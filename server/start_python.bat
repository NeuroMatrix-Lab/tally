@echo off
echo Starting Tally Server (Python)...
echo.

cd %~dp0

if not exist "data" mkdir data

if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

call venv\Scripts\activate

echo Installing dependencies...
pip install -r requirements.txt

echo Starting server on port 7378...
python main.py

pause