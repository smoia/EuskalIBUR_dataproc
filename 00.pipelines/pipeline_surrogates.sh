#!/usr/bin/env bash

sub=$1
ses=$2
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-/tmp}

logname=surr_${sub}_${ses}_log

######################################
######### Script starts here #########
######################################

date

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${logname}" ]]; then rm ${wdr}/log/${logname}; fi

echo "************************************" >> ${wdr}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdr}/log/${logname} 2>&1

date
echo "************************************"

# saving the current wokdir
cwd=$(pwd)

# Create temp folder
if [[ -d "${tmp}" ]]; then rm -rf ${tmp}; fi
mkdir ${tmp}

echo "************************************"
echo "*** Prepare surrogates"
echo "************************************"
echo "************************************"
singularity exec -e --no-home \
-B ${wdr}:/data -B ${sdr}:/scripts \
-B ${tmp}:/tmp \
euskalibur.sif 04.first_level_analysis/06.prepare_surrogates.sh ${sub} ${ses}

echo "************************************"
echo "*** Compute surrogates"
echo "************************************"
echo "************************************"
singularity exec -e --no-home \
-B ${wdr}:/data -B ${sdr}:/scripts \
-B ${tmp}:/tmp \
mcr.sif 04.first_level_analysis/09.compute_surrogates.sh ${sub} ${ses}

# Remove temp
rm -rf ${tmp}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}