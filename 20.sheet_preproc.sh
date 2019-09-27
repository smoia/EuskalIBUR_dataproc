#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###
cwd=$( pwd )

echo "Processing sheet"
python3 sheet_preproc.py

cd ${wdr}

for sub in 007 003 002
do
	for ses in $( seq -f %02g 1 9 )
	do
		echo "Denoising sub ${sub} ses ${ses}"
		func=sub-${sub}/ses-${ses}/func_preproc/00.sub-${sub}_ses-${ses}_task-breathhold_optcom_bold_native_preprocessed.nii.gz
		fsl_regfilt -i ${func} \
		-d sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_echo-1_bold_RPI_bet_meica/meica_mix.1D \
		-f "$( cat sub-${sub}_ses-${ses}_rejected.1D )" \
		-o sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_meica_bold_bet
		fsl_regfilt -i ${func} \
		-d sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_echo-1_bold_RPI_bet_meica/meica_mix.1D \
		-f "$( cat sub-${sub}_ses-${ses}_vascular.1D )" \
		-o sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_meica_bold_bet_vascular
		fsl_regfilt -i ${func} \
		-d sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_echo-1_bold_RPI_bet_meica/meica_mix.1D \
		-f "$( cat sub-${sub}_ses-${ses}_networks.1D )" \
		-o sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_meica_bold_bet_network

		exit
	done
done

cd ${cwd}