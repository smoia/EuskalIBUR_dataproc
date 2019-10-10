#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Compute CVR regressors"
python3 compute_CVR_regressors.py
