#!/usr/bin/env bash

# sub     > $1
# ses     > $2
# ftype   > $3
# ftype can be any meica denoising, optcom or echo-2

wdr=${4:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Compute CVR regressors"

python3 /scripts/20.python_scripts/compute_CVR_regressors.py $1 $2 $3

cd ${cwd}