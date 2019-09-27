#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Processing sheet"
python3 sheet_preproc.py
