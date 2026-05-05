from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


class Zone(Base):
    __tablename__ = "zones"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    fill_alpha: Mapped[float] = mapped_column(Float, default=0.3, nullable=False)
    border_alpha: Mapped[float] = mapped_column(Float, default=0.8, nullable=False)
    start_minute_of_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_minute_of_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    temp_delta_c: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    points: Mapped[list["ZonePoint"]] = relationship(
        "ZonePoint", cascade="all, delete-orphan", back_populates="zone"
    )


class ZonePoint(Base):
    __tablename__ = "zone_points"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    zone_id: Mapped[int] = mapped_column(ForeignKey("zones.id", ondelete="CASCADE"))
    point_order: Mapped[int] = mapped_column(Integer, nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    zone: Mapped[Zone] = relationship("Zone", back_populates="points")


class Incident(Base):
    __tablename__ = "incidents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    max_temp: Mapped[float | None] = mapped_column(Float, nullable=True)
    max_risk_ratio: Mapped[float] = mapped_column(Float, nullable=False)
    shaded: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class EMReport(Base):
    __tablename__ = "em_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    location_lat: Mapped[float] = mapped_column(Float, nullable=False)
    location_lng: Mapped[float] = mapped_column(Float, nullable=False)
    incident_id: Mapped[int | None] = mapped_column(ForeignKey("incidents.id", ondelete="CASCADE"))
    incident: Mapped["Incident"] = relationship("Incident")
    taken_care: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

class ModelBucket(Base):
    __tablename__ = "model_buckets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    bucket_key: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    sample_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ema_safe_seconds: Mapped[float] = mapped_column(Float, nullable=False, default=900.0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
