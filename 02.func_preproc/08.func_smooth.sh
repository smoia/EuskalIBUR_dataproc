#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func_in=$1
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

#Read and process input
func=${func_in%_*}

## 01. Smooth

echo "Smoothing ${func}"
3dBlurInMask -input ${func_in} -prefix ${func}_sm.nii.gz -mask ${mask}.nii.gz \
-preserve -FWHM ${fwhm} -overwrite

cd ${cwd}