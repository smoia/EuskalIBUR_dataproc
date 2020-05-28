#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Plotting motion outliers"

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

python3 /scripts/20.python_scripts/plot_motion_denoise.py

cd ${cwd}
