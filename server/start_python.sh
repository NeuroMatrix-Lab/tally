#!/bin/bash

echo "Starting Tally Server (Python)..."
echo

cd "$(dirname "$0")"

if [ ! -d "data" ]; then
    mkdir data
fi

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate

echo "Installing dependencies..."
pip install -r requirements.txt

echo "Starting server on port 7378..."
python main.py