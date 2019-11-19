#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# FWHM
fwhm=$3
# mask
mask=$4

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

## 01. Smooth
if [ -e "${func}_den.nii.gz" ]
then
	in=${func}_den.nii.gz
else
	in=${func}_bet.nii.gz
fi

echo "Smoothing ${func}"
3dBlurInMask -input ${in} -prefix ${func}_sm.nii.gz -mask ${mask}.nii.gz \
-preserve -FWHM ${fwhm} -overwrite

cd ${cwd}