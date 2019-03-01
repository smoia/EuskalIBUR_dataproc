#!/usr/bin/env bash

######### ANATOMICAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# anat
anat=$1
# folders
adir=$2
# MNI
std=$3
mmres=$4

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir}

## 01. Normalization

if [[ ! -e ${std}_mask ]]
then
	fslmaths ${std} -bin ${std}_mask
fi

antsRegistration -d 3 -r [${std}.nii.gz,${anat}_brain.nii.gz,1] \
-o [../reg/${anat}2std,../reg/${anat}2std.nii.gz,../reg/std2${anat}.nii.gz] \
-x [${std}_mask.nii.gz, ${anat}_brain_mask.nii.gz] \
-n Linear -u 0 -w [0.005,0.995] \
-t Rigid[0.1] \
-m MI[${std}.nii.gz,${anat}_brain.nii.gz,1,48,Regular,0.1] \
-c [1000x500x250x100,1e-6,10] \
-f 8x4x2x1 \
-s 3x2x1x0vox \
-t Affine[0.1] \
-m MI[${std}.nii.gz,${anat}_brain.nii.gz,1,48,Regular,0.1] \
-c [1000x500x250x100,1e-6,10] \
-f 8x4x2x1 \
-s 3x2x1x0vox \
-t SyN[0.1,3,0] \
-m CC[${std}.nii.gz,${anat}_brain.nii.gz,1,5] \
-c [100x70x50x20,1e-6,10] \
-f 8x4x2x1 \
-s 3x2x1x0vox \
-z 1 -v 1

## 02. Registration to downsampled MNI

#!#
cd ../reg
WarpImageMultiTransform 3 ../${adir}/${anat}_brain.nii.gz \
${anat}2std_resamp_${mmres}mm.nii.gz -R ${std}_resamp_${mmres}mm.nii.gz ${anat}2std1Warp.nii.gz ${anat}2std0GenericAffine.mat


cd ${cwd}