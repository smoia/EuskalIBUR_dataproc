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
### Main ###

cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "BHT_decomp" ]]; then mkdir BHT_decomp; fi

echo "Copy optcom volume into new folder"
imcp sub-${sub}/ses-${ses}/func_preproc/01.sub-${sub}_ses-${ses}_task-breathhold_optcom_bold_native_SPC_preprocessed BHT_decomp/sub-${sub}_ses-${ses}_trials-8
imcp sub-${sub}/ses-${ses}/func_preproc/01.sub-${sub}_ses-${ses}_task-rest_run-01_optcom_bold_native_SPC_preprocessed BHT_decomp/sub-${sub}_ses-${ses}_rest

cd BHT_decomp

echo "Run melodic on 8 trials of BH for sub ${sub} ses ${ses}"
melodic -i sub-${sub}_ses-${ses}_trials-8 -o sub-${sub}_ses-${ses}_trials-8 --report
echo "Run melodic on RS for sub ${sub} ses ${ses}"
melodic -i sub-${sub}_ses-${ses}_rest -o sub-${sub}_ses-${ses}_rest --report

for trial in $( seq 2 7 )
do
	let cut=step*trial
	echo "Prepare ${trial} trials of BH"
	fslroi sub-${sub}_ses-${ses}_trials-8 sub-${sub}_ses-${ses}_trials-${trial} 0 ${cut}

	echo "Run melodic on ${trial} trials of BH for sub ${sub} ses ${ses}"
	melodic -i sub-${sub}_ses-${ses}_trials-${trial} -o sub-${sub}_ses-${ses}_trials-${trial} --report
done

cd ${cwd}