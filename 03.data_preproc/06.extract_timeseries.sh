#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
ses=$2
parc=$3

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${5:-/data}
scriptdir=${6:-/scripts}
tmp=${7:-/tmp}

atlas=${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc

flpr=sub-${sub}_ses-${ses}
func=00.${flpr}_task-breathhold_optcom_bold_native_preprocessed

### Main ###

cwd=$( pwd )

cd ${fdir} || exit

# (Re)-creating temporal files folder
if [ -d ${tmp}/tmp.${flpr}_${parc}_06et ]
then
	rm -rf ${tmp}/tmp.${flpr}_${parc}_06et
fi
mkdir ${tmp}/tmp.${flpr}_${parc}_06et

# Mask atlas by the GM

mref=sub-${sub}_sbref
aref=sub-${sub}_ses-01_T2w
anat=sub-${sub}_ses-01_acq-uni_T1w

if [ ! -e sub-${sub}_GM_native.nii.gz ]
then
	echo "Move GM in functional space"
	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-01/anat_preproc/${anat}_GM.nii.gz \
						-r ${wdr}/sub-${sub}/ses-${ses}/reg/${mref}.nii.gz \
						-o sub-${sub}_GM_native.nii.gz -n MultiLabel \
						-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat \
						-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1]
fi

if [ ! -e ${atlas}_masked.nii.gz ]
then
	echo "Mask atlas by GM"
	fslmaths ${atlas} -mas sub-${sub}_GM_native ${atlas}_masked
fi

# Extract timeseries, label number, and number of voxels in each label
echo "Extract timeseries, label number, and number of voxels in each label"
fslmeants -i ${func} --label=${atlas}_masked > ${tmp}/tmp.${flpr}_${parc}_06et/atlas_timeseries.1D
fslmeants -i ${atlas}_masked --label=${atlas}_masked --transpose > ${tmp}/tmp.${flpr}_${parc}_06et/atlas_labels.1D

# Remove really empty labels #!# coming soon

if [ ! -e ${atlas}_labels.1D ]
then
	echo "Paste labels"
	mv ${tmp}/tmp.${flpr}_${parc}_06et/atlas_labels.1D ${atlas}_labels.1D
fi

if [ ! -e ${atlas}_vx.1D ]
then
	echo "Count voxels..."
	touch ${tmp}/tmp.${flpr}_${parc}_06et/sub-${sub}_${parc}_vx.1D
	for n in $(cat ${atlas}_labels.1D)
	do
		n=${n%.*}
		echo "... in parcel ${n}"
		let l=n-1
		let u=n+1
		fslstats ${atlas}_masked -l ${l} -u ${u} -V >> ${tmp}/tmp.${flpr}_${parc}_06et/sub-${sub}_${parc}_vx.1D
	done

	mv ${tmp}/tmp.${flpr}_${parc}_06et/sub-${sub}_${parc}_vx.1D ${atlas}_vx.1D
fi
# Compute SPC

echo "Compute SPC"
python3 ${scriptdir}/20.python_scripts/compute_1d_spc.py ${tmp}/tmp.${flpr}_${parc}_06et/atlas_timeseries.1D \
${fdir}/00.${flpr}_task-breathhold_optcom_bold_parc-${parc}.1D
# ${tmp}/tmp.${flpr}_${parc}_06et/spc.1D

# Check that this actually works on 3dDeconvolve, otherwise use labels to format it right
# 3dROIstats -mask ${atlas}_labels.1D -1Dformat \
# 			 ${tmp}/tmp.${flpr}_${parc}_06et/spc.1D > ${fdir}/00.${flpr}_task-breathhold_optcom_bold_parc-${parc}.1D

rm -rf ${tmp}/tmp.${flpr}_${parc}_06et

cd ${cwd}