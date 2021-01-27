#!/usr/bin/env bash

######### FUNCTIONAL 02 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
sbrf_in=$1
# Anat reference
anat=${2:-none}
# folders
fdir=$3
adir=$4

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
sbrf=${sbrf_in%_*}

## 01. BET
echo "BETting ${sbrf}"
bet ${sbrf_in} ${sbrf}_brain -R -f 0.5 -g 0 -n -m

## 02. Anat Coreg

if [[ "${anat}" != "none" ]]
then
	echo "Coregistering ${sbrf} to ${anat}"
	flirt -in ${adir}/${anat}_brain -ref ${sbrf}_brain -out ${anat}2${sbrf} -omat ${anat}2${sbrf}_fsl.mat \
	-searchry -90 90 -searchrx -90 90 -searchrz -90 90
	echo "Affining for ANTs"
	c3d_affine_tool -ref ${sbrf}_brain -src ${adir}/${anat}_brain \
	${anat}2${sbrf}_fsl.mat -fsl2ras -oitk ${anat}2${sbrf}0GenericAffine.mat
fi

cd ${cwd}