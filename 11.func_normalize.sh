#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# file
func=$1
anat=$2
mref=$3
std=$4
# folders
fdir=$4
# other
mmres=$5
anat2=${6:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

WarpImageMultiTransform 3 ${func}_sm.nii.gz ${func}_std.nii.gz \
-R ../reg/${std}_resamp_${mmres}mm.nii.gz \
../reg/${anat}2std1Warp.nii.gz \
../reg/${anat}2std0GenericAffine.mat \
../reg/${anat2}2${anat}0GenericAffine.mat \
-i ../reg/${anat2}2${mref}0GenericAffine.mat

cd ${cwd}