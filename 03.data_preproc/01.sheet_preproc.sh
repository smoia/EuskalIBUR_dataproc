#!/usr/bin/env bash

# sub     > $1

wdr=${2:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Processing sheet"

if [[ -d "decomp" ]]; then rm -rf decomp; fi

python3 ${cwd}/20.python_scripts/sheet_preproc.py $1


cd ${cwd}