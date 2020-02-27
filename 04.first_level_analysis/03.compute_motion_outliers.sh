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
cd ${wdr} || exit

if [[ ! -d "ME_Denoising" ]]; then mkdir ME_Denoising; fi

cd ME_Denoising

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi

flpr=sub-${sub}_ses-${ses}
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

# # 01. Register GM to MREF if necessary
# if [[ ! -e sub-${sub}_GM.nii.gz ]]
# then
# 	echo "Registering GM to functional space"
# 	anat=sub-${sub}_ses-01_acq-uni_T1w
# 	aref=sub-${sub}_ses-01_T2w

# 	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-${ses}/anat_preproc/${anat}_GM.nii.gz \
# 						-r ${wdr}/sub-${sub}/ses-${ses}/reg/${mref}_brain.nii.gz \
# 						-o sub-${sub}_GM.nii.gz -n MultiLabel \
# 						-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat \
# 						-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1]
# fi

echo "Computing DVARS Pre-motcor and collecting FD"
3dTto1D -input ${fdir}/${flpr}_task-breathhold_echo-2_bold_cr.nii.gz -mask ${mask}.nii.gz -method dvars -prefix sub-${sub}/dvars_pre_${flpr}.1D

# cp ${fdir}/${flpr}_task-breathhold_echo-1_bold_dvars_pre.par sub-${sub}/dvars_pre_${flpr}.1D
cp ${fdir}/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_${flpr}.1D

# for type in meica  #vessels networks
# do
# 	for den in aggr orth preg mvar recn
# 	do
# 		echo "Computing DVARS and average GM ${type}-${den}"
# 		fsl_motion_outliers -i ${fdir}/00.${flpr}_task-breathhold_${type}-${den}_bold_native_preprocessed \
# 							-o tmp.${flpr}_out -s sub-${sub}/dvars_${type}-${den}_${flpr}.1D --dvars --nomoco
# 		fslmeants -i ${fdir}/00.${flpr}_task-breathhold_${type}-${den}_bold_native_preprocessed \
# 				  -m sub-${sub}_GM > sub-${sub}/avg_GM_${type}-${den}_${flpr}.1D
# 	done
# done

# echo "Extracting GM pre-preproc"
# fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
# 		  -m sub-${sub}_GM > sub-${sub}/avg_GM_pre_${flpr}.1D

# rm tmp.${flpr}*

cd ${cwd}