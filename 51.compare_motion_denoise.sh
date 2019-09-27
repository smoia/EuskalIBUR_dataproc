#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Processing sheet"
python3 compare_motion_denoise.py
