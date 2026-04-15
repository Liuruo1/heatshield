# HeatShield Backend

FastAPI backend for zones, effective weather, and adaptive safe-exposure prediction.

## 1) Configure

Create a `.env` file from `.env.example`:

```powershell
Copy-Item .env.example .env
```

Update at least if you want Postgres/Docker:

- `API_KEY`
- `DATABASE_URL` (for local docker compose, default works)

If you do not want Docker running locally, leave `DATABASE_URL` empty and the backend will use a local SQLite file instead.

## 2) Run with Docker

```powershell
docker compose up --build
```

API will be available at `http://localhost:8000`.

If you see `failed to connect to the docker API at npipe:////./pipe/docker_engine`, start Docker Desktop first or use the SQLite fallback below.

## 2b) Run without Docker

Install Python dependencies and run directly:

```powershell
cd backend
python -m pip install -r requirements.txt
$env:API_KEY="change-me"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

This uses `heatshield.db` in the backend folder and does not require Postgres.

## 3) Endpoints

- `GET /health`
- `GET /v1/zones`
- `POST /v1/zones` (requires `x-api-key`)
- `PUT /v1/zones/{zone_id}` (requires `x-api-key`)
- `DELETE /v1/zones/{zone_id}` (requires `x-api-key`)
- `GET /v1/weather/effective?lat=...&lng=...`
- `GET /v1/exposure-threshold?user_id=default&temp=39&shaded=false`
- `POST /v1/incidents`

## 4) Flutter app connection

Set these build-time values:

- `API_BASE_URL`
- `API_KEY` (optional if key is enforced server-side)

Examples:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=API_KEY=change-me
```

```powershell
flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com --dart-define=API_KEY=your-real-key
```

## Notes on adaptive training

`POST /v1/incidents` updates a lightweight per-user/per-temperature bucket EMA model.
The app requests `GET /v1/exposure-threshold` and receives `safe_exposure_seconds`.
Model output is blended with a rule-based baseline for safety, especially with low sample counts.
