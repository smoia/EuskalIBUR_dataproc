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
# Slicetiming
siot=${8:-none}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

nTR=$(fslval ${func} dim4)

## 01. Corrections
# 01.1. Discard first volumes if there's more than one TR

funcsource=${func}
if [[ "${nTR}" -gt "1" && "${vdsc}" -gt "0" ]]
then
	echo "Discarding first ${vdsc} volumes"
	let vdsc--
	fslroi ${func} ${func}_dsd.nii.gz ${vdsc} -1
	funcsource=${func}_dsd
fi
# 01.2. Deoblique & resample
echo "Deoblique and RPI orient ${func}"
3drefit -deoblique ${funcsource}.nii.gz
3dresample -orient RPI -inset ${funcsource}.nii.gz -prefix ${func}_RPI.nii.gz -overwrite
# set name of source for 3dNwarpApply
funcsource=${func}_RPI
# 01.3. Compute outlier fraction if there's more than one TR
if [[ "${nTR}" -gt "1" ]]
then
	echo "Computing outlier fraction in ${func}"
	fslmaths ${func}_RPI -Tmean ${func}_avg
	bet ${func}_avg ${func}_brain -R -f 0.5 -g 0 -n -m
	3dToutcount -mask ${func}_brain_mask.nii.gz -fraction -polort 5 -legendre ${func}_brain.nii.gz > ${func}_outcount.1D
	imrm ${func}_avg ${func}_brain ${func}_brain_mask
fi
# 01.4. Despike if asked
if [[ "${dspk}" -gt "0" ]]
then
	echo "Despike ${func}"
	3dDespike -prefix ${func}_dsk.nii.gz ${func}_RPI.nii.gz
	funcsource=${func}_dsk
fi

## 02. Slice Interpolation

if [[ "${siot}" != "none" ]]
then
	echo "Slice Interpolation of ${func}"
	3dTshift -Fourier -prefix ${func}_si.nii.gz \
	-tpattern ${siot} -overwrite \
	${funcsource}.nii.gz
	funcsource=${func}_si
fi


## 03. PEpolar

if [[ "${brev}" != "none" && "${bfor}" != "none" || "${pepl}" != "none" ]]
then
	if [[ "${pepl}" == "none" ]]
	then
		echo "Computing PEPOLAR map for ${func}"
		pepl=$( echo ${func%_*} | sed 's/_rec-[^_]*//' )_pepolar
		# 03.1. Computing the warping to midpoint
		3dQwarp -plusminus -pmNAMES Rev For \
		-pblur 0.05 0.05 -blur -1 -1 \
		-noweight -minpatch 9 -overwrite \
		-source ${brev}.nii.gz \
		-base ${bfor}.nii.gz \
		-prefix ${pepl}.nii.gz
	fi

	# 03.2. Applying the warping to the functional volume
	echo "Applying PEPOLAR map on ${func}"
	3dNwarpApply -quintic -nwarp ${pepl}_For_WARP.nii.gz \
	-source ${funcsource}.nii.gz -overwrite \
	-prefix ${func}_pe.nii.gz
	funcsource=${func}_pe
fi

## 04. Change name to script output
immv ${funcsource} ${func}_cr

cd ${cwd}