#!/usr/bin/env bash

######### FUNCTIONAL 01 for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# discard
vdsc=$3
## Optional
# Despiking
dspk=${4:-0}
# PEpolar
pepl=${5:-none}
brev=${6:-none}
bfor=${7:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

nTR=$(fslval ${func} dim4)

## 01. Corrections
# 01.1. Discard first volumes if there's more than one TR
if [[ "${nTR}" -gt "1" -a "${vdsc}" -gt "0" ]]
then
	3dcalc -a ${func}.nii.gz'[${vdsc}..$]' -expr 'a' -prefix ${func}.nii.gz -overwrite
fi
# 01.2. Deoblique & resample
3drefit -deoblique ${func}.nii.gz
3dresample -orient RPI -inset ${func}.nii.gz -prefix ${func}_RPI.nii.gz -overwrite
# 01.3. Compute outlier fraction if there's more than one TR
if [[ "${nTR}" -gt "1" ]]
then
	fslmaths ${func}_RPI -Tmean ${func}_avg
	bet ${func}_avg ${func}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${func}_brain_mask.nii.gz -fraction -polort ${dtdord} -legendre ${func}_brain.nii.gz > ${func}_outcount.1D
	#!#
	imrm ${func}_avg ${func}_brain ${func}_brain_mask
fi
# 01.4. Despike if asked
if [[ "${dspk}" != "0" ]]
then
	3dDespike -prefix ${func}_dsk.nii.gz ${func}_RPI.nii.gz
	#!#
fi

## 02. Slice Interpolation # try quintic or heptic instead of Fourier
# For multiband, you should have a file with the slice time acquisition (sliceorder.txt)
# You can get this information from the .json associated with your acquisition
# 3dTshift -Fourier \
# -prefix ${func}_si.nii.gz \
# -tpattern @sliceorder.txt \
# ${func}_dsk.nii.gz

## 03. PEpolar

if [[ "${brev}" != "none" -a "${bfor}" != "none" -o "${pepl}" != "none" ]]
then
	if [[ "${pepl}" == "none" ]]
	then
		pepl=$( echo ${func%_*} | sed 's/_rec-[^_]*//' )
		# 03.1. Computing the warping to midpoint
		3dQwarp -plusminus -pmNAMES Rev For \
		-pblur 0.05 0.05 -blur -1 -1 \
		-noweight -minpatch 9 \
		-source ${brev} \
		-base ${bfor} \
		-prefix ${pepl}_pepolar
	fi

	# 03.2. Applying the warping to the functional volume
	3dNwarpApply -quintic -nwarp ${pepl}_For_WARP.nii.gz \
	-source ${func}_RPI.nii.gz \
	-prefix ${func}_pe.nii.gz
fi

cd ${cwd}