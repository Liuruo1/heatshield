@echo off
rem load .env 
for /f "usebackq tokens=1* delims==" %%A in ("backend.env") do (
if not "%%A"=="" (
set "%%A=%%B"
)
)
pushd "%~dp0backend"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
popd
pause