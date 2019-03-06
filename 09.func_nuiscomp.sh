#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# files
func=$1
anat=$2
aref=$3
mref=$4
# folders
fdir=$5
adir=$6
# action
dprj=${7:-1}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}


#!# Maybe this can go in a separate file
if [ -e "${adir}/${anat}_seg_eroded.nii.gz" ]
then
	if [ [ ! -e "${adir}/${anat}_seg_native.nii.gz" ] || [ ! -e "${adir}/${anat}_GM_native.nii.gz" ] ]
	then
		echo "Coregistering segmentations to ${func}"
		antsApplyTransforms -d 3 -i ${adir}/${anat}_seg_eroded.nii.gz -r ../${fdir}/${mref}.nii.gz \
		-o ${adir}/${anat}_seg_native.nii.gz -n MultiLabel \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1] \
		-t ../reg/${aref}2${mref}0GenericAffine.mat
		antsApplyTransforms -d 3 -i ${adir}/${anat}_GM_dilated.nii.gz -r ../${fdir}/${mref}.nii.gz \
		-o ${adir}/${anat}_GM_native.nii.gz -n MultiLabel \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1] \
		-t ../reg/${aref}2${mref}0GenericAffine.mat
	fi
	echo "Extracting average WM and CSF in ${func}"
	3dDetrend -polort 5 -prefix ${func}_dtd.nii.gz ${func}_mcf.nii.gz -overwrite
	fslmeants -i ${func}_dtd.nii.gz -o ${func}_avg_tissue.1D --label=../anat_preproc/seg_native.nii.gz
fi

## 04. Nuisance computation
# 04.2. Create matrix
# add censoring, save matrix w and w/o censoring
echo "Preparing nuisance matrix"
3dDeconvolve -input ${func}_mcf.nii.gz \
-polort 5 -float \
-num_stimts  2 \
-stim_file 1 ${func}_avg_tissue.1D'[0]' -stim_base 1 -stim_label 1 CSF \
-stim_file 2 ${func}_avg_tissue.1D'[2]' -stim_base 2 -stim_label 2 WM \
-ortvec ${func}_mcf_demean.par motdemean \
-ortvec ${func}_mcf_deriv1.par motderiv1 \
-ortvec ${func}_meica/rej_ort.par meica \
-x1D ${func}_nuisreg_mat.1D -xjpeg ${func}_nuisreg_mat.jpg \
-x1D_uncensored ${func}_nuisreg_uncensored_mat.1D \
-x1D_stop
	# -censor censor_${subj}_combined_2.1D -cenmode ZERO \

## 06. Nuisance

if [ "${dprj}" -gt "0" ]
then
	echo "Actually applying nuisance"
	fslmaths ${func}_mcf -Tmean ${func}_avg
	3dTproject -polort 0 -input ${func}_mcf.nii.gz  -mask func_mask.nii.gz \
	-ort ${func}_nuisreg_uncensored_mat.1D -prefix ${func}_prj.nii.gz \
	-overwrite
	fslmaths ${func}_prj -add ${func}_avg ${func}_den.nii.gz
fi


cd ${cwd}