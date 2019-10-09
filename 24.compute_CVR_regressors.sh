#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Processing sheet"
python3 compute_CVR_regressors.py
