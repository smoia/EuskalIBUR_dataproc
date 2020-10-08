#!/usr/bin/env bash

sub=${1}
wdr=${2:-/data}
scriptdir=${3:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Decimating biopac traces"

python3 ${scriptdir}/20.python_scripts/new_biopac_decimate.py ${wdr} ${sub}

cd ${cwd}