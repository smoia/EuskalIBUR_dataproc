#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

echo "Processing sheet"

if [[ -d "decomp" ]]; then rm -rf decomp; fi

python3 sheet_preproc.py
