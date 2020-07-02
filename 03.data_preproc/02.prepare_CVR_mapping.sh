#!/usr/bin/env bash

sub=$1
ses=$2
wdr=${3:-/data}

adir=anat_preproc
fdir=func_preproc

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

if [ ! -d CVR ]
then
	mkdir CVR
fi

anat=sub-${sub}_ses-01_acq-uni_T1w
func=sub-${sub}_ses-${ses}_task-breathhold
mref=sub-${sub}_sbref
aref=sub-${sub}_ses-01_T2w

if [ ! -e ${wdr}/CVR/sub-${sub}_GM_native.nii.gz ]
then
	antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-${ses}/${adir}/${anat}_GM.nii.gz -r ${wdr}/sub-${sub}/ses-${ses}/reg/${mref}.nii.gz \
						-o ${wdr}/CVR/sub-${sub}_GM_native.nii.gz -n MultiLabel \
						-t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat \
						-t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1]
fi

cd ${wdr}/CVR

if [ ! -e sub-${sub}_GM_eroded.nii.gz ]
then
	fslmaths sub-${sub}_GM_native -kernel gauss 2.5 -ero sub-${sub}_GM_eroded
fi

for ftype in echo-2 optcom
do
	fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/00.${func}_${ftype}_bold_native_preprocessed \
			  -m sub-${sub}_GM_eroded > sub-${sub}_ses-${ses}_GM_${ftype}_avg.1D
done

cp ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${func}_echo-1_bold_mcf_demean.par ./sub-${sub}_ses-${ses}_motpar_demean.par
cp ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${func}_echo-1_bold_mcf_deriv1.par ./sub-${sub}_ses-${ses}_motpar_deriv1.par

cd ${cwd}