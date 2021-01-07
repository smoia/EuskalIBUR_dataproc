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

tmp=${4:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
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

if [[ ! -e ${tmp}/${func}.nii.gz ]];
then
	echo "Merging ${func} for MEICA"
	fslmerge -z ${tmp}/${func} $( ls ${tmp}/${eprfx}* | grep ${esffx}.nii.gz )
else
	echo "Merged ${func} found!"
fi

if [[ ! -e ${tmp}/${func_optcom} ]]
then
	echo "Running t2smap"
	t2smap -d ${tmp}/${func}.nii.gz -e ${TEs}

	echo "Housekeeping"
	fslmaths TED.${func}/ts_OC.nii.gz ${tmp}/${func_optcom} -odt float
	# Remove TED folder
	rm -rf TED.${func}
fi

# 01.3. Compute outlier fraction if there's more than one TR
nTR=$(fslval ${tmp}/${func_optcom} dim4)

if [[ "${nTR}" -gt "1" ]]
then
	echo "Computing outlier fraction in ${func_optcom}"
	fslmaths ${tmp}/${func_optcom} -Tmean ${tmp}/${func_optcom}_avg
	bet ${tmp}/${func_optcom}_avg ${tmp}/${func_optcom}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${tmp}/${func_optcom}_brain_mask.nii.gz -fraction -polort 5 -legendre ${tmp}/${func_optcom}.nii.gz > ${func_optcom%_bet}_outcount.1D
	imrm ${tmp}/${func_optcom}_avg ${tmp}/${func_optcom}_brain ${tmp}/${func_optcom}_brain_mask
fi

rm -rf ${tmp}/*.${func}

cd ${cwd}
