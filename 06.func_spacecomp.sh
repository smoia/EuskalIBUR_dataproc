#!/usr/bin/env bash

######### FUNCTIONAL 02 for PJMASK
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
# Anat reference
anat=${4:-none}
# Motion reference file
mref=${5:-none}
# Joint transform Flag
jstr=${6:-0}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

nTR=$(fslval ${func} dim4)
let nTR=nTR-${vdsc}-1

## 01. Motion Computation

# 01.1. Mcflirt
echo "McFlirting"

if [[ "${mref}" == "none" ]]
then
	mref=${func}_avgref
	fslmaths ${func}_pe -Tmean ${mref}
fi

mcflirt -in ${func}_pe -r ${mref} -out ${func}_mcf -stats -mats -plots

# 01.2. Demean motion parameters
1d_tool.py -infile ${func}_mcf.par -demean -write ${func}_mcf_demean.par
#!#


if [[ ! -e "${mref}_brain_mask" ]]
then
	bet ${mref} ${mref}_brain -R -f 0.5 -g 0 -n -m
fi

# 01.3. Compute various metrics
fsl_motion_outlier -i ${func}_mcf -o ${func}_mcf_dvars_confounds -s ${func}_dvars.par -p ${func}_dvars \
--dvars --nomoco --dummy=${vdsc} -m ${mref}_brain_mask
# Momentarily
#!# 0.3
fsl_motion_outlier -i ${func}_pe -o ${func}_mcf_fd_confounds -s ${func}_fd.par -p ${func}_fd \
--fd --dummy=${vdsc} -m ${mref}_brain_mask

## 02. Anat Coreg

if [[ "${anat}" != "none" ]]
then
	flirt -in ${anat} -ref ${mref}_brain_mask -out ${anat}2${mref} -omat ${anat}2${mref}_fsl.mat \
	-searchry -90 90 -searchrx -90 90 -searchrz -90 90
	echo "Affining"
	c3d_affine_tool -ref ${mref}_brain_mask -src ${anat} \
	${anat}2${mref}_fsl.mat -fsl2ras -oitk ${anat}2${mref}0GenericAffine.mat
	mv ${anat}2${mref}* ../reg/.
fi

## 03. Split and affine to ANTs if required
if [[ "${jstr}" -gt 0 ]]
then
	if [[ ! -d "${func}_split" ]]; then mkdir ${func}_split; fi
	if [[ ! -d "../reg/${func}_mcf_ants_mat" ]]; then mkdir ../reg/${func}_mcf_ants_mat; fi
	fslsplit ${func}_pe ${func}_split/vol_ -t

	for i in $( seq -f %04g 0 ${nTR} )
	do
		c3d_affine_tool -ref ${mref}_brain_mask -src ${func}_split/vol_${i}.nii.gz \
		${func}_mcf.mat/MAT_${i} -fsl2ras -oitk ../reg/mcf_ants_mat/v${i}2${func}.mat
	done
	rm -r ${func}_split
fi

mv ${func}_mcf.mat ../reg/.

cd ${cwd}