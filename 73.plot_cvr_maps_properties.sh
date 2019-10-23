#!/usr/bin/env bash

wdr=${1:-/data}
lastses=9

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR/00.Reliability

# 01. Prepare general mask
for sub in 007 003 002
do
	imcp sub-${sub}_echo-2_allses_mask sub-${sub}_alltypes_allses_mask

	for ftype in optcom meica vessels
	do
		fslmaths sub-${sub}_alltypes_allses_mask -mas sub-${sub}_${ftype}_allses_mask \
		sub-${sub}_alltypes_allses_mask
	done
done

echo "Initialising csv files"

for fname in cvrvals lagvals
do
	if [[ -e sub-${sub}_${ftype}_${fname}_alltypes_mask.csv ]]; then rm -f sub-${sub}_${ftype}_${fname}_alltypes_mask.csv; fi

	case ${fname} in
		cvrvals ) fvol=cvr ;;
		lagvals ) fvol=cvr_lag ;;
	esac

	for ftype in echo-2 optcom meica vessels
	do
		for ses in $( seq -f %02g 1 ${lastses} )
		do
			echo "Extracting voxel informations in session ${ses} for ${fname}"
			echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
			fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_${fvol} -m sub-${sub}_alltypes_allses_mask --showall --transpose \
			| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
		done

	echo "Paste and Trim"
	paste tmp.sub-${sub}_??_${ftype}_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${ftype}_${fname}_alltypes_mask.csv

	rm -f tmp.sub*.csv
	done
done

cd ${cwd}

python3 ./compute_CVR_ICCs.py
python3 ./plot_CVR_changes.py

cd ${cwd}