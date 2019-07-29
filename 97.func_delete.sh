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

cd ${fdir}_preproc

imrm ${func} ${func}_dsd ${func}_mcf ${func}_bet_concat \
${func}_mean ${func}_avg ${func}_prj ${func}_RPI_bet_concat \
${func}_RPI_bet_OC ${func}_RPI_mcf
imrm rm.*
if [ -e ${func}_topup/mgdmap.nii.gz ]; then rm ${func}_topup/mgdmap*; fi

cd ${cwd}