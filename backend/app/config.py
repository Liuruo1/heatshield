from os import getenv
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = getenv("DATABASE_URL", "").strip()
API_KEY = getenv("API_KEY", "change-me")
APP_ENV = getenv("APP_ENV", "development").strip().lower()
CORS_ALLOW_ORIGINS = [
    origin.strip()
    for origin in getenv("CORS_ALLOW_ORIGINS", "*").split(",")
    if origin.strip()
]
OPEN_METEO_TIMEOUT_SECONDS = float(getenv("OPEN_METEO_TIMEOUT_SECONDS", "8"))
DEFAULT_SAFE_EXPOSURE_SECONDS = int(getenv("DEFAULT_SAFE_EXPOSURE_SECONDS", "900"))
MIN_SAFE_EXPOSURE_SECONDS = int(getenv("MIN_SAFE_EXPOSURE_SECONDS", "180"))
MODEL_BLEND_MAX = float(getenv("MODEL_BLEND_MAX", "0.8"))
MODEL_MIN_SAMPLES = int(getenv("MODEL_MIN_SAMPLES", "5"))
ENFORCE_GLOBAL_DAYLIGHT_WINDOW = getenv(
    "ENFORCE_GLOBAL_DAYLIGHT_WINDOW", "1"
).strip().lower() in {"1", "true", "yes", "on"}
USE_DYNAMIC_DAYLIGHT_WINDOW = getenv(
    "USE_DYNAMIC_DAYLIGHT_WINDOW", "1"
).strip().lower() in {"1", "true", "yes", "on"}
GLOBAL_ZONE_DAY_START_MINUTE = int(getenv("GLOBAL_ZONE_DAY_START_MINUTE", "360"))
GLOBAL_ZONE_DAY_END_MINUTE = int(getenv("GLOBAL_ZONE_DAY_END_MINUTE", "1080"))