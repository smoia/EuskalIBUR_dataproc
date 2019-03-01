#!/usr/bin/env bash

######### ANATOMICAL 01 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# anat
anat=$1
# folders
adir=$2

## Optional
# mask
mask=${3:-none}
aref=${4:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir}

if [[ "${mask}" == "none" ]]
then
	3dSkullStrip -input ${anat}_bfc.nii.gz \
	-prefix ${anat}_brain.nii.gz \
	-orig_vol -overwrite
	fslmaths ${anat}_brain -bin ${anat}_brain_mask
elif [[ -e "${mask}.nii.gz" ]]; then
	fslmaths ${anat}_bfc -mas ${mask} ${anat}_brain
elif [[ -e "${mask}_brain_mask.nii.gz" ]]; then
	fslmaths ${anat}_bfc -mas ${mask}_brain_mask ${anat}_brain
else
	echo "**** WARNING"
	echo "**** A problem arose with the specified mask"
	echo "**** Check this step"
fi

if [[ "${aref}" != "none" ]]
then
	flirt -in ${mask} -ref ${aref} -cost normmi -searchcost normmi \
	-init ../reg/${anat}2${aref}.mat -o ${aref}_brain_mask
fi
	

cd ${cwd}