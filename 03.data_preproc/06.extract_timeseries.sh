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

atlas=${wdr}/sub-${sub}/ses-01/atlases/sub-${sub}_${parc}

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
anat=sub-${sub}_ses-01_acq-uni_T1w_GM

if [ ! -e sub-${sub}_GM_native.nii.gz ]
then
	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-01/anat_preproc/${anat}.nii.gz \
						-r ${wdr}/sub-${sub}/ses-${ses}/reg/${mref}.nii.gz \
						-o sub-${sub}_GM_native.nii.gz -n MultiLabel \
						-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat \
						-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1]
fi

fslmaths ${atlas} -mas sub-${sub}_GM_native ${atlas}_masked

# Extract timeseries, label number, and number of voxels in each label
fslmeants -i ${func} --label=${atlas}_masked > ${tmp}/tmp.${flpr}_${parc}_06et/atlas.1D
fslmeants -i ${atlas}_masked --label=${atlas}_masked --transpose > ${atlas}_labels.1D

touch ${atlas}_vx.1D
for n in $(cat ${atlas}_labels.1D)
do
	let l=n-1
	let u=n+1
	fslstats ${atlas}_masked -l ${l} -u ${u} -V >> ${atlas}_vx.1D
done

# Compute SPC

python3 ${scriptdir}/20.python_scripts/compute_1d_spc.py ${tmp}/tmp.${flpr}_${parc}_06et/atlas.1D \
${fdir}/00.${flpr}_task-breathhold_optcom_bold_parc-${parc}.1D
# ${tmp}/tmp.${flpr}_${parc}_06et/spc.1D

# Check that this actually works on 3dDeconvolve, otherwise use labels to format it right
# 3dROIstats -mask ${atlas}_labels.1D -1Dformat \
# 			 ${tmp}/tmp.${flpr}_${parc}_06et/spc.1D > ${fdir}/00.${flpr}_task-breathhold_optcom_bold_parc-${parc}.1D

rm -rf ${tmp}/tmp.${flpr}_${parc}_06et

cd ${cwd}