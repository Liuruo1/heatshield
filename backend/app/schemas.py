from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class Point(BaseModel):
    lat: float
    lng: float


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
    user_id: str = "default"
    duration_seconds: int = Field(ge=1)
    max_temp: float | None = None
    max_risk_ratio: float = Field(ge=0.0, le=1.0)
    shaded: bool = False


class IncidentOut(BaseModel):
    id: int
    user_id: str
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
