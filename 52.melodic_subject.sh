#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2${ses}9
#########


sub=$1
ftype=${2:-optcom}
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d DMN ]
then
	mkdir DMN
fi
if [ ! -d DMN/sub-${sub} ]
then
	mkdir DMN/sub-${sub}
fi

echo "Copying session 01"
imcp sub-${sub}/ses-01/sub-${sub}_ses-01_task-rest_run-01_optcom_bold_native_preprocessed DMN/sub-${sub}/ses-01_rest_run-01_${ftype}

lastses=9

reffile=sub-${sub}/ses-01/func_preproc/sub-${sub}_ses-01_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain

imcp ${wdr}/${reffile}_mask DMN/sub-${sub}/mask_${ftype}

for ses in $( seq -f %02g 2 ${lastses} )
do
	infile=sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-rest_run-01_optcom_bold_native_preprocessed
	matfile=sub-${sub}/ses-${ses}/reg/sub-${sub}_ses-${ses}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain2ses-01

	echo "Flirting session ${ses} to session 01"
	flirt -in ${infile} -ref ${reffile} \
	-out DMN/sub-${sub}/ses-${ses}_rest_run-01_${ftype} -interp spline \
	-applyxfm -init ${matfile}.mat

	fslmaths DMN/sub-${sub}/ses-${ses}_rest_run-01_${ftype} -Tmean -add DMN/sub-${sub}/mask_${ftype} -bin DMN/sub-${sub}/mask_${ftype}
done

cd ${wdr}/DMN

ls ses-*.nii.gz > ses_list

echo "Running Melodic"

melodic -in ses_list -m mask_${ftype} -o ses-${ses}_rest_run-01_${ftype}_melodic -d 25

cd ${cwd}