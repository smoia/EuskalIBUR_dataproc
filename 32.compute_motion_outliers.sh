#!/usr/bin/env bash

######### Motion cleaning for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
ses=$2
wdr=${3:-/data}

nTE=${4:-5}

### Main ###
cwd=$( pwd )
cd ${wdr}

if [[ ! -d "ME_Denoising" ]]; then mkdir ME_Denoising; fi

cd ME_Denoising

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi


# 01. Get FD and DVARS
flpr=sub-${sub}_ses-${ses}
echo ${flpr}
cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_dvars_pre.par sub-${sub}/dvars_pre_sub-${sub}_ses-${ses}.1D
cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_sub-${sub}_ses-${ses}.1D

for e in $( seq 1 ${nTE} )
do
	echo "DVARS Single Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_echo-${e}_sub-${sub}_ses-${ses}.1D --dvars --nomoco
	echo "DVARS MEICA Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/04.${flpr}_task-breathhold_meica_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_meica_echo-${e}_sub-${sub}_ses-${ses}.1D --dvars --nomoco
done
for ftype in optcom meica
do
	echo "DVARS ${ftype}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_${ftype}_sub-${sub}_ses-${ses}.1D --dvars --nomoco
done

# 02. Get average GM response
for ftype in echo-2 optcom meica
do
	echo "Extracting GM in ${ftype}"
	fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed \
	-m ${wdr}/sub-${sub}/ses-${ses}/anat_preproc/sub-${sub}_ses-${ses}_acq-uni_T1w_GM_native.nii.gz > sub-${sub}/avg_GM_${ftype}_sub-${sub}_ses-${ses}.1D
done

rm tmp*

cd ${cwd}