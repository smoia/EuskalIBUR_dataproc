#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
rep=$2

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${3:-/data}
scriptdir=${4:-/scripts}
tmp=${5:-/tmp}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

mref=sub-${sub}_sbref
aref=sub-${sub}_ses-01_T2w
anat=sub-${sub}_ses-01_acq-uni_T1w


for pnum in $(seq 2 120)
do
	for size in $(seq 3 15)
	do
		parc=rand-${pnum}p-${size}s-${rep}r
		atlas=${scriptdir}/90.template/rand_atlas/${parc}
		afunc=${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}
		echo "Move atlas ${parc} in sub-${sub} functional space"
		# transfrom vessels territories atlas from MNI to func space
		antsApplyTransforms -d 3 -i ${atlas}.nii.gz \
							-r ${wdr}/sub-${sub}/ses-01/reg/${mref}.nii.gz \
							-o ${afunc}.nii.gz -n MultiLabel \
							-t ${wdr}/sub-${sub}/ses-01/reg/${aref}2${mref}0GenericAffine.mat \
							-t [${wdr}/sub-${sub}/ses-01/reg/${aref}2${anat}0GenericAffine.mat,1] \
							-t [${wdr}/sub-${sub}/ses-01/reg/${anat}2std0GenericAffine.mat,1] \
							-t ${wdr}/sub-${sub}/ses-01/reg/${anat}2std1InverseWarp.nii.gz -v
	done
done

cd ${cwd}