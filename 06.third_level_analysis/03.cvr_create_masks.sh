#!/usr/bin/env bash

wdr=${1:-/data}
tmp=${2:-/tmp}
scriptdir=${3:-/scripts}

cwd=$( pwd )

cd ${wdr}/CVR_reliability/normalised || exit

if [ -d masks ]; then rm -rf masks; fi

mkdir masks

fslmaths ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm -bin masks/brain_mask
fslmaths ${scriptdir}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm -bin masks/GM

# Extract ICC
for sub in 001 002 003 004 007 008 009
do
	for ses in $( seq -f %02g 1 10 )
	do
		fslmaths std_optcom_cvr_masked_${sub}_${ses} -abs -bin masks/std_optcom_mask_${sub}_${ses}
	done
done

cd masks

python3 ${scriptdir}/20.python_scripts/variance_weighted_average.py -ftype cvr -wdr ${wdr}/CVR_reliability/normalised
python3 ${scriptdir}/20.python_scripts/variance_weighted_average.py -ftype lag -wdr ${wdr}/CVR_reliability/normalised

# Some more prep before calling the nulls generator
fslmaths wavg_cvr_masked_optcom -thr 6 -uthr -6 wavg_cvr_thr_6_optcom
3dbucket -prefix ICC2_lag_brick_optcom.nii.gz -abuc ICC2_lag_masked_optcom.nii.gz'[0]' -overwrite
3dbucket -prefix ICC2_cvr_brick_optcom.nii.gz -abuc ICC2_cvr_masked_optcom.nii.gz'[0]' -overwrite

cd ${cwd}
