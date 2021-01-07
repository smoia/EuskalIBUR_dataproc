#!/usr/bin/env bash

######### FUNCTIONAL 01 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# discard
vdsc=${3:-0}
## Optional
# Despiking
dspk=${4:-none}
# Slicetiming
siot=${5:-none}

## Temp folder
tmp=${6:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

nTR=$(fslval ${tmp}/${func} dim4)

## 01. Corrections
# 01.1. Discard first volumes if there's more than one TR

funcsource=${tmp}/${func}
if [[ "${nTR}" -gt "1" && "${vdsc}" -gt "0" ]]
then
	echo "Discarding first ${vdsc} volumes"
	# The next line was added due to fslroi starting from 0, however it does not.
	# let vdsc--
	fslroi ${funcsource} ${tmp}/${func}_dsd.nii.gz ${vdsc} -1
	funcsource=${tmp}/${func}_dsd
fi
# 01.2. Deoblique & resample
echo "Deoblique and RPI orient ${func}"
3drefit -deoblique ${funcsource}.nii.gz
3dresample -orient RPI -inset ${funcsource}.nii.gz -prefix ${tmp}/${func}_RPI.nii.gz -overwrite
# set name of source for 3dNwarpApply
funcsource=${tmp}/${func}_RPI
# 01.3. Compute outlier fraction if there's more than one TR
if [[ "${nTR}" -gt "1" ]]
then
	echo "Computing outlier fraction in ${func}"
	fslmaths ${funcsource} -Tmean ${tmp}/${func}_avg
	bet ${tmp}/${func}_avg ${tmp}/${func}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${tmp}/${func}_brain_mask.nii.gz -fraction -polort 5 -legendre ${funcsource}.nii.gz > ${func}_outcount.1D
fi

# 01.4. Despike if asked
if [[ "${dspk}" != "none" ]]
then
	echo "Despike ${func}"
	3dDespike -prefix ${tmp}/${func}_dsk.nii.gz ${funcsource}.nii.gz
	funcsource=${tmp}/${func}_dsk
fi

## 02. Slice Interpolation if asked
if [[ "${siot}" != "none" ]]
then
	echo "Slice Interpolation of ${func}"
	3dTshift -Fourier -prefix ${tmp}/${func}_si.nii.gz \
	-tpattern ${siot} -overwrite \
	${funcsource}.nii.gz
	funcsource=${tmp}/${func}_si
fi

## 03. Change name to script output
immv ${funcsource} ${tmp}/${func}_cr

cd ${cwd}