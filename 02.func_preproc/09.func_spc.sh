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

## Temp folder
tmp=${3:-/tmp}
tmp=${tmp}/09fspc_${1}

######################################
######### Script starts here #########
######################################

# Start making the tmp folder
mkdir ${tmp}

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

echo "Computing SPC of ${func} ( [X-avg(X)]/avg(X) )"

fslmaths ${func_in} -Tmean ${tmp}/${func}_mean
fslmaths ${func_in} -sub ${tmp}/${func}_mean -div ${tmp}/${func}_mean ${func}_SPC

rm -rf ${tmp}
cd ${cwd}