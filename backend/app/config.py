import os

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
API_KEY = os.getenv("API_KEY", "change-me")
OPEN_METEO_TIMEOUT_SECONDS = float(os.getenv("OPEN_METEO_TIMEOUT_SECONDS", "8"))
DEFAULT_SAFE_EXPOSURE_SECONDS = int(os.getenv("DEFAULT_SAFE_EXPOSURE_SECONDS", "900"))
MIN_SAFE_EXPOSURE_SECONDS = int(os.getenv("MIN_SAFE_EXPOSURE_SECONDS", "180"))
MODEL_BLEND_MAX = float(os.getenv("MODEL_BLEND_MAX", "0.8"))
MODEL_MIN_SAMPLES = int(os.getenv("MODEL_MIN_SAMPLES", "5"))
ENFORCE_GLOBAL_DAYLIGHT_WINDOW = os.getenv(
	"ENFORCE_GLOBAL_DAYLIGHT_WINDOW", "1"
).strip().lower() in {"1", "true", "yes", "on"}
USE_DYNAMIC_DAYLIGHT_WINDOW = os.getenv(
	"USE_DYNAMIC_DAYLIGHT_WINDOW", "1"
).strip().lower() in {"1", "true", "yes", "on"}
GLOBAL_ZONE_DAY_START_MINUTE = int(os.getenv("GLOBAL_ZONE_DAY_START_MINUTE", "360"))
GLOBAL_ZONE_DAY_END_MINUTE = int(os.getenv("GLOBAL_ZONE_DAY_END_MINUTE", "1080"))
