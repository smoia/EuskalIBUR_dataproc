#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# file
func_in=$1
# folders
fdir=$2

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

echo "Computing SPC of ${func} ( [X-avg(X)]/avg(X) )"

fslmaths ${func_in} -Tmean ${func}_mean
fslmaths ${func_in} -sub ${func}_mean -div ${func}_mean ${func}_SPC

cd ${cwd}