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
if [[ ${sub} == "002" ]]
then
	lastses=9
else
	lastses=10
fi

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
if [[ -e sub-${sub}_tvals.csv ]]; then rm -f sub-${sub}_tvals.csv; fi
if [[ -e sub-${sub}_cvrvals.csv ]]; then rm -f sub-${sub}_cvrvals.csv; fi
if [[ -e sub-${sub}_lagvals.csv ]]; then rm -f sub-${sub}_lagvals.csv; fi

for ses in $( seq -f %02g 1 ${lastses} )
do
	echo "Extracting voxel informations in session ${ses}"
	echo "ses-${ses}" > tmp.sub-${sub}_${ses}_cvrvals.csv
	fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_cvr -m sub-${sub}_allses_mask --showall --transpose \
	| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_cvrvals.csv
	echo "ses-${ses}" > tmp.sub-${sub}_${ses}_lagvals.csv
	fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_cvr_lag -m sub-${sub}_allses_mask --showall --transpose \
	| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_lagvals.csv
	echo "ses-${ses}" > tmp.sub-${sub}_${ses}_tvals.csv
	fslmeants -i sub-${sub}/sub-${sub}_ses-${ses}_tmap -m sub-${sub}_allses_mask --showall --transpose \
	| csvtool -t SPACE col 4 - >> tmp.sub-${sub}_${ses}_tvals.csv
done

paste tmp.sub-${sub}_??_cvrvals.csv -d , > sub-${sub}_cvrvals.csv
paste tmp.sub-${sub}_??_lagvals.csv -d , > sub-${sub}_lagvals.csv
paste tmp.sub-${sub}_??_tvals.csv -d , > sub-${sub}_tvals.csv

rm -f tmp.sub*.csv

echo "Trim"
csvtool trim sub-${sub}_tvals.csv
csvtool trim sub-${sub}_cvrvals.csv
csvtool trim sub-${sub}_lagvals.csv

cd ${cwd}