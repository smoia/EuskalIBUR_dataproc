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

echo "Initialising csv files"

	for fname in cvrvals lagvals tvals
	do
		if [[ -e sub-${sub}_${ftype}_${fname}_alltypes_mask.csv ]]; then rm -f sub-${sub}_${ftype}_${fname}_alltypes_mask.csv; fi

		case ${fname} in
			tvals ) fvol=tmap ;;
			cvrvals ) fvol=cvr ;;
			lagvals ) fvol=cvr_lag ;;
		esac

		for ftype in echo-2 optcom meica vessels
		do
			for ses in $( seq -f %02g 1 ${lastses} )
			do
				case ${fname} in
					tvals ) val=0 ;;
					cvrvals ) val=0 ;;
					lagvals ) val=$( awk -F',' '{printf("%g",$1 )}' ${wdr}/CVR/sub-${sub}_ses-${ses}_GM_${ftype}_avg_optshift.1D ); echo "Adding ${val} to lag" ;;
				esac

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
				case ${fname} in
					tvals ) val=0 ;;
					cvrvals ) val=0 ;;
					lagvals ) val=$( awk -F',' '{printf("%g",$1 )}' ${wdr}/CVR/sub-${sub}_ses-${ses}_GM_${ftype}_avg_optshift.1D ); echo "Adding ${val} to lag" ;;
				esac

				echo "Extracting voxel informations in session ${ses} for ${fname}"
				echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
				fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_${fvol} -m ../sub-${sub}_ses-${ses}_acq-uni_T1w_GM_native --showall --transpose \
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