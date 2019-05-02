#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# files
func=$1
fmat=$2
anat=$3
aref=$4
mref=$5
# folders
fdir=$6
adir=$7
# action
dprj=${8:-1}
# thresholds
mthr=${9:-0.3}
othr=${10:-0.05}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}


#!# Maybe this can go in a separate file
if [ -e "${adir}/${anat}_seg_eroded.nii.gz" ]
then
	if [[ ! -e "${adir}/${anat}_seg_native.nii.gz" || ! -e "${adir}/${anat}_GM_native.nii.gz" ]]
	then
		echo "Coregistering segmentations to ${func}"
		antsApplyTransforms -d 3 -i ${adir}/${anat}_seg_eroded.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${anat}_seg_native.nii.gz -n MultiLabel \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1] \
		-t ../reg/${aref}2${mref}0GenericAffine.mat
		antsApplyTransforms -d 3 -i ${adir}/${anat}_GM_dilated.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${anat}_GM_native.nii.gz -n MultiLabel \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1] \
		-t ../reg/${aref}2${mref}0GenericAffine.mat
	fi
	echo "Extracting average WM and CSF in ${func}"
	3dDetrend -polort 5 -prefix ${func}_dtd.nii.gz ${func}_bet.nii.gz -overwrite
	fslmeants -i ${func}_dtd.nii.gz -o ${func}_avg_tissue.1D --label=${adir}/${anat}_seg_native.nii.gz
fi

## 04. Nuisance computation
# 04.1. Preparing censoring of fd > b & c > d in AFNI format
echo "Preparing censoring"
1deval -a ${fmat}_fd.par -b=${mthr} -c ${func}_outcount.1D -d=${othr} -expr 'isnegative(a-b)*isnegative(c-d)' > ${func}_censors.1D

# 04.2. Create matrix
echo "Preparing nuisance matrix"
3dDeconvolve -input ${func}_bet.nii.gz \
-polort 5 -float \
-num_stimts  2 \
-stim_file 1 ${func}_avg_tissue.1D'[0]' -stim_base 1 -stim_label 1 CSF \
-stim_file 2 ${func}_avg_tissue.1D'[2]' -stim_base 2 -stim_label 2 WM \
-ortvec ${fmat}_mcf_demean.par motdemean \
-ortvec ${fmat}_mcf_deriv1.par motderiv1 \
-ortvec ${fmat}_bet_rej_ort.1D meica \
-censor ${func}_censors.1D \
-x1D ${func}_nuisreg_mat.1D -xjpeg ${func}_nuisreg_mat.jpg \
-x1D_uncensored ${func}_nuisreg_uncensored_mat.1D \
-x1D_stop
# -cenmode ZERO \


## 06. Nuisance

if [[ "${dprj}" -gt "0" ]]
then
	echo "Actually applying nuisance"
	fslmaths ${func}_bet -Tmean ${func}_avg
	3dTproject -polort 0 -input ${func}_bet.nii.gz  -mask ${mref}_brain_mask.nii.gz \
	-ort ${func}_nuisreg_uncensored_mat.1D -prefix ${func}_prj.nii.gz \
	-overwrite
	fslmaths ${func}_prj -add ${func}_avg ${func}_den.nii.gz
fi


cd ${cwd}
