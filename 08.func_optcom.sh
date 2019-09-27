#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# echo times
TEs="$3"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

## 01. MEICA
# 01.1. concat in space

eprfx=${func%_echo-*}_echo-
esffx=${func#*_echo-?}

echo "Merging ${func} for MEICA"
fslmerge -z ${func}_concat $( ls ${eprfx}* | grep ${esffx}.nii.gz )

echo "Running t2smap"
t2smap -d ${func}_concat.nii.gz -e ${TEs}

echo "Housekeeping"
fslmaths TED.${func}_concat/ts_OC.nii ${func%_echo-*}_optcom${esffx} -odt float

rm -rf *.${func}_concat

cd ${cwd}
