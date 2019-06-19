#!/usr/bin/env bash

######### FUNCTIONAL DEL for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# folders
fdir=$1
# anat
func=$2


######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

imrm ${func} ${func}_dsd ${func}_mcf ${func}_bet_concat ${func}_mean ${func}_avg ${func}_prj
imrm rm.*
# rm ${func}_topup/mgdmap

cd ${cwd}