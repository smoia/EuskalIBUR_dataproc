#!/usr/bin/env bash

######### ANATOMICAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# anat
anat_in=$1
# folders
adir=$2
# MNI
std=$3
mmres=$4

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${adir} || exit

#Read and process input
anat=${anat_in%_*}

## 01. Normalization

if [[ ! -e ../reg/${std}_mask.nii.gz ]]
then
	echo "Creating mask for ${std}"
	fslmaths ../reg/${std} -bin ../reg/${std}_mask
fi

echo "Normalizing ${anat} to ${std}"
antsRegistration -d 3 -r [../reg/${std}.nii.gz,${anat_in}.nii.gz,1] \
				 -o [../reg/${anat}2std,../reg/${anat}2std.nii.gz,../reg/std2${anat}.nii.gz] \
				 -x [../reg/${std}_mask.nii.gz, ${anat_in}_mask.nii.gz] \
				 -n Linear -u 0 -w [0.005,0.995] \
				 -t Rigid[0.1] \
				 -m MI[../reg/${std}.nii.gz,${anat_in}.nii.gz,1,48,Regular,0.1] \
				 -c [1000x500x250x100,1e-6,10] \
				 -f 8x4x2x1 \
				 -s 3x2x1x0vox \
				 -t Affine[0.1] \
				 -m MI[../reg/${std}.nii.gz,${anat_in}.nii.gz,1,48,Regular,0.1] \
				 -c [1000x500x250x100,1e-6,10] \
				 -f 8x4x2x1 \
				 -s 3x2x1x0vox \
				 -t SyN[0.1,3,0] \
				 -m CC[../reg/${std}.nii.gz,${anat_in}.nii.gz,1,5] \
				 -c [100x70x50x20,1e-6,10] \
				 -f 8x4x2x1 \
				 -s 3x2x1x0vox \
				 -z 1 -v 1

## 02. Registration to downsampled MNI
cd ../reg || exit

if [ ! -e ${std}_resamp_${mmres}mm.nii.gz ]
then
	echo "Resampling ${std} at ${mmres}mm"
	ResampleImageBySpacing 3 ${std}.nii.gz ${std}_resamp_${mmres}mm.nii.gz ${mmres} ${mmres} ${mmres} 0
fi

echo "Registering ${anat} to resampled standard"
antsApplyTransforms -d 3 -i ${adir}/${anat_in}.nii.gz \
					-r ${std}_resamp_${mmres}mm.nii.gz -o ${anat}2std_resamp_${mmres}mm.nii.gz \
					-n Linear -t ${anat}2std1Warp.nii.gz -t ${anat}2std0GenericAffine.mat


cd ${cwd}