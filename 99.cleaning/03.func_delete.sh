#!/usr/bin/env bash

######### FUNCTIONAL DEL for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# folders
fdir=$1
# base volume
func=$2


######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

imrm ${func} ${func}_mcf ${func}_bet ${func}_bet_concat
imrm rm.* tmp.*
if [ -e ${func}_topup/mgdmap.nii.gz ]; then rm ${func}_topup/mgdmap*; fi

cd ${cwd}