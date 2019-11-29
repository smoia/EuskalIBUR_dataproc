#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Plotting motion outliers"

python3 ${cwd}/20.python_scripts/plot_motion_denoise.py

cd ${cwd}
