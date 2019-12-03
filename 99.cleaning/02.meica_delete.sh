#!/usr/bin/env bash

######### MEICA DEL for PJMASK
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

cd ${fdir}/${func}_meica || exit

imrm t2sv s0v lowk_* midk_* hik_* betas_hik_* t2ss s0vs mepca_OC_*

imrm tmp.* rm.*

cd ${cwd}