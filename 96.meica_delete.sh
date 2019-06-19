#!/usr/bin/env bash

######### MEICA DEL for PJMASK
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

cd ${fdir}/${func}_tedana

imrm t2sv s0v lowk_* midk_* hik_* betas_* t2ss s0vs
rm __meica_mix.txt

cd ${cwd}