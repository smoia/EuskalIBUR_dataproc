#!/usr/bin/env bash

if_missing_do() {
if [ $1 == 'mkdir' ]
then
       if [ ! -d $2 ]
       then
              mkdir "${@:2}"
       fi
elif [ ! -e $3 ]
then
       printf "%s is missing, " "$3"
       case $1 in
              copy ) echo "copying $2"; cp $2 $3 ;;
              mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
              * ) echo "and you shouldn't see this"; exit ;;
       esac
fi
}

ftype=${1:-optcom}
lastses=${2:-10}
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if_missing_do mkdir CVR_reliability

cd CVR_reliability

if_missing_do mkdir reg normalised cov

# Copy files for transformation & create mask
if_missing_do copy /scripts/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz
if_missing_do mask ./reg/MNI_T1_brain.nii.gz -bin ./reg/MNI_T1_brain_mask.nii.gz

# Copy
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
				  ./reg/${sub}_T1w2std1Warp.nii.gz
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
				  ./reg/${sub}_T1w2std0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
				  ./reg/${sub}_T2w2sbref0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
				  ./reg/${sub}_T2w2T1w0GenericAffine.mat

	for map in masked_physio_only # corrected
	do
		for ses in $( seq -f %02g 1 ${lastses} )
		do
			echo "Copying session ${ses} ${map}"
			imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_${map}.nii.gz \
				 ./${sub}_${ses}_${ftype}_cvr_${map}.nii.gz
			imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_${map}.nii.gz \
				 ./${sub}_${ses}_${ftype}_lag_${map}.nii.gz
			imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_${map}.nii.gz \
				 ./${sub}_${ses}_${ftype}_tmap_${map}.nii.gz

			for inmap in cvr lag tmap  # cvr_idx_mask tstat_mask
			do
				inmap=${inmap}_${map}
				echo "Transforming ${inmap} maps of session ${ses} to MNI"
				antsApplyTransforms -d 3 -i ${sub}_${ses}_${ftype}_${inmap}.nii.gz -r ./reg/MNI_T1_brain.nii.gz \
									-o ./normalised/std_${ftype}_${inmap}_${sub}_${ses}.nii.gz -n NearestNeighbor \
									-t ./reg/${sub}_T1w2std1Warp.nii.gz \
									-t ./reg/${sub}_T1w2std0GenericAffine.mat \
									-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
									-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
				imrm ${sub}_${ses}_${ftype}_${inmap}.nii.gz
			done
		done
	done
done

cd normalised

for map in masked_physio_only # corrected
do
	for inmap in cvr lag
	do
		# Compute ICC
		inmap=${inmap}_${map}
		rm ../ICC2_${inmap}_${ftype}.nii.gz

		run3dICC="3dICC -prefix ../ICC2_${inmap}_${ftype}.nii.gz -jobs 10"
		run3dICC="${run3dICC} -mask ../reg/MNI_T1_brain_mask.nii.gz"
		run3dICC="${run3dICC} -model  '1+(1|session)+(1|Subj)'"
		run3dICC="${run3dICC} -tStat 'tFile'"
		run3dICC="${run3dICC} -dataTable"
		run3dICC="${run3dICC}      Subj session    tFile                           InputFile            "
		for sub in 001 002 003 004 007 008 009
		do
			for ses in $( seq -f %02g 1 ${lastses} )
			do
				run3dICC="${run3dICC}      ${sub}  ${ses}  std_${ftype}_tmap_${map}_${sub}_${ses}.nii.gz  std_${ftype}_${inmap}_${sub}_${ses}.nii.gz"
			done
		done
		echo ""
		echo "${run3dICC}"
		echo ""
		eval ${run3dICC}
	done
done

echo "End of script!"

cd ${cwd}