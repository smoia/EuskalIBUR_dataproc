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

flpr=sub-${sub}_ses-${ses}
mref=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc

# 01. Register GM to MREF if necessary
if [[ ! -e sub-${sub}_GM.nii.gz ]]
then
	echo "Registering GM to functional space"
	anat=sub-${sub}_ses-01_acq-uni_T1w
	aref=sub-${sub}_ses-01_T2w

	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-${ses}/anat_preproc/${anat}_GM.nii.gz \
						-r ${mref}.nii.gz \
						-o sub-${sub}_GM.nii.gz -n MultiLabel \
						-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1] \
						-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat
fi

# 02. Quick denoise for OC, E2, 4D denoise?
echo ${flpr}

for den in optcom echo-2
do
	func=${fdir}/00.${flpr}_task-breathhold_${den}_bold_native_preprocessed
	3dDeconvolve -input ${func}.nii.gz \
				 -polort 2 -float \
				 -ortvec ${fdir}/${flpr}_task-breathhold_echo-1_bold_mcf_demean.par motdemean \
				 -ortvec ${fdir}/${flpr}_task-breathhold_echo-1_bold_mcf_deriv1.par motderiv1 \
				 -x1D tmp.${flpr}_nuisreg_mat.1D \
				 -x1D_stop
	fslmaths ${func} -Tmean tmp.${flpr}_avg
	3dTproject -polort 0 -input ${func}.nii.gz -mask ${mref}_mask.nii.gz \
			   -ort tmp.${flpr}_nuisreg_mat.1D -prefix tmp.${flpr}_prj.nii.gz \
			   -overwrite
	fslmaths tmp.${flpr}_prj -add tmp.${flpr}_avg tmp.${flpr}_den

	echo "Computing DVARS and average GM ${den}"
	fsl_motion_outliers -i tmp.${flpr}_den -o tmp.${flpr}_out -s sub-${sub}/dvars_${den}_${flpr}.1D --dvars --nomoco
	fslmeants -i tmp.${flpr}_den -m sub-${sub}_GM > sub-${sub}/avg_GM_${den}_${flpr}.1D
done

echo "Collecting DVARS Pre-motcor and FD"
cp ${fdir}/${func}_dvars_pre.par sub-${sub}/dvars_pre_${flpr}.1D
cp ${fdir}/${func}_dvars_fd.par sub-${sub}/fc_${flpr}.1D

for type in meica #vessels networks
do
	for den in aggr orth preg mvar
	do
		echo "Computing DVARS and average GM ${type}-${den}"
		fsl_motion_outliers -i ${fdir}/00.${flpr}_task-breathhold_${type}-${den}_bold_native_preprocessed \
							-o tmp.${flpr}_out -s sub-${sub}/dvars_${type}-${den}_${flpr}.1D --dvars --nomoco
		fslmeants -i ${fdir}/00.${flpr}_task-breathhold_${type}-${den}_bold_native_preprocessed \
				  -m sub-${sub}_GM > sub-${sub}/avg_GM_${type}-${den}_${flpr}.1D
	done
done

echo "Extracting GM pre-preproc"
fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
		  -m sub-${sub}_GM > sub-${sub}/avg_GM_pre_${flpr}.1D

rm tmp.${flpr}*

cd ${cwd}