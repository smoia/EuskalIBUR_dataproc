#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# FWHM
fwhm=$3

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

## 01. Smooth
if [ -e "${func}_den.nii.gz" ]
then
	in=${func}_den.nii.gz
else
	in=${func}_pe.nii.gz
fi

3dBlurInMask -input ${in}.nii.gz -prefix ${func}_sm.nii.gz -mask ${func}_brain_mask.nii.gz \
-preserve -FWHM ${fwhm} -overwrite

cd ${cwd}