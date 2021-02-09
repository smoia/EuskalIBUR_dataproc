#!/usr/bin/env bash

######### FUNCTIONAL 12 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    09.02.2021
#########

## Variables
# functional
func_in=$1
# folders
fdir=$2

## Optional
# Anat reference
anat=${3:-none}
# Motion reference file
mref=${4:-none}

# Anat used for segmentation
aseg=${6:-none}

# Detrending
pol=${7:-4}

## Temp folder
tmp=${8:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%.nii*}
tmp=${tmp}/12gp_${func}
mkdir ${tmp}

if [[ ! -e "${mref}_brain_mask" && "${mref}" != "none" ]]
then
	echo "BETting reference ${mref}"
	bet ${mref} ${tmp}/${mref}_brain -R -f 0.5 -g 0 -n -m
	mref=${tmp}/${mref}_brain
elif [[ "${mref}" == "none" ]]
then
	bet ${func} ${tmp}/${func}_brain -R -f 0.5 -g 0 -n -m
	mref=${tmp}/${func}_brain
fi

## 02. Anat Coreg

if [[ ! -e "../reg/${anat}2${mref}0GenericAffine.mat" ]]
then
	echo "Coregistering ${func} to ${anat}"
	flirt -in ${anat}_brain -ref ${mref} -out ${tmp}/${anat}2${mref} -omat ${tmp}/${anat}2${mref}_fsl.mat \
	-searchry -90 90 -searchrx -90 90 -searchrz -90 90
	echo "Affining for ANTs"
	c3d_affine_tool -ref ${mref} -src ${anat}_brain \
	${tmp}/${anat}2${mref}_fsl.mat -fsl2ras -oitk ${tmp}/${anat}2${mref}0GenericAffine.mat
	a2m=${tmp}/${anat}2${mref}0GenericAffine.mat
else
	a2m=../reg/${anat}2${mref}0GenericAffine.mat
fi
if [[ ! -e "../anat_preproc/${seg}_seg2mref.nii.gz" ]]
then
	echo "Coregistering anatomical segmentation to ${func}"
	antsApplyTransforms -d 3 -i ../anat_preproc/${aseg}_seg.nii.gz \
						-r ${mref}.nii.gz -o ${tmp}/seg2mref.nii.gz \
						-n Multilabel -v \
						-t ${a2m} \
						-t [../reg/${anat}2${aseg}0GenericAffine.mat,1]
	seg=${tmp}/seg2mref
else
	seg=../anat_preproc/${seg}_seg2mref
fi

#Plot some grayplots!
3dGrayplot -input ${func}.nii.gz -mask ${seg}.nii.gz \
		   -prefix ${func}_gp_PVO.png -dimen 1800 1200 \
		   -polort ${pol} -pvorder -percent
3dGrayplot -input ${func}.nii.gz -mask ${seg}.nii.gz \
		   -prefix ${func}_gp_IJK.png -dimen 1800 1200 \
		   -polort ${pol} -ijkorder -percent
3dGrayplot -input ${func}.nii.gz -mask ${seg}.nii.gz \
		   -prefix ${func}_gp_peel.png -dimen 1800 1200 \
		   -polort ${pol} -peelorder -percent

rm -rf ${tmp}

cd ${cwd}