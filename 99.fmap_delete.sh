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

imrm ${func}
imrm rm.*

cd ${cwd}