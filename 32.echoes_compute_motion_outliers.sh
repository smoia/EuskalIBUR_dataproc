#!/usr/bin/env bash

######### Motion cleaning for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
ses=$2
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr}

if [[ ! -d "ME_Denoising" ]]; then mkdir ME_Denoising; fi

cd ME_Denoising

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi

flpr=sub-${sub}_ses-${ses}
echo ${flpr}
cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_dvars_pre.par sub-${sub}/dvars_pre_sub-${sub}_ses-${ses}.1D
cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_sub-${sub}_ses-${ses}.1D

echo "DVARS Single Echo"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-2_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_echo-2_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS Single Echo"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-1_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_echo-1_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS Single Echo"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-3_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_echo-3_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS Single Echo"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-4_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_echo-4_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS Single Echo"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-5_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_echo-5_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS Optcom"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_optcom_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_optcom_sub-${sub}_ses-${ses}.1D --dvars --nomoco
echo "DVARS MEICA"
fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_meica_bold_native_preprocessed \
-o tmp_out -s sub-${sub}/dvars_meica_sub-${sub}_ses-${ses}.1D --dvars --nomoco

rm tmp*

cd ${cwd}