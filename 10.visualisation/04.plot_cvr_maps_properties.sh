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

	echo "Preparing GM"
	imcp ../sub-${sub}_ses-01_acq-uni_T1w_GM_native sub-${sub}_alltypes_GM_mask
	for ses in $( seq -f %02g 1 ${lastses} )
	do
		fslmaths sub-${sub}_alltypes_GM_mask -mul sub-${sub}/sub-${sub}_ses-${ses}_optcom_cvr \
		-mul sub-${sub}/sub-${sub}_ses-${ses}_optcom_cvr sub-${sub}_alltypes_GM_mask
	done

	fslmaths sub-${sub}_alltypes_GM_mask -abs -bin sub-${sub}_alltypes_GM_mask

echo "Initialising csv files"

	for fname in cvrvals lagvals tvals
	do
		if [[ -e sub-${sub}_${ftype}_${fname}_alltypes_mask.csv ]]; then rm -f sub-${sub}_${ftype}_${fname}_alltypes_mask.csv; fi

		case ${fname} in
			tvals ) fvol=tmap; val=0 ;;
			cvrvals ) fvol=cvr; val=0 ;;
			lagvals ) fvol=cvr_lag; val=$( awk -F',' '{printf("%g",$1 )}' ${wdr}/CVR/sub-${sub}_ses-${ses}_GM_${ftype}_avg_optshift.1D ); echo "Adding ${val} to lag" ;;
		esac

		for ftype in echo-2 optcom meica vessels
		do
			for ses in $( seq -f %02g 1 ${lastses} )
			do
				echo "Extracting voxel informations in session ${ses} for ${fname}"
				echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
				fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_${fvol} -m sub-${sub}_alltypes_allses_mask --showall --transpose \
				| csvtool -t SPACE col 4 - \
				| awk -v val=${val} -F',' '{printf("%g\n",$1+val )}' - >> tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv

			done

		echo "Paste and Trim"
		paste tmp.sub-${sub}_??_${ftype}_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${ftype}_${fname}_alltypes_mask.csv

		rm -f tmp.sub*.csv
		done

		for ftype in echo-2 optcom meica vessels
		do
			for ses in $( seq -f %02g 1 ${lastses} )
			do
				echo "Extracting voxel informations in session ${ses} for ${fname}"
				echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
				fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_${fvol} -m sub-${sub}_alltypes_GM_mask --showall --transpose \
				| csvtool -t SPACE col 4 - \
				| awk -v val=${val} -F',' '{printf("%g\n",$1+val )}' - >> tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv

			done

		echo "Paste and Trim"
		paste tmp.sub-${sub}_??_${ftype}_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${ftype}_${fname}_GM_mask.csv

		rm -f tmp.sub*.csv
		done
	done
done

cd ${cwd}

python3 ./compute_CVR_ICCs.py
python3 ./plot_CVR_changes.py

cd ${cwd}