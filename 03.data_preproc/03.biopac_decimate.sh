#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Decimating biopac traces"

python3 ${scriptdir}/20.python_scripts/biopac_decimate.py ${wdr}

cd ${cwd}