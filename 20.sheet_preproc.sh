#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Processing sheet"


if [[ -d "decomp" ]]; then rm -rf decomp; fi

python3 sheet_preproc.py

cd ${cwd}