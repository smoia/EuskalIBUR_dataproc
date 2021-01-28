#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2

wdr=${3:-/data}
tmp=${4:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

if [ -d ${tmp}/tmp.${flpr}_07cr ]; then	rm -rf ${tmp}/tmp.${flpr}_07cr; fi

cd ${wdr} || exit

if [[ ! -d "Mennes_replication" ]]
then
	mkdir Mennes_replication Mennes_replication/fALFF Mennes_replication/RSFA
fi

cd Mennes_replication

for run in $( seq -f %02g 1 4 )
do
	input=00.${flpr}_task-rest_run-${run}_optcom_bold_native_preprocessed
	3dRSFC -input ${fdir}/${input}.nii.gz -band 0.01 0.1 \
		   -mask ${mask}.nii.gz -no_rs_out -nodetrend \
		   -prefix ${tmp}/${input}

	3dresample -input ${tmp}/${input}_fALFF+orig -prefix fALFF/${flpr}_task-rest_run-${run}_fALFF.nii.gz
	3dresample -input ${tmp}/${input}_RSFA+orig -prefix RSFA/${flpr}_task-rest_run-${run}_RSFA.nii.gz
done

cd ${cwd}