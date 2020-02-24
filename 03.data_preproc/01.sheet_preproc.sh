#!/usr/bin/env bash

# sub     > $1

wdr=${2:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Processing sheet"

if [[ ! -d "decomp" ]]; then mkdir decomp; fi

python3 /scripts/20.python_scripts/sheet_preproc.py $1


cd ${cwd}