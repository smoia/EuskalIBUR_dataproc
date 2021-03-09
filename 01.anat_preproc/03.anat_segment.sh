#!/usr/bin/env bash

######### ANATOMICAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# anat
anat_in=$1
# folders
adir=$2

## Temp folder
tmp=${3:-/tmp}
tmp=${tmp}/03as_${1}

######################################
######### Script starts here #########
######################################

# Start making the tmp folder
mkdir ${tmp}

cwd=$(pwd)

cd ${adir} || exit

#Read and process input
anat=${anat_in%_*}

## 01. Atropos (segmentation)
# 01.1. Run Atropos
echo "Segmenting ${anat}"
Atropos -d 3 -a ${anat_in}.nii.gz \
-o ${anat}_seg.nii.gz \
-x ${anat}_brain_mask.nii.gz -i kmeans[3] \
--use-partial-volume-likelihoods \
-s 1x2 -s 2x3 \
-v 1

## 02. Split, erode & dilate
echo "Splitting the segmented files, eroding and dilating"
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,1)' -prefix ${tmp}/${anat}_CSF.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,3)' -prefix ${anat}_WM.nii.gz -overwrite
3dcalc -a ${anat}_seg.nii.gz -expr 'equals(a,2)' -prefix ${anat}_GM.nii.gz -overwrite

dicsf=-2
diwm=-3

3dmask_tool -input ${tmp}/${anat}_CSF.nii.gz -prefix ${tmp}/${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
3dmask_tool -input ${anat}_WM.nii.gz -prefix ${tmp}/${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
3dmask_tool -input ${anat}_GM.nii.gz -prefix ${anat}_GM_dilated.nii.gz -dilate_input 2 -overwrite
fslmaths ${anat}_GM_dilated -mas ${anat_in}_mask ${anat}_GM_dilated

#!# Further release: Check number voxels > compcorr components
until [ "$(fslstats ${tmp}/${anat}_CSF_eroded -p 100)" != "0" -o "${dicsf}" == "0" ]
do
	let dicsf+=1
	echo "Too much erosion, setting new erosion to ${dicsf}"
	3dmask_tool -input ${tmp}/${anat}_CSF.nii.gz -prefix ${tmp}/${anat}_CSF_eroded.nii.gz -dilate_input ${dicsf} -overwrite
done 
until [ "$(fslstats ${tmp}/${anat}_WM_eroded -p 100)" != "0" -o "${diwm}" == "0" ]
do
	let diwm+=1
	echo "Too much erosion, setting new erosion to ${diwm}"
	3dmask_tool -input ${anat}_WM.nii.gz -prefix ${tmp}/${anat}_WM_eroded.nii.gz -fill_holes -dilate_input ${diwm} -overwrite
done

# Checking that the CSF mask doesn't cointain GM
echo "Checking that the CSF doesn't contain GM"
fslmaths ${tmp}/${anat}_CSF_eroded -sub ${anat}_GM_dilated.nii.gz -thr 0 ${tmp}/${anat}_CSF_eroded

# Recomposing masks
echo "Recomposing the eroded maps into one volume"
fslmaths ${anat}_GM -mul 2 ${anat}_GM
fslmaths ${tmp}/${anat}_WM_eroded -sub ${tmp}/${anat}_CSF -thr 0 -mul 3 -add ${tmp}/${anat}_CSF_eroded -add ${anat}_GM ${anat}_seg_eroded

rm -rf ${tmp}
cd ${cwd}