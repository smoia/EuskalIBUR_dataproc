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
fwhm=${3:-5}
# mask
mask=$4

## Temp folder
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

## 01. Smooth

echo "Smoothing ${func}"
3dBlurInMask -input ${tmp}/${func_in}.nii.gz -prefix ${tmp}/${func}_sm.nii.gz -mask ${mask}.nii.gz \
-preserve -FWHM ${fwhm} -overwrite

cd ${cwd}