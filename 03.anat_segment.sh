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
   #uiuhu
cwd=$(pwd)

cd ${adir}

## 01. Atropos (segmentation)
# 01.1. Run Atropos
echo "Segmenting ${anat}"
Atropos -d 3 -a ${anat}_brain.nii.gz \
-o ${anat}_seg.nii.gz \
-x ${anat}_brain_mask.nii.gz -i kmeans[3] \
--use-partial-volume-likelihoods \
-s 1x2 -s 2x3 \
-v 1

## 02. Split, erode & dilate
echo "Splitting the segmented files, eroding and dilating"
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,1)' -prefix ${anat}_CSF.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,3)' -prefix ${anat}_WM.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,2)' -prefix ${anat}_GM.nii.gz -overwrite

dicsf=-3
diwm=-4

3dmask_tool -input ${anat}_CSF.nii.gz -prefix ${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
3dmask_tool -input ${anat}_WM.nii.gz -prefix ${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
3dmask_tool -input ${anat}_GM.nii.gz -prefix ${anat}_GM_dilated.nii.gz -dilate_input 2 -overwrite
fslmaths ${anat}_GM_dilated -mas ${anat}_brain_mask ${anat}_GM_dilated

#!# Further release: Check number voxels > compcorr components
until [ "$(fslstats ${anat}_CSF_eroded -p 100)" != "0" -o "${dicsf}" == "0" ]
do
	let dicsf+=1
	echo "Too much erosion, setting new erosion to ${dicsf}"
	3dmask_tool -input ${anat}_CSF.nii.gz -prefix ${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
done 
until [ "$(fslstats ${anat}_WM_eroded -p 100)" != "0" -o "${diwm}" == "0" ]
do
	let diwm+=1
	echo "Too much erosion, setting new erosion to ${diwm}"
	3dmask_tool -input ${anat}_WM.nii.gz -prefix ${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
done

# Checking that the CSF mask doesn't cointain GM
echo "Checking that the CSF doesn't contain GM"
fslmaths ${anat}_CSF_eroded -sub ${anat}_GM_dilated.nii.gz -thr 0 ${anat}_CSF_eroded

# Recomposing masks
echo "Recomposing the eroded maps into one volume"
fslmaths ${anat}_GM -mul 2 ${anat}_GM
fslmaths ${anat}_WM_eroded -sub ${anat}_CSF -thr 0 -mul 3 -add ${anat}_CSF_eroded -add ${anat}_GM ${anat}_seg_eroded

cd ${cwd}