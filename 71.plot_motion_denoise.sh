#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Plotting motion outliers"
python3 plot_motion_denoise.py
