#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Plotting motion outliers"

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

python3 ${scriptdir}/20.python_scripts/plot_cvr_vals.py ${wdr}

cd ${cwd}