#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# echo times
TEs="$3"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

## 01. MEICA
# 01.1. concat in space

eprfx=${func%_echo-*}_echo-
esffx=${func#*_echo-?}

func_optcom=${func%_echo-*}_optcom${esffx}

echo "Merging ${func} for MEICA"
if [[ ! -e ${func}_concat.nii.gz ]];
then
	fslmerge -z ${func}_concat $( ls ${eprfx}* | grep ${esffx}.nii.gz )
fi

echo "Running t2smap"
t2smap -d ${func}_concat.nii.gz -e ${TEs}

echo "Housekeeping"
fslmaths TED.${func}_concat/ts_OC.nii ${func_optcom} -odt float

# 01.3. Compute outlier fraction if there's more than one TR
nTR=$(fslval ${func_optcom} dim4)

if [[ "${nTR}" -gt "1" ]]
then
	echo "Computing outlier fraction in ${func}"
	fslmaths ${func_optcom} -Tmean ${func_optcom}_avg
	bet ${func_optcom}_avg ${func_optcom}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${func_optcom}_brain_mask.nii.gz -fraction -polort 5 -legendre ${func_optcom}.nii.gz > ${func_optcom}_outcount.1D
	imrm ${func_optcom}_avg ${func_optcom}_brain ${func_optcom}_brain_mask
fi

rm -rf *.${func}_concat

cd ${cwd}
