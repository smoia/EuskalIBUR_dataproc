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

imrm ${func} ${func}_mcf ${func}_bet ${func}_bet_concat \
${func}_mean ${func}_avg ${func}_prj ${func}_RPI_bet_concat \
${func}_RPI_bet_OC ${func}_RPI_mcf
imrm rm.* tmp.*
if [ -e ${func}_topup/mgdmap.nii.gz ]; then rm ${func}_topup/mgdmap*; fi

cd ${cwd}







## Temp folder
tmp=${4:-/tmp}
tmp=${tmp}/01fc_${1}

######################################
######### Script starts here #########
######################################

# Start making the tmp folder
mkdir ${tmp}




${tmp}/


rm -rf ${tmp}