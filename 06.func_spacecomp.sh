#!/usr/bin/env bash

######### FUNCTIONAL 02 for PJMASK
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
if [[ "${mref}" == "none" ]]
then
	echo "Creating a reference for ${func}"
	mref=${func}_avgref
	fslmaths ${func}_cr -Tmean ${mref}
fi

echo "McFlirting ${func}"
if [[ -d ${func}_mcf.mat ]]; then rm -r ${func}_mcf.mat; fi
mcflirt -in ${func}_cr -r ${mref} -out ${func}_mcf -stats -mats -plots

# 01.2. Demean motion parameters
echo "Demean and derivate ${func} motion parameters"
1d_tool.py -infile ${func}_mcf.par -demean -write ${func}_mcf_demean.par -overwrite
1d_tool.py -infile ${func}_mcf_demean.par -derivative -write ${func}_mcf_deriv1.par -overwrite


if [[ ! -e "${mref}_brain_mask" ]]
then
	echo "BETting reference ${mref}"
	bet ${mref} ${mref}_brain -R -f 0.5 -g 0 -n -m
fi

# 01.3. Compute various metrics
echo "Computing DVARS and FD for ${func}"
fsl_motion_outliers -i ${func}_mcf -o ${func}_mcf_dvars_confounds -s ${func}_dvars_post.par -p ${func}_dvars_post --dvars --nomoco
fsl_motion_outliers -i ${func}_cr -o ${func}_mcf_dvars_confounds -s ${func}_dvars_pre.par -p ${func}_dvars_pre --dvars --nomoco
fsl_motion_outliers -i ${func}_cr -o ${func}_mcf_fd_confounds -s ${func}_fd.par -p ${func}_fd --fd

# 01.4. Apply mask
echo "BETting ${func}"
fslmaths ${func}_mcf -mas ${mref}_brain_mask ${func}_bet

## 02. Anat Coreg

if [[ "${anat}" != "none" && ! -e "../reg/${anat}2${mref}0GenericAffine.mat" ]]
then
	echo "Coregistering ${func} to ${anat}"
	flirt -in ${anat}_brain -ref ${mref}_brain -out ${anat}2${mref} -omat ${anat}2${mref}_fsl.mat \
	-searchry -90 90 -searchrx -90 90 -searchrz -90 90
	echo "Affining for ANTs"
	c3d_affine_tool -ref ${mref}_brain -src ${anat}_brain \
	${anat}2${mref}_fsl.mat -fsl2ras -oitk ${anat}2${mref}0GenericAffine.mat
	mv ${anat}2${mref}* ../reg/.
fi

## 03. Split and affine to ANTs if required
if [[ "${jstr}" -gt 0 ]]
then
	echo "Splitting ${func}"
	if [[ ! -d "${func}_split" ]]; then mkdir ${func}_split; fi
	if [[ ! -d "../reg/${func}_mcf_ants_mat" ]]; then mkdir ../reg/${func}_mcf_ants_mat; fi
	fslsplit ${func}_cr ${func}_split/vol_ -t

	for i in $( seq -f %04g 0 ${nTR} )
	do
		echo "Affining volume ${i} of ${nTR} in ${func}"
		c3d_affine_tool -ref ${mref}_brain_mask -src ${func}_split/vol_${i}.nii.gz \
		${func}_mcf.mat/MAT_${i} -fsl2ras -oitk ../reg/mcf_ants_mat/v${i}2${func}.mat
	done
	rm -r ${func}_split
fi

if [[ -d ../reg/${func}_mcf.mat ]]; then rm -r ../reg/${func}_mcf.mat; fi
mv ${func}_mcf.mat ../reg/.

cd ${cwd}