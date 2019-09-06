#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2${ses}9
#########

# wdr=/media
wdr=/media/nemo/ANVILData/gdrive/PJMASK

sub=$1

### Main ###
cwd=$( pwd )
cd ${wdr}

echo "Creating folders"
mkdir CVR/00.Reliability CVR/00.Reliability/sub-${sub}

echo "Copying session 01"
imcp CVR/sub-${sub}_ses-01_map_cvr/sub-${sub}_ses-01_cvr_idx_mask CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_cvr_idx_mask
imcp CVR/sub-${sub}_ses-01_map_cvr/sub-${sub}_ses-01_cvr CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_cvr
imcp CVR/sub-${sub}_ses-01_map_cvr/sub-${sub}_ses-01_cvr_lag CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_cvr_lag
imcp CVR/sub-${sub}_ses-01_map_cvr/sub-${sub}_ses-01_tmap CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_tmap

echo "Initialising common mask"
imcp CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-01_cvr_idx_mask CVR/00.Reliability/sub-${sub}_allses_mask
# coreg
# if [[ ${sub} == "002" ]]
# then
# 	lastses=9
# else
# 	lastses=10
# fi

lastses=9

for ses in $( seq -f %02g 2 ${lastses} )
do
	infile=sub-${sub}/ses-${ses}/func_preproc/sub-${sub}_ses-${ses}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain
	reffile=sub-${sub}/ses-01/func_preproc/sub-${sub}_ses-01_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain
	outfile=sub-${sub}/ses-${ses}/reg/sub-${sub}_ses-${ses}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain2ses-01

	echo "Flirting session ${ses} to session 01"
	flirt -in ${infile} -ref ${reffile} -out ${outfile} -omat ${outfile}.mat -cost normcorr -searchcost normcorr
	flirt -in CVR/sub-${sub}_ses-${ses}_map_cvr/sub-${sub}_ses-${ses}_cvr_idx_mask -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_cvr_idx_mask -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_map_cvr/sub-${sub}_ses-${ses}_cvr -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_cvr -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_map_cvr/sub-${sub}_ses-${ses}_cvr_lag -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_cvr_lag -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat
	flirt -in CVR/sub-${sub}_ses-${ses}_map_cvr/sub-${sub}_ses-${ses}_tmap -ref ${reffile} \
	-out CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_tmap -interp nearestneighbour \
	-applyxfm -init ${outfile}.mat

	echo "Updating common mask"
	fslmaths CVR/00.Reliability/sub-${sub}_allses_mask -mas CVR/00.Reliability/sub-${sub}/sub-${sub}_ses-${ses}_cvr_idx_mask \
	CVR/00.Reliability/sub-${sub}_allses_mask
done

cd ${wdr}/CVR/00.Reliability
echo "Initialising csv files"

for fname in tvals cvrvals lagvals
do
	if [[ -e sub-${sub}_${fname}.csv ]]; then rm -f sub-${sub}_${fname}.csv; fi

	case ${fname} in
		tvals ) fvol=tmap ;;
		cvrvals ) fvol=cvr ;;
		lagvals ) fvol=cvr_lag ;;
	esac

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Extracting voxel informations in session ${ses} for ${fname}"
		echo "ses-${ses}" > tmp.sub-${sub}_${ses}_${fname}.csv
		fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_${fvol} -m sub-${sub}_allses_mask --showall --transpose \
		| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_${fname}.csv
	done

	echo "Paste and Trim"
	paste tmp.sub-${sub}_??_${fname}.csv -d , | csvtool trim b - > sub-${sub}_${fname}.csv

	rm -f tmp.sub*.csv
done

cd ${cwd}