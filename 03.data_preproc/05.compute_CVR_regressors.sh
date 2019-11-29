#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Compute CVR regressors"

python3 ${cwd}/20.python_scripts/compute_CVR_regressors.py

cd ${cwd}