#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func_in=$1
# folders
fdir=$2
# echo times
TEs="$3"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
eprfx=${func_in%_echo-*}_echo-
esffx=${func_in#*_echo-?}
func=${func_in%_echo-*}_concat${esffx}
func_optcom=${func_in%_echo-*}_optcom${esffx}

## 01. MEICA
# 01.1. concat in space

if [[ ! -e ${func}.nii.gz ]];
then
	echo "Merging ${func} for MEICA"
	fslmerge -z ${func} $( ls ${eprfx}* | grep ${esffx}.nii.gz )
else
	echo "Merged ${func} found!"
fi

echo "Running t2smap"
t2smap -d ${func}.nii.gz -e ${TEs}

echo "Housekeeping"
fslmaths TED.${func}/ts_OC.nii ${func_optcom} -odt float

# 01.3. Compute outlier fraction if there's more than one TR
nTR=$(fslval ${func_optcom} dim4)

if [[ "${nTR}" -gt "1" ]]
then
	echo "Computing outlier fraction in ${func_optcom}"
	fslmaths ${func_optcom} -Tmean ${func_optcom}_avg
	bet ${func_optcom}_avg ${func_optcom}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${func_optcom}_brain_mask.nii.gz -fraction -polort 5 -legendre ${func_optcom}.nii.gz > ${func_optcom}_outcount.1D
	imrm ${func_optcom}_avg ${func_optcom}_brain ${func_optcom}_brain_mask
fi

rm -rf *.${func}

cd ${cwd}
