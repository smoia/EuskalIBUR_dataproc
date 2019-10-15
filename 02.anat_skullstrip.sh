#!/usr/bin/env bash

######### ANATOMICAL 02 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
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
c3dsrc=${5:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir} || exit

if [[ "${mask}" == "none" ]]
then
	echo "Skull Stripping ${anat}"
	3dSkullStrip -input ${anat}_bfc.nii.gz \
	-prefix ${anat}_brain.nii.gz \
	-orig_vol -overwrite
	fslmaths ${anat}_brain -bin ${anat}_brain_mask
	mask=${anat}_brain_mask
else
	if [[ -e "${mask}_brain_mask.nii.gz" ]]
	then
		mask=${mask}_brain_mask
	fi
	echo "Masking ${anat}"
	fslmaths ${anat}_bfc -mas ${mask} ${anat}_brain
	fslmaths ${anat}_brain -bin ${anat}_brain_mask
fi

if [[ "${aref}" != "none" ]]
then
	echo "Flirting ${mask} into ${aref}"
	flirt -in ${mask} -ref ${aref} -cost normmi -searchcost normmi \
	-init ../reg/${anat}2${aref}_fsl.mat -o ${aref}_brain_mask \
	-applyxfm -interp nearestneighbour
fi
	
if [[ "${c3dsrc}" != "none" ]]
then
	echo "Moving from FSL to ants in brain extracted images"
	c3d_affine_tool -ref ${anat}_brain -src ${c3dsrc}_brain \
	../reg/${c3dsrc}2${anat}_fsl.mat -fsl2ras -oitk ../reg/${c3dsrc}2${anat}0GenericAffine.mat
fi


cd ${cwd}