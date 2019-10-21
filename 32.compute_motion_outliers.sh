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
cd ${wdr} || exit

if [[ ! -d "ME_Denoising" ]]; then mkdir ME_Denoising; fi

cd ME_Denoising

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi


# 01. Register GM to MREF
anat=${flpr}_acq-uni_T1w
mref=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr
aref=${flpr}_T2w

antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-${ses}/anat_preproc/${anat}_GM.nii.gz \
-r ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${mref}.nii.gz \
-o ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses}.nii.gz -n MultiLabel \
-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1] \
-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat

# 02. Get FD and DVARS
flpr=sub-${sub}_ses-${ses}
echo ${flpr}
# cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_dvars_pre.par sub-${sub}/dvars_pre_${flpr}.1D
cp ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_${flpr}.1D

for e in 2 # $( seq 1 ${nTE} )
do
	echo "DVARS Pre motcor ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
	-o tmp_out -s sub-${sub}/dvars_pre_${flpr}.1D -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} --dvars --nomoco
	echo "DVARS Single Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_echo-${e}_${flpr}.1D -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} --dvars --nomoco
	echo "DVARS MEICA Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/04.${flpr}_task-breathhold_meica_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_meica_echo-${e}_${flpr}.1D -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} --dvars --nomoco
done
for ftype in optcom meica
do
	echo "DVARS ${ftype}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_${ftype}_${flpr}.1D -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} --dvars --nomoco
done

# 03. Get average GM response
for ftype in echo-2 optcom meica
do
	echo "Extracting GM in ${ftype}"
	fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed \
	-m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} > sub-${sub}/avg_GM_${ftype}_${flpr}.1D
done

echo "Extracting GM pre-preproc"
fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
-m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses} > sub-${sub}/avg_GM_pre_${flpr}.1D

rm tmp*

cd ${cwd}