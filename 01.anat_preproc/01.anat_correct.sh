#!/usr/bin/env bash

######### ANATOMICAL 01 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# anat
anat_in=$1
# folders
adir=$2

## Optional
aref_in=${3:-none}

## Temp folder
tmp=${4:-/tmp}

# shellcheck source=EuskalIBUR_dataproc/utils.sh
source ${sdr}/utils.sh
######################################
######### Script starts here #########
######################################

# Start making the tmp folder
if_missing_do mkdir ${tmp}

cwd=$(pwd)

cd ${adir} || exit

#Read and process input
anat=${anat_in%.nii.gz}
anat=${anat##*/}
aref=${aref_in%.nii.gz}
aref=${aref##*/}

# 01. Deoblique & resample
echo "Resample ${anat}"
3drefit -deoblique ${anat}.nii.gz 
3dresample -orient RPI -inset ${anat}.nii.gz -prefix ${tmp}/${anat}_RPI.nii.gz -overwrite

## 02. Bias Field Correction with ANTs
# 02.1. Truncate (0.01) for Bias Correction
echo "Performing BFC on ${anat}"
ImageMath 3 ${tmp}/${anat}_trunc.nii.gz TruncateImageIntensity ${tmp}/${anat}_RPI.nii.gz 0.02 0.98 256
# 02.2. Bias Correction
N4BiasFieldCorrection -d 3 -i ${tmp}/${anat}_trunc.nii.gz -o ${tmp}/${anat}_bfc.nii.gz

## 03. Anat coreg between modalities
if [[ "${aref}" != "none" ]]
then
	echo "Flirting ${anat} on ${aref}"
	flirt -in ${anat} -ref ${aref_in} -cost normmi -searchcost normmi \
	-omat ../reg/${anat}2${aref}_fsl.mat -o ../reg/${anat}2${aref}_fsl.nii.gz
fi

cd ${cwd}