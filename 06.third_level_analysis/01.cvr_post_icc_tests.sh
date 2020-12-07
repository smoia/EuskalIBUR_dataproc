#!/usr/bin/env bash

wdr=${1:-/data}
tmp=${2:-/tmp}
scriptdir=${3:-/scripts}

cwd=$( pwd )

cd ${wdr}/CVR_reliability || exit

if [ -d tests ]; then rm -rf tests; fi

mkdir tests tests/val tests/stats

fslmaths ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm -bin mask
fslmaths ${scriptdir}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm -bin GM

for map in masked_physio_only # masked # corrected
do
	for inmap in cvr lag
	do
		inmap=${inmap}_${map}
		for ftype in echo-2 optcom meica-aggr meica-cons meica-orth
		do
			# Extract ICC
			fslmeants -i ICC2_${inmap}_${ftype}.nii.gz -m mask.nii.gz --showall --transpose > tests/val/ICC2_${inmap}_${ftype}.txt
			fslmeants -i ICC2_${inmap}_${ftype}.nii.gz -m GM.nii.gz --showall --transpose > tests/val/ICC2_${inmap}_${ftype}_GM.txt
			# Compute statistics
			fslstats -t ICC2_${inmap}_${ftype}.nii.gz -k mask.nii.gz -M -S > tests/stats/stats_ICC2_${inmap}_${ftype}.txt
			fslstats -t ICC2_${inmap}_${ftype}.nii.gz -k GM.nii.gz -M -S > tests/stats/stats_ICC2_${inmap}_${ftype}_GM.txt
		done
	done
done

cd tests

python3 ${scriptdir}/20.python_scripts/post_icc_tests.py

rm mask.nii.gz

cd ${cwd}