from datetime import datetime, timezone
import json
from pathlib import Path

import requests
from fastapi import Depends, FastAPI, Header, HTTPException
from sqlalchemy import inspect, select, text
from sqlalchemy.orm import Session

from .config import (
    API_KEY,
    DEFAULT_SAFE_EXPOSURE_SECONDS,
    MIN_SAFE_EXPOSURE_SECONDS,
    MODEL_BLEND_MAX,
    MODEL_MIN_SAMPLES,
    OPEN_METEO_TIMEOUT_SECONDS,
)
from .db import Base, SessionLocal, engine, get_db
from .models import Incident, ModelBucket, Zone, ZonePoint
from .schemas import (
    EffectiveWeatherOut,
    ExposureThresholdOut,
    IncidentIn,
    IncidentOut,
    ZoneCreate,
    ZoneOut,
    ZoneUpdate,
)

app = FastAPI(title="HeatShield API", version="1.0.0")
_BASE_DIR = Path(__file__).resolve().parent
_DEFAULT_ZONES_PATH = _BASE_DIR / "default_zones.json"


def _require_api_key(x_api_key: str = Header(default="")):
    if not API_KEY or API_KEY == "change-me":
        return
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        _migrate_legacy_zone_columns(db)
        _seed_default_zones_if_needed(db)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
def root(db: Session = Depends(get_db)):
    zone_count = db.query(Zone).count()
    incident_count = db.query(Incident).count()
    bucket_count = db.query(ModelBucket).count()
    latest_incident = db.query(Incident).order_by(Incident.created_at.desc()).first()

    return {
        "service": "HeatShield API",
        "status": "running",
        "docs": "/docs",
        "redoc": "/redoc",
        "health": "/health",
        "summary": {
            "zones": zone_count,
            "incidents": incident_count,
            "model_buckets": bucket_count,
            "latest_incident_at": latest_incident.created_at.isoformat() if latest_incident else None,
        },
    }


def _load_default_zones() -> list[dict]:
    with _DEFAULT_ZONES_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _migrate_legacy_zone_columns(db: Session) -> None:
    if engine.dialect.name != "sqlite":
        return

    inspector = inspect(engine)
    try:
        columns = {column["name"] for column in inspector.get_columns("zones")}
    except Exception:
        return

    statements = []
    if "fill_alpha" not in columns:
        statements.append("ALTER TABLE zones ADD COLUMN fill_alpha REAL NOT NULL DEFAULT 0.3")
    if "border_alpha" not in columns:
        statements.append("ALTER TABLE zones ADD COLUMN border_alpha REAL NOT NULL DEFAULT 0.8")

    for statement in statements:
        db.execute(text(statement))

    if statements:
        db.commit()


def _upsert_zone_from_payload(db: Session, payload: dict) -> Zone:
    zone = Zone(
        name=payload["name"],
        type=payload["type"],
        fill_alpha=payload.get("fill_alpha", 0.3),
        border_alpha=payload.get("border_alpha", 0.8),
        start_minute_of_day=payload.get("start_minute_of_day"),
        end_minute_of_day=payload.get("end_minute_of_day"),
        temp_delta_c=payload.get("temp_delta_c", 0.0),
    )
    db.add(zone)
    db.flush()

    for idx, point in enumerate(payload["points"]):
        db.add(
            ZonePoint(
                zone_id=zone.id,
                point_order=idx,
                lat=point["lat"],
                lng=point["lng"],
            )
        )
    return zone


def _seed_default_zones_if_needed(db: Session) -> None:
    if db.query(Zone).count() > 0:
        return

    for payload in _load_default_zones():
        _upsert_zone_from_payload(db, payload)

    db.commit()


def _zone_is_active(zone: Zone) -> bool:
    start = zone.start_minute_of_day
    end = zone.end_minute_of_day
    if start is None or end is None:
        return True

    now = datetime.now(timezone.utc)
    minute = now.hour * 60 + now.minute
    if start == end:
        return True
    if start < end:
        return start <= minute < end
    return minute >= start or minute < end


def _point_in_polygon(lat: float, lng: float, polygon: list[ZonePoint]) -> bool:
    inside = False
    j = len(polygon) - 1
    for i in range(len(polygon)):
        yi, xi = polygon[i].lat, polygon[i].lng
        yj, xj = polygon[j].lat, polygon[j].lng
        intersects = ((yi > lat) != (yj > lat)) and (
            lng < (xj - xi) * (lat - yi) / ((yj - yi) if (yj - yi) != 0 else 1e-12) + xi
        )
        if intersects:
            inside = not inside
        j = i
    return inside


def _serialize_zone(zone: Zone) -> ZoneOut:
    points = sorted(zone.points, key=lambda p: p.point_order)
    return ZoneOut(
        id=zone.id,
        name=zone.name,
        type=zone.type,
        fill_alpha=zone.fill_alpha,
        border_alpha=zone.border_alpha,
        start_minute_of_day=zone.start_minute_of_day,
        end_minute_of_day=zone.end_minute_of_day,
        temp_delta_c=zone.temp_delta_c,
        points=[{"lat": p.lat, "lng": p.lng} for p in points],
    )


def _fetch_open_meteo_temp(lat: float, lng: float) -> float:
    response = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params={"latitude": lat, "longitude": lng, "current": "temperature_2m"},
        timeout=OPEN_METEO_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    data = response.json()
    return float(data["current"]["temperature_2m"])


def _bucket_key(temp_c: float | None, shaded: bool) -> str:
    if temp_c is None:
        temp_band = "unknown"
    else:
        band_floor = int(temp_c // 3 * 3)
        temp_band = f"{band_floor}-{band_floor + 2}"
    return f"temp:{temp_band}|shaded:{1 if shaded else 0}"


def _rule_based_safe_seconds(temp_c: float, shaded: bool) -> float:
    penalty = max(0.0, (temp_c - 32.0) * 30.0)
    bonus = 180.0 if shaded else 0.0
    value = DEFAULT_SAFE_EXPOSURE_SECONDS - penalty + bonus
    return max(float(MIN_SAFE_EXPOSURE_SECONDS), value)


def _upsert_bucket(
    db: Session,
    user_id: str,
    bucket_key: str,
    observed_safe_seconds: int,
):
    bucket = db.scalar(
        select(ModelBucket).where(
            ModelBucket.user_id == user_id, ModelBucket.bucket_key == bucket_key
        )
    )
    alpha = 0.25
    if bucket is None:
        bucket = ModelBucket(
            user_id=user_id,
            bucket_key=bucket_key,
            sample_count=1,
            ema_safe_seconds=float(observed_safe_seconds),
            updated_at=datetime.utcnow(),
        )
        db.add(bucket)
    else:
        bucket.sample_count += 1
        bucket.ema_safe_seconds = (
            (1.0 - alpha) * bucket.ema_safe_seconds + alpha * float(observed_safe_seconds)
        )
        bucket.updated_at = datetime.utcnow()


def _predict_threshold(
    db: Session,
    user_id: str,
    temp_c: float,
    shaded: bool,
) -> tuple[int, float, float, float, int]:
    key = _bucket_key(temp_c, shaded)
    bucket = db.scalar(
        select(ModelBucket).where(
            ModelBucket.user_id == user_id, ModelBucket.bucket_key == key
        )
    )
    rule_pred = _rule_based_safe_seconds(temp_c, shaded)
    if bucket is None:
        model_pred = float(DEFAULT_SAFE_EXPOSURE_SECONDS)
        samples = 0
    else:
        model_pred = bucket.ema_safe_seconds
        samples = bucket.sample_count

    if samples < MODEL_MIN_SAMPLES:
        alpha = 0.0
    else:
        alpha = min(MODEL_BLEND_MAX, samples / 200.0)

    safe_seconds = max(
        MIN_SAFE_EXPOSURE_SECONDS,
        int(alpha * model_pred + (1.0 - alpha) * rule_pred),
    )
    return safe_seconds, model_pred, rule_pred, alpha, samples


@app.get("/v1/zones", response_model=list[ZoneOut])
def list_zones(db: Session = Depends(get_db)):
    zones = db.scalars(select(Zone).order_by(Zone.id.asc())).all()
    return [_serialize_zone(zone) for zone in zones]


@app.get("/v1/zones/defaults", response_model=list[ZoneOut])
def list_default_zones():
    return [ZoneOut(**payload, id=index + 1) for index, payload in enumerate(_load_default_zones())]


@app.post("/v1/zones/reset-defaults", response_model=list[ZoneOut], dependencies=[Depends(_require_api_key)])
def reset_default_zones(db: Session = Depends(get_db)):
    db.query(ZonePoint).delete()
    db.query(Zone).delete()
    db.flush()

    created = []
    for payload in _load_default_zones():
        created.append(_upsert_zone_from_payload(db, payload))
    db.commit()
    return [_serialize_zone(zone) for zone in created]


@app.post("/v1/zones", response_model=ZoneOut, dependencies=[Depends(_require_api_key)])
def create_zone(payload: ZoneCreate, db: Session = Depends(get_db)):
    zone = _upsert_zone_from_payload(db, payload.model_dump())
    db.commit()
    db.refresh(zone)
    return _serialize_zone(zone)


@app.put("/v1/zones/{zone_id}", response_model=ZoneOut, dependencies=[Depends(_require_api_key)])
def update_zone(zone_id: int, payload: ZoneUpdate, db: Session = Depends(get_db)):
    zone = db.get(Zone, zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.name = payload.name
    zone.type = payload.type
    zone.fill_alpha = payload.fill_alpha
    zone.border_alpha = payload.border_alpha
    zone.start_minute_of_day = payload.start_minute_of_day
    zone.end_minute_of_day = payload.end_minute_of_day
    zone.temp_delta_c = payload.temp_delta_c

    zone.points.clear()
    for idx, point in enumerate(payload.points):
        zone.points.append(
            ZonePoint(point_order=idx, lat=point.lat, lng=point.lng)
        )

    db.commit()
    db.refresh(zone)
    return _serialize_zone(zone)


@app.delete("/v1/zones/{zone_id}", dependencies=[Depends(_require_api_key)])
def delete_zone(zone_id: int, db: Session = Depends(get_db)):
    zone = db.get(Zone, zone_id)
    if zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    db.delete(zone)
    db.commit()
    return {"deleted": True}


@app.post("/v1/incidents", response_model=IncidentOut)
def ingest_incident(payload: IncidentIn, db: Session = Depends(get_db)):
    incident = Incident(
        user_id=payload.user_id,
        duration_seconds=payload.duration_seconds,
        max_temp=payload.max_temp,
        max_risk_ratio=payload.max_risk_ratio,
        shaded=payload.shaded,
    )
    db.add(incident)

    if payload.max_temp is not None:
        # More severe incidents should reduce tolerated outside time for that bucket.
        scaled = int(payload.duration_seconds * max(0.4, 1.0 - payload.max_risk_ratio * 0.6))
        _upsert_bucket(
            db=db,
            user_id=payload.user_id,
            bucket_key=_bucket_key(payload.max_temp, payload.shaded),
            observed_safe_seconds=max(MIN_SAFE_EXPOSURE_SECONDS, scaled),
        )

    db.commit()
    db.refresh(incident)

    return IncidentOut(
        id=incident.id,
        user_id=incident.user_id,
        duration_seconds=incident.duration_seconds,
        max_temp=incident.max_temp,
        max_risk_ratio=incident.max_risk_ratio,
        shaded=incident.shaded,
        created_at=incident.created_at,
    )


@app.get("/v1/weather/effective", response_model=EffectiveWeatherOut)
def effective_weather(lat: float, lng: float, db: Session = Depends(get_db)):
    base_temp = _fetch_open_meteo_temp(lat, lng)
    matched_zone = None
    for zone in db.scalars(select(Zone).order_by(Zone.id.asc())).all():
        if not _zone_is_active(zone):
            continue
        ordered_points = sorted(zone.points, key=lambda p: p.point_order)
        if _point_in_polygon(lat, lng, ordered_points):
            matched_zone = zone
            break

    delta = matched_zone.temp_delta_c if matched_zone else 0.0
    now = datetime.now(timezone.utc)
    return EffectiveWeatherOut(
        base_temp_c=round(base_temp, 2),
        effective_temp_c=round(base_temp + delta, 2),
        temp_delta_c=round(delta, 2),
        zone_id=matched_zone.id if matched_zone else None,
        zone_name=matched_zone.name if matched_zone else None,
        zone_type=matched_zone.type if matched_zone else None,
        source="open-meteo",
        timestamp=now,
    )


@app.get("/v1/exposure-threshold", response_model=ExposureThresholdOut)
def exposure_threshold(
    user_id: str = "default",
    temp: float = 35.0,
    shaded: bool = False,
    db: Session = Depends(get_db),
):
    safe, model_pred, rule_pred, alpha, samples = _predict_threshold(
        db=db,
        user_id=user_id,
        temp_c=temp,
        shaded=shaded,
    )
    return ExposureThresholdOut(
        safe_exposure_seconds=safe,
        model_prediction_seconds=round(model_pred, 2),
        rule_prediction_seconds=round(rule_pred, 2),
        blend_alpha=round(alpha, 4),
        sample_count=samples,
    )
