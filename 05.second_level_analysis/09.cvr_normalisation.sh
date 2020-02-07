#!/usr/bin/env bash

ftype=${1:-optcom}
lastses=${2:-10}
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d CVR_reliability ]
then
	mkdir CVR_reliability
fi

cd CVR_reliability

mkdir reg
mkdir normalised

# Copy files for transformation
cp /scripts/MNI_T1_putamen_cerebellum.nii.gz ./reg/.
cp /scripts/MNI152_T1_1mm_brain.nii.gz ./reg/MNI_T1_brain_1mm.nii.gz
cp /scripts/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz

# Copy
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 05 || ${sub} == 06 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	# this has to be simplified
	imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain.nii.gz \
		 ./reg/${sub}_sbref_brain.nii.gz
	imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask.nii.gz \
		 ./reg/${sub}_sbref_brain_mask.nii.gz
	imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1InverseWarp.nii.gz \
		 ./reg/${sub}_T1w2std1InverseWarp.nii.gz
	imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
		 ./reg/${sub}_T1w2std1Warp.nii.gz
	cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
	   ./reg/${sub}_T1w2std0GenericAffine.mat
	cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
	   ./reg/${sub}_T2w2sbref0GenericAffine.mat
	cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
	   ./reg/${sub}_T2w2T1w0GenericAffine.mat

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Copying session ${ses}"
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.nii.gz \
			 ./${sub}_${ses}_${ftype}_cvr.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask.nii.gz \
			 ./${sub}_${ses}_${ftype}_cvr_idx_mask.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.nii.gz \
			 ./${sub}_${ses}_${ftype}_cvr_lag.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap.nii.gz \
			 ./${sub}_${ses}_${ftype}_tmap.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_abs_mask.nii.gz \
			 ./${sub}_${ses}_${ftype}_tstat_mask.nii.gz

		for inmap in cvr cvr_idx_mask cvr_lag tmap tstat_mask
		do
			echo "Transforming ${inmap} maps of session ${ses} to MNI"
			infile=${sub}_${ses}_${ftype}_${inmap}.nii.gz
			antsApplyTransforms -d 3 -i ${infile} -r ./reg/MNI_T1_brain.nii.gz \
								-o ./normalised/std_${infile}.nii.gz -n NearestNeighbor \
								-t ./reg/${sub}_T1w2std1Warp.nii.gz \
								-t ./reg/${sub}_T1w2std0GenericAffine.mat \
								-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
								-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
		done
	done
done

cd normalised




cd ${cwd}