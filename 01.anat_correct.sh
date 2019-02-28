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
aref=${3:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir}

## 01. Deoblique & resample
echo "Resample"
3drefit -deoblique ${anat}.nii.gz 
3dresample -orient RPI -inset ${anat}.nii.gz -prefix ${anat}_RPI.nii.gz -overwrite
echo "Done"

## 02. Bias Field Correction with ANTs
# 02.1. Truncate (0.01) for Bias Correction # try with 0.01-0.95 (this helps skullstripping too)
echo "Performing BFC"
ImageMath 3 ${anat}_trunc.nii.gz TruncateImageIntensity ${anat}_RPI.nii.gz 0.02 0.98 256
# 02.2. Bias Correction
N4BiasFieldCorrection -d 3 -i ${anat}_trunc.nii.gz -o ${anat}_bfc.nii.gz
echo "Done"

## 03. Anat coreg
if [ "${aref}" != "none" ]
then
	flirt -in ${anat} -ref ${aref} -cost normmi -searchcost normmi -omat ../reg/${anat}2${aref}.mat
fi

cd ${cwd}