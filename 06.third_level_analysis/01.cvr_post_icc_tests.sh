#!/usr/bin/env bash

wdr=${1:-/data}
tmp=${2:-/tmp}
scriptdir=${3:-/scripts}

cwd=$( pwd )

cd ${wdr}/CVR_reliability || exit

if [ -d tests ]; then rm -rf tests; fi

mkdir tests tests/val

cd tests

fslmaths ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm -bin mask

for map in masked # corrected
do
	for inmap in cvr lag
	do
		inmap=${inmap}_${map}
		for ftype in echo-2 optcom meica-aggr meica-cons meica-orth all-orth
		do
			# Extract ICC
			fslmeants -i ICC2_${inmap}_${ftype}.nii.gz -m mask.nii.gz --showall --transpose > val/ICC2_${inmap}_${ftype}.txt

			# Extract CoV
			for sub in 001 002 003 004 007 008 009
			do
				fslmeants -i CoV_${sub}_${inmap}_${ftype}.nii.gz -m mask.nii.gz --showall --transpose > val/CoV_${inmap}_${ftype}.txt
			done
		done
	done
done

python3 ${scriptdir}/20.python_scripts/post_icc_tests.py

cd ${cwd}