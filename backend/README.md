# HeatShield Backend



## Notes on adaptive training

`POST /v1/incidents` updates a lightweight per-user/per-temperature bucket EMA model.
The app requests `GET /v1/exposure-threshold` and receives `safe_exposure_seconds`.
Model output is blended with a rule-based baseline for safety, especially with low sample counts.
