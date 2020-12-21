#!/usr/bin/env bash

######### ANATOMICAL DEL for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# folders
adir=$1
# base volume
anat=$2


######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir} || exit

imrm ${anat} ${anat}_bfc

cd ${cwd}