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


# 01. Register GM to MREF if necessary
if [[ ! -e sub-${sub}_GM.nii.gz ]]
then
	echo "Registering GM to functional space"
	flpr=sub-${sub}_ses-${ses}
	anat=sub-${sub}_ses-01_acq-uni_T1w
	mref=sub-${sub}_sbref_brain
	aref=sub-${sub}_ses-01_T2w

	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-01/anat_preproc/${anat}_GM.nii.gz \
	-r ${wdr}/sub-${sub}/ses-01/reg/${mref}.nii.gz \
	-o ${wdr}/ME_Denoising/sub-${sub}_GM.nii.gz -n MultiLabel \
	-t [${wdr}/sub-${sub}/ses-01/reg/${aref}2${anat}0GenericAffine.mat,1] \
	-t ${wdr}/sub-${sub}/ses-01/reg/${aref}2${mref}0GenericAffine.mat
fi

# 02. Quick denoise for OC, E2, 4D denoise?
echo ${flpr}

# for optcom echo-2 meica ...
# 3dDeconvolve -input ${func_in}.nii.gz \
# -polort 5 -float \
# -num_stimts  2 \
# -stim_file 1 ${func}_avg_tissue.1D'[0]' -stim_base 1 -stim_label 1 CSF \
# -stim_file 2 ${func}_avg_tissue.1D'[2]' -stim_base 2 -stim_label 2 WM \
# -ortvec ${fmat}_mcf_demean.par motdemean \
# -ortvec ${fmat}_mcf_deriv1.par motderiv1 \
# -ortvec ${fmat}_rej_ort.1D meica \
# -censor ${func}_censors.1D \
# -x1D ${func}_nuisreg_mat.1D -xjpeg ${func}_nuisreg_mat.jpg \
# -x1D_uncensored ${func}_nuisreg_uncensored_mat.1D \
# -x1D_stop
# fslmaths ${func_in} -Tmean ${func}_avg
# 3dTproject -polort 0 -input ${func_in}.nii.gz  -mask ${mref}_brain_mask.nii.gz \
# -ort ${func}_nuisreg_uncensored_mat.1D -prefix ${func}_prj.nii.gz \
# -overwrite
# fslmaths ${func}_prj -add ${func}_avg ${func}_den.nii.gz





for e in 2 # $( seq 1 ${nTE} )
do
	echo "DVARS Pre motcor ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
	-o tmp_out -s sub-${sub}/dvars_pre_${flpr}.1D --dvars --nomoco #\
	# -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses}
	echo "DVARS Single Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_echo-${e}_${flpr}.1D --dvars --nomoco #\
	# -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses}
	echo "DVARS MEICA Echo ${e}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/04.${flpr}_task-breathhold_meica_echo-${e}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_meica_echo-${e}_${flpr}.1D --dvars --nomoco #\
	# -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses}
done
for ftype in optcom meica
do
	echo "DVARS ${ftype}"
	fsl_motion_outliers -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed \
	-o tmp_out -s sub-${sub}/dvars_${ftype}_${flpr}.1D --dvars --nomoco #\
	# -m ${wdr}/ME_Denoising/sub-${sub}/GM_ses-${ses}
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