#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2${ses}9
#########


sub=$1
ftype=$2
lastses=${3:-5}
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr}/CVR || exit

echo "Creating folders"
if [ ! -d 00.Reliability ]
then
	mkdir 00.Reliability
fi

for ses in $( seq -f %02g 1 ${lastses} )
do
	echo "Copying session ${ses}"
	imcp sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr 00.Reliability/sub-${sub}_ses-${ses}_${ftype}_cvr
	imcp sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_simple 00.Reliability/sub-${sub}_ses-${ses}_${ftype}_cvr_simple
	imcp sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag 00.Reliability/sub-${sub}_ses-${ses}_${ftype}_cvr_lag
	imcp sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap 00.Reliability/sub-${sub}_ses-${ses}_${ftype}_tmap
done

echo "Initialising common mask"
imcp sub-${sub}_ses-01_${ftype}_map_cvr/sub-${sub}_ses-01_${ftype}_cvr_idx_mask 00.Reliability/sub-${sub}_${ftype}_allses_mask
for ses in $( seq -f %02g 2 ${lastses} )
do
	echo "Updating common mask"
	fslmaths 00.Reliability/sub-${sub}_${ftype}_allses_mask -mas sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask \
	00.Reliability/sub-${sub}_${ftype}_allses_mask
done

cd 00.Reliability
echo "Initialising csv files"

for fname in tvals cvrvals lagvals
do
	if [[ -e sub-${sub}_${ftype}_${fname}.csv ]]; then rm -f sub-${sub}_${ftype}_${fname}.csv; fi

	case ${fname} in
		tvals ) fvol=tmap ;;
		cvrvals ) fvol=cvr ;;
		lagvals ) fvol=cvr_lag ;;
	esac

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Extracting voxel informations in session ${ses} for ${fname}"
		echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
		fslmeants -i sub-${sub}_ses-${ses}_${ftype}_${fvol} -m sub-${sub}_${ftype}_allses_mask --showall --transpose \
		| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
	done

	echo "Paste and Trim"
	paste tmp.sub-${sub}_??_${ftype}_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${ftype}_${fname}.csv

	rm -f tmp.sub-${sub}*${ftype}*.csv
done

cd ${cwd}