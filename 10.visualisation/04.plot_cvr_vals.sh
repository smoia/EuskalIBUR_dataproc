#!/usr/bin/env bash

sub=${1}
wdr=${2:-/data}
scriptdir=${3:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Plotting motion outliers"

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

python3 ${scriptdir}/20.python_scripts/plot_cvr_vals.py ${sub} ${wdr} ${scriptdir}

cd ${cwd}
