#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# file
func_in=$1
anat=$2
mref=$3
std=$4
# folders
fdir=$5
# other
mmres=$6
anat2=${7:-none}

tmp=${8:-.}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

echo "Normalising ${func}"
antsApplyTransforms -d 3 -i ${tmp}/${func_in}.nii.gz \
-r ../reg/${std}_resamp_${mmres}mm.nii.gz -o ${tmp}/${func}_std.nii.gz \
-n Linear -t [../reg/${anat2}2${mref}0GenericAffine.mat,1] \
-t ../reg/${anat2}2${anat}0GenericAffine.mat \
-t ../reg/${anat}2std0GenericAffine.mat \
-t ../reg/${anat}2std1Warp.nii.gz

cd ${cwd}