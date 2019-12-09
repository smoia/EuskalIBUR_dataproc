#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2
wdr=${3:-/data}
step=${4:-39}
overwrite=${5:-overwrite}
### Main ###

cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "BHT_decomp" ]]; then mkdir BHT_decomp; fi

if [ ! -e BHT_decomp/sub-${sub}_ses-${ses}_trials-8.nii.gz ]
then
	echo "Copy optcom BH volume into new folder"
	imcp sub-${sub}/ses-${ses}/func_preproc/01.sub-${sub}_ses-${ses}_task-breathhold_optcom_bold_native_SPC_preprocessed BHT_decomp/sub-${sub}_ses-${ses}_trials-8
fi
if [ ! -e BHT_decomp/sub-${sub}_ses-${ses}_rest.nii.gz ]
then
	echo "Copy optcom RS volume into new folder"
	imcp sub-${sub}/ses-${ses}/func_preproc/01.sub-${sub}_ses-${ses}_task-rest_run-01_optcom_bold_native_SPC_preprocessed BHT_decomp/sub-${sub}_ses-${ses}_rest
fi
if [ ! -e BHT_decomp/sub-${sub}_mask.nii.gz ]
then
	echo "Copy mask into new folder"
	imcp sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain_mask.nii.gz BHT_decomp/sub-${sub}_mask
fi

cd BHT_decomp

echo "Run melodic on 8 trials of BH for sub ${sub} ses ${ses}"
melodic -i sub-${sub}_ses-${ses}_trials-8 -o sub-${sub}_ses-${ses}_trials-8 -m sub-${sub}_mask --update_mask --report
echo "Run melodic on RS for sub ${sub} ses ${ses}"
melodic -i sub-${sub}_ses-${ses}_rest -o sub-${sub}_ses-${ses}_rest -m sub-${sub}_mask --update_mask --report

for trial in 1 2 3 5
do
	let cut=step*trial
	if [ ! -e sub-${sub}_ses-${ses}_trials-${trial} ]
	then
		echo "Prepare ${trial} trials of BH"
		fslroi sub-${sub}_ses-${ses}_trials-8 sub-${sub}_ses-${ses}_trials-${trial} 0 ${cut}
	fi

	if [ ! -d sub-${sub}_ses-${ses}_trials-${trial} ] || [[ ${overwrite} == "overwrite" ]]
	then
		echo "Run melodic on ${trial} trials of BH for sub ${sub} ses ${ses}"
		melodic -i sub-${sub}_ses-${ses}_trials-${trial} -o sub-${sub}_ses-${ses}_trials-${trial} -m sub-${sub}_mask --update_mask --report
	fi
done

cd ${cwd}