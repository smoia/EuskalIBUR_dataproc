#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2${ses}9
#########


sub=$1
ftype=$2
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d CVR/00.Reliability ]
then
	mkdir CVR/00.Reliability
fi
if [ ! -d CVR/00.Reliability/sub-${sub} ]
then
	mkdir CVR/00.Reliability/sub-${sub}
fi

echo "Copying session 01"
imcp CVR/sub-${sub}_ses-01_${ftype}_map_cvr/sub-${sub}_ses-01_${ftype}_cvr_idx_mask CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_${ftype}_cvr_idx_mask
imcp CVR/sub-${sub}_ses-01_${ftype}_map_cvr/sub-${sub}_ses-01_${ftype}_cvr CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_${ftype}_cvr
imcp CVR/sub-${sub}_ses-01_${ftype}_map_cvr/sub-${sub}_ses-01_${ftype}_cvr_lag CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_${ftype}_cvr_lag
imcp CVR/sub-${sub}_ses-01_${ftype}_map_cvr/sub-${sub}_ses-01_${ftype}_tmap CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_${ftype}_tmap

echo "Initialising common mask"
imcp CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_${ftype}_cvr_idx_mask CVR/00.Reliability/sub-${sub}_${ftype}_allses_mask
# coreg
# if [[ ${sub} == "002" ]]
# then
# 	lastses=9
# else
# 	lastses=10
# fi

lastses=9

reffile=sub-${sub}/ses-01/func_preproc/sub-${sub}_ses-01_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain
for ses in $( seq -f %02g 2 ${lastses} )
do
	infile=sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain
	outfile=sub-${sub}/ses-${ses}/reg/sub-${sub}_ses-${ses}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain2ses-01

	echo "Flirting session ${ses} to session 01"
	flirt -in ${infile} -ref ${reffile} -out ${outfile} -omat ${outfile}.mat -cost normcorr -searchcost normcorr
	flirt -in CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_cvr -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_cvr_lag -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_tmap -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat

	echo "Updating common mask"
	fslmaths CVR/00.Reliability/sub-${sub}_${ftype}_allses_mask -mas CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask \
	CVR/00.Reliability/sub-${sub}_${ftype}_allses_mask
done

cd ${wdr}/CVR/00.Reliability
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
		fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${ftype}_${fvol} -m sub-${sub}_${ftype}_allses_mask --showall --transpose \
		| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_${ftype}_${fname}.csv
	done

	echo "Paste and Trim"
	paste tmp.sub-${sub}_??_${ftype}_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${ftype}_${fname}.csv

	rm -f tmp.sub-${sub}*.csv
done

cd ${cwd}