#!/usr/bin/env bash

######### ANATOMICAL 02 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# anat
anat_in=$1
# folders
adir=$2

## Optional
# mask
mask=${3:-none}
aref=${4:-none}
c3dsrc=${5:-yes}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir} || exit

#Read and process input
anat=${anat_in%_*}

if [[ "${mask}" == "none" ]]
then
	# If no mask is specified, then creates it.
	echo "Skull Stripping ${anat}"
	3dSkullStrip -input ${anat_in}.nii.gz \
				 -prefix ${anat}_brain.nii.gz \
				 -orig_vol -overwrite
	fslmaths ${anat}_brain -bin ${anat}_brain_mask
	mask=${anat}_brain_mask
else
	# If a mask is specified, use it.
	# Check if user input is basename or mask itself.
	if [[ -e "${mask}_brain_mask.nii.gz" ]]
	then
		mask=${mask}_brain_mask
	fi
	echo "Masking ${anat}"
	fslmaths ${anat_in} -mas ${mask} ${anat}_brain
	fslmaths ${anat}_brain -bin ${anat}_brain_mask
fi

if [[ "${aref}" != "none" ]] && [[ -e ../reg/${anat}2${aref}_fsl.mat ]]
then
	# If a reference is specified, coreg the mask to the reference
	echo "Flirting ${mask} into ${aref}"
	flirt -in ${mask} -ref ${aref} -cost normmi -searchcost normmi \
		  -init ../reg/${anat}2${aref}_fsl.mat -o ${aref}_brain_mask \
		  -applyxfm -interp nearestneighbour
fi
	
if [[ "${c3dsrc}" != "none" ]]
then
	# If a source for c3d is specified,
	# translate fsl transformation into ants with the right images.
	echo "Moving from FSL to ants in brain extracted images"
	c3d_affine_tool -ref ${anat}_brain -src ${c3dsrc}_brain ../reg/${c3dsrc}2${anat}_fsl.mat \
				    -fsl2ras -oitk ../reg/${c3dsrc}2${anat}0GenericAffine.mat
	# Also transform both skullstripped and not!
	antsApplyTransforms -d 3 -i ${c3dsrc}_brain.nii.gz \
						-r ${anat}_brain.nii.gz -o ../reg/${c3dsrc}_brain2${anat}_brain.nii.gz \
						-n Linear -t ../reg/${c3dsrc}2${anat}0GenericAffine.mat/${c3dsrc}2${anat}0GenericAffine.mat
	antsApplyTransforms -d 3 -i ${c3dsrc}.nii.gz \
						-r ${anat}.nii.gz -o ../reg/${c3dsrc}2${anat}.nii.gz \
						-n Linear -t ../reg/${c3dsrc}2${anat}0GenericAffine.mat
fi


cd ${cwd}