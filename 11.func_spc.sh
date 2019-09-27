#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# file
func=$1
# folders
fdir=$2

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

echo "Computing SPC of ${func} ( [X-avg(X)]/avg(X) )"

fslmaths ${func} -Tmean ${func}_mean
fslmaths ${func} -sub ${func}_mean -div ${func}_mean ${func}_SPC

cd ${cwd}