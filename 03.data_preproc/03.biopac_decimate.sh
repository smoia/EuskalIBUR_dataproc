#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Decimating biopac traces"

python3 /scripts/20.python_scripts/biopac_decimate.py

cd ${cwd}