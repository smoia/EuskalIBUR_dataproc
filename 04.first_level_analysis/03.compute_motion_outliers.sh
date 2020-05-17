#!/usr/bin/env bash

######### Motion cleaning for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
ses=$2
wdr=${3:-/data}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

if [[ ! -d "ME_Denoising" ]]; then mkdir ME_Denoising; fi

cd ME_Denoising

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi

flpr=sub-${sub}_ses-${ses}
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

echo "Computing DVARS Pre-motcor and collecting FD"
3dTto1D -input ${fdir}/${flpr}_task-breathhold_echo-2_bold_cr.nii.gz -mask ${mask}.nii.gz -method dvars -prefix sub-${sub}/dvars_pre_${flpr}.1D

cp ${fdir}/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_${flpr}.1D

cd ${cwd}