from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Point(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lng: float = Field(ge=-180.0, le=180.0)


class ZoneBase(BaseModel):
    
    name: str
    type: Literal["shaded", "unshaded"]
    points: list[Point] = Field(min_length=3)
    fill_alpha: float = 0.3
    border_alpha: float = 0.8
    start_minute_of_day: int | None = None
    end_minute_of_day: int | None = None
    temp_delta_c: float = 0.0





class ZoneCreate(ZoneBase):
    pass


class ZoneUpdate(ZoneBase):
    pass


class ZoneOut(ZoneBase):
    id: int
    zone_id: int


class IncidentIn(BaseModel):
    user_id: int = Field(ge=0, default=0)
    duration_seconds: int = Field(ge=1)
    max_temp: float | None = None
    max_risk_ratio: float = Field(ge=0.0, le=1.0)
    shaded: bool = False


class IncidentOut(BaseModel):
    id: int
    user_id: int
    duration_seconds: int
    max_temp: float | None
    max_risk_ratio: float
    shaded: bool
    created_at: datetime


class EffectiveWeatherOut(BaseModel):
    base_temp_c: float
    effective_temp_c: float
    temp_delta_c: float
    zone_id: int | None
    zone_name: str | None
    zone_type: str | None
    source: str
    timestamp: datetime


class ExposureThresholdOut(BaseModel):
    safe_exposure_seconds: int
    model_prediction_seconds: float
    rule_prediction_seconds: float
    blend_alpha: float
    sample_count: int


class DaylightWindowOut(BaseModel):
    start_minute_of_day: int
    end_minute_of_day: int
    sunrise_utc: datetime | None = None
    sunset_utc: datetime | None = None
    source: str

class EMReportCreate(BaseModel):
    user_id: int = Field(ge=0, default=0)
    created_at: datetime | None = None
    location_lat: float = Field(ge=-90.0, le=90.0)
    location_lng: float = Field(ge=-180.0, le=180.0)
    incident_id: int | None = None
    taken_care: bool = False

class EMReportListOut(BaseModel):
    id: int
    user_id: int
    created_at: datetime
    location_lat: float
    location_lng: float
    taken_care: bool
    incident_id: int | None = None

    model_config = ConfigDict(from_attributes=True)

class EMReportOut(EMReportListOut):
    pass