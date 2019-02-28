#!/usr/bin/env bash

######### ANATOMICAL 02 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# anat
anat=$1
# folders
adir=$2

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir}

## 01. Atropos (segmentation)
# 01.1. Run Atropos
Atropos -d 3 -a ${anat}_brain.nii.gz \
-o ${anat}_seg.nii.gz \
-x ${anat}_brain_mask.nii.gz -i kmeans[3] \
--use-partial-volume-likelihoods \
-s 1x2 -s 2x3 \
-v 1

## 02. Split, erode & dilate
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,1)' -prefix ${anat}_CSF.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,3)' -prefix ${anat}_WM.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,2)' -prefix ${anat}_GM.nii.gz -overwrite

dicsf=-2
diwm=-3

3dmask_tool -input ${anat}_CSF.nii.gz -prefix ${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
3dmask_tool -input ${anat}_WM.nii.gz -prefix ${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
3dmask_tool -input ${anat}_GM.nii.gz -prefix ${anat}_GM_dilated.nii.gz -dilate_input 2 -overwrite

until [ [ "$(fslstats ${anat}_CSF_eroded -p 100)" != "0" ] || [ "${dicsf}" == "0" ] ]
do
	let dicsf+=1
	3dmask_tool -input ${anat}_CSF.nii.gz -prefix ${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
done 
until [ [ "$(fslstats ${anat}_WM_eroded -p 100)" != "0" ] || [ "${diwm}" == "0" ] ]
do
	let diwm+=1
	3dmask_tool -input ${anat}_WM.nii.gz -prefix ${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
done

# Checking that the CSF mask doesn't cointain GM
fslmaths ${anat}_CSF_eroded -sub ${anat}_GM_dilated.nii.gz -thr 0 ${anat}_CSF_eroded

# Recomposing masks
fslmaths ${anat}_GM -mul 2 ${anat}_GM
fslmaths ${anat}_WM_eroded -sub ${anat}_CSF -thr 0 -mul 3 -add ${anat}_CSF_eroded -add ${anat}_GM ${anat}_seg_eroded

cd ${cwd}