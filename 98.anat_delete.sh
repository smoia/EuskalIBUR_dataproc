#!/usr/bin/env bash

######### ANATOMICAL DEL for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# folders
adir=$1
# anat
anat=$2


######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir}

imrm ${anat} ${anat}_RPI ${anat}_trunc ${anat}_CSF ${anat}_WM

cd ${cwd}