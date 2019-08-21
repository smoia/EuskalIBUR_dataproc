#!/usr/bin/env bash

wdr=/media

adir=anat_preproc
fdir=func_preproc

### Main ###
cwd=$( pwd )
cd ${wdr}

if [ ! -d CVR ]
then
	mkdir CVR
fi

for sub in $( seq -f %03g 1 10 )
do
	for ses in $( seq -f %02g 1 10 )
	do
		flpr=sub-${sub}_ses-${ses}
		
		anat=${flpr}_acq-uni_T1w
		func=${flpr}_task-breathhold_echo-1_bold
		mref=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr
		aref=${flpr}_T2w

		# antsApplyTransforms -d 3 -i ${wdr}/sub-${sub}/ses-${ses}/${adir}/${anat}_GM.nii.gz -r ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${mref}.nii.gz \
		# -o ${wdr}/CVR/${anat}_GM_native.nii.gz -n MultiLabel \
		# -t [${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${anat}0GenericAffine.mat,1] \
		# -t ${wdr}/sub-${sub}/ses-${ses}/reg/${aref}2${mref}0GenericAffine.mat

		cd ${wdr}/CVR

		fslmaths ${anat}_GM_native -kernel gauss 2.5 -ero ${anat}_GM_eroded

		fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${func}_RPI_bet_meica/ts_OC -m ${anat}_GM_eroded > sub-${sub}_ses-${ses}_GM_OC_avg.txt

		cp ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${func}_mcf_demean.par ./sub-${sub}_ses-${ses}_demean.par
		cp ${wdr}/sub-${sub}/ses-${ses}/${fdir}/${func}_mcf_deriv1.par ./sub-${sub}_ses-${ses}_deriv1.par

		# Here should go the decomposition extraction
	done
done

cd ${cwd}