#!/usr/bin/env bash

ftype=${1:-optcom}
lastses=${2:-10}
wdr=${3:-/data}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d CVR_reliability ]
then
	mkdir CVR_reliability
fi

cd CVR_reliability

mkdir reg normalised cov

# Copy files for transformation & create mask
if [ ! -e ./reg/MNI_T1_brain.nii.gz ]
then
	cp /scripts/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz
fi
if [ ! -e ./reg/MNI_T1_brain_mask.nii.gz ]
then
	fslmaths ./reg/MNI_T1_brain.nii.gz -bin ./reg/MNI_T1_brain_mask.nii.gz
fi

# Copy
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	if [ ! -e ${sub}_T1w2std1Warp.nii.gz ]
	then
		imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
			 ./reg/${sub}_T1w2std1Warp.nii.gz
	fi
	if [ ! -e ./reg/${sub}_T1w2std0GenericAffine.mat ]
	then
		cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
		   ./reg/${sub}_T1w2std0GenericAffine.mat
	fi
	if [ ! -e ./reg/${sub}_T2w2sbref0GenericAffine.mat ]
	then
		cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
		   ./reg/${sub}_T2w2sbref0GenericAffine.mat
	fi
	if [ ! -e ./reg/${sub}_T2w2T1w0GenericAffine.mat ]
	then
		cp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
		   ./reg/${sub}_T2w2T1w0GenericAffine.mat
	fi

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
			# for inmap in cvr lag
			# do
			# 	inmap=${inmap}_${map}
			# 	# Compute intrasubject CoV
			# 	fslmerge -t all_${sub}_${ftype}_${inmap}.nii.gz normalised/std_${ftype}_${inmap}_${sub}_*

			# 	fslmaths all_${sub}_${ftype}_${inmap} -Tmean avg_${sub}_${ftype}_${inmap}
			# 	fslmaths all_${sub}_${ftype}_${inmap} -Tstd -div avg_${sub}_${ftype}_${inmap} cov/CoV_sub_${inmap}_${ftype}_${sub}
				
			# 	imrm all_${sub}_${ftype}_${inmap}.nii.gz
			# 	imrm avg_${sub}_${ftype}_${inmap}.nii.gz
			# done
		done
	done
done

# for map in masked # corrected
# do
# 	for inmap in cvr lag # cvr_idx_mask tstat_mask
# 	do
# 		inmap=${inmap}_${map}
# 		for ses in $( seq -f %02g 1 10 )
# 		do
# 			# Compute intersession CoV
# 			fslmerge -t all_${ses}_${ftype}_${inmap}.nii.gz normalised/std_${ftype}_${inmap}_001_${ses}.nii.gz \
# 			normalised/std_${ftype}_${inmap}_002_${ses}.nii.gz normalised/std_${ftype}_${inmap}_003_${ses}.nii.gz \
# 			normalised/std_${ftype}_${inmap}_004_${ses}.nii.gz normalised/std_${ftype}_${inmap}_007_${ses}.nii.gz \
# 			normalised/std_${ftype}_${inmap}_008_${ses}.nii.gz normalised/std_${ftype}_${inmap}_009_${ses}.nii.gz

# 			fslmaths all_${ses}_${ftype}_${inmap} -Tmean avg_${ses}_${ftype}_${inmap}
# 			fslmaths all_${ses}_${ftype}_${inmap} -Tstd -div avg_${ses}_${ftype}_${inmap} cov/CoV_ses_${inmap}_${ftype}_${ses}
# 			imrm all_${ses}_${ftype}_${inmap}.nii.gz
# 			imrm avg_${ses}_${ftype}_${inmap}.nii.gz
# 		done

# 		# Compute total CoV
# 		fslmerge -t all_total_${ftype}_${inmap}.nii.gz normalised/std_${ftype}_${inmap}_*
# 		fslmaths all_total_${ftype}_${inmap}.nii.gz -Tmean avg_total_${ftype}_${inmap}
# 		fslmaths all_total_${ftype}_${inmap} -Tstd -div avg_total_${ftype}_${inmap} CoV_total_${inmap}_${ftype}
# 		imrm all_total_${ftype}_${inmap}.nii.gz
# 		imrm avg_total_${ftype}_${inmap}.nii.gz

# 		# Compute average intersubject CoV
# 		fslmerge -t all_cov_ses_${inmap}_${ftype} cov/CoV_ses_${inmap}_${ftype}_*
# 		fslmaths all_cov_ses_${inmap}_${ftype} -Tmean CoV_intrases_${inmap}_${ftype}
# 		imrm all_cov_ses_${inmap}_${ftype}.nii.gz

# 		# Compute average intrasubject CoV
# 		fslmerge -t all_cov_subs_${inmap}_${ftype} cov/CoV_sub_${inmap}_${ftype}_*
# 		fslmaths all_cov_subs_${inmap}_${ftype} -Tmean CoV_intrasub_${inmap}_${ftype}
# 		imrm all_cov_subs_${inmap}_${ftype}.nii.gz
# 	done
# done

cd normalised

for map in masked_physio_only # corrected
do
for inmap in cvr lag
do
# Compute ICC
inmap=${inmap}_${map}
rm ../ICC2_${inmap}_${ftype}.nii.gz

3dICC -prefix ../ICC2_${inmap}_${ftype}.nii.gz -jobs 10                                    \
      -mask ../reg/MNI_T1_brain_mask.nii.gz                                                \
      -model  '1+(1|session)+(1|Subj)'                                                     \
      -tStat 'tFile'                                                                       \
      -dataTable                                                                           \
      Subj session         tFile                             InputFile                     \
      001  01       std_${ftype}_tmap_${map}_001_01.nii.gz    std_${ftype}_${inmap}_001_01.nii.gz \
      001  02       std_${ftype}_tmap_${map}_001_02.nii.gz    std_${ftype}_${inmap}_001_02.nii.gz \
      001  03       std_${ftype}_tmap_${map}_001_03.nii.gz    std_${ftype}_${inmap}_001_03.nii.gz \
      001  04       std_${ftype}_tmap_${map}_001_04.nii.gz    std_${ftype}_${inmap}_001_04.nii.gz \
      001  05       std_${ftype}_tmap_${map}_001_05.nii.gz    std_${ftype}_${inmap}_001_05.nii.gz \
      001  06       std_${ftype}_tmap_${map}_001_06.nii.gz    std_${ftype}_${inmap}_001_06.nii.gz \
      001  07       std_${ftype}_tmap_${map}_001_07.nii.gz    std_${ftype}_${inmap}_001_07.nii.gz \
      001  08       std_${ftype}_tmap_${map}_001_08.nii.gz    std_${ftype}_${inmap}_001_08.nii.gz \
      001  09       std_${ftype}_tmap_${map}_001_09.nii.gz    std_${ftype}_${inmap}_001_09.nii.gz \
      001  10       std_${ftype}_tmap_${map}_001_10.nii.gz    std_${ftype}_${inmap}_001_10.nii.gz \
      002  01       std_${ftype}_tmap_${map}_002_01.nii.gz    std_${ftype}_${inmap}_002_01.nii.gz \
      002  02       std_${ftype}_tmap_${map}_002_02.nii.gz    std_${ftype}_${inmap}_002_02.nii.gz \
      002  03       std_${ftype}_tmap_${map}_002_03.nii.gz    std_${ftype}_${inmap}_002_03.nii.gz \
      002  04       std_${ftype}_tmap_${map}_002_04.nii.gz    std_${ftype}_${inmap}_002_04.nii.gz \
      002  05       std_${ftype}_tmap_${map}_002_05.nii.gz    std_${ftype}_${inmap}_002_05.nii.gz \
      002  06       std_${ftype}_tmap_${map}_002_06.nii.gz    std_${ftype}_${inmap}_002_06.nii.gz \
      002  07       std_${ftype}_tmap_${map}_002_07.nii.gz    std_${ftype}_${inmap}_002_07.nii.gz \
      002  08       std_${ftype}_tmap_${map}_002_08.nii.gz    std_${ftype}_${inmap}_002_08.nii.gz \
      002  09       std_${ftype}_tmap_${map}_002_09.nii.gz    std_${ftype}_${inmap}_002_09.nii.gz \
      002  10       std_${ftype}_tmap_${map}_002_10.nii.gz    std_${ftype}_${inmap}_002_10.nii.gz \
      003  01       std_${ftype}_tmap_${map}_003_01.nii.gz    std_${ftype}_${inmap}_003_01.nii.gz \
      003  02       std_${ftype}_tmap_${map}_003_02.nii.gz    std_${ftype}_${inmap}_003_02.nii.gz \
      003  03       std_${ftype}_tmap_${map}_003_03.nii.gz    std_${ftype}_${inmap}_003_03.nii.gz \
      003  04       std_${ftype}_tmap_${map}_003_04.nii.gz    std_${ftype}_${inmap}_003_04.nii.gz \
      003  05       std_${ftype}_tmap_${map}_003_05.nii.gz    std_${ftype}_${inmap}_003_05.nii.gz \
      003  06       std_${ftype}_tmap_${map}_003_06.nii.gz    std_${ftype}_${inmap}_003_06.nii.gz \
      003  07       std_${ftype}_tmap_${map}_003_07.nii.gz    std_${ftype}_${inmap}_003_07.nii.gz \
      003  08       std_${ftype}_tmap_${map}_003_08.nii.gz    std_${ftype}_${inmap}_003_08.nii.gz \
      003  09       std_${ftype}_tmap_${map}_003_09.nii.gz    std_${ftype}_${inmap}_003_09.nii.gz \
      003  10       std_${ftype}_tmap_${map}_003_10.nii.gz    std_${ftype}_${inmap}_003_10.nii.gz \
      004  01       std_${ftype}_tmap_${map}_004_01.nii.gz    std_${ftype}_${inmap}_004_01.nii.gz \
      004  02       std_${ftype}_tmap_${map}_004_02.nii.gz    std_${ftype}_${inmap}_004_02.nii.gz \
      004  03       std_${ftype}_tmap_${map}_004_03.nii.gz    std_${ftype}_${inmap}_004_03.nii.gz \
      004  04       std_${ftype}_tmap_${map}_004_04.nii.gz    std_${ftype}_${inmap}_004_04.nii.gz \
      004  05       std_${ftype}_tmap_${map}_004_05.nii.gz    std_${ftype}_${inmap}_004_05.nii.gz \
      004  06       std_${ftype}_tmap_${map}_004_06.nii.gz    std_${ftype}_${inmap}_004_06.nii.gz \
      004  07       std_${ftype}_tmap_${map}_004_07.nii.gz    std_${ftype}_${inmap}_004_07.nii.gz \
      004  08       std_${ftype}_tmap_${map}_004_08.nii.gz    std_${ftype}_${inmap}_004_08.nii.gz \
      004  09       std_${ftype}_tmap_${map}_004_09.nii.gz    std_${ftype}_${inmap}_004_09.nii.gz \
      004  10       std_${ftype}_tmap_${map}_004_10.nii.gz    std_${ftype}_${inmap}_004_10.nii.gz \
      007  01       std_${ftype}_tmap_${map}_007_01.nii.gz    std_${ftype}_${inmap}_007_01.nii.gz \
      007  02       std_${ftype}_tmap_${map}_007_02.nii.gz    std_${ftype}_${inmap}_007_02.nii.gz \
      007  03       std_${ftype}_tmap_${map}_007_03.nii.gz    std_${ftype}_${inmap}_007_03.nii.gz \
      007  04       std_${ftype}_tmap_${map}_007_04.nii.gz    std_${ftype}_${inmap}_007_04.nii.gz \
      007  05       std_${ftype}_tmap_${map}_007_05.nii.gz    std_${ftype}_${inmap}_007_05.nii.gz \
      007  06       std_${ftype}_tmap_${map}_007_06.nii.gz    std_${ftype}_${inmap}_007_06.nii.gz \
      007  07       std_${ftype}_tmap_${map}_007_07.nii.gz    std_${ftype}_${inmap}_007_07.nii.gz \
      007  08       std_${ftype}_tmap_${map}_007_08.nii.gz    std_${ftype}_${inmap}_007_08.nii.gz \
      007  09       std_${ftype}_tmap_${map}_007_09.nii.gz    std_${ftype}_${inmap}_007_09.nii.gz \
      007  10       std_${ftype}_tmap_${map}_007_10.nii.gz    std_${ftype}_${inmap}_007_10.nii.gz \
      008  01       std_${ftype}_tmap_${map}_008_01.nii.gz    std_${ftype}_${inmap}_008_01.nii.gz \
      008  02       std_${ftype}_tmap_${map}_008_02.nii.gz    std_${ftype}_${inmap}_008_02.nii.gz \
      008  03       std_${ftype}_tmap_${map}_008_03.nii.gz    std_${ftype}_${inmap}_008_03.nii.gz \
      008  04       std_${ftype}_tmap_${map}_008_04.nii.gz    std_${ftype}_${inmap}_008_04.nii.gz \
      008  05       std_${ftype}_tmap_${map}_008_05.nii.gz    std_${ftype}_${inmap}_008_05.nii.gz \
      008  06       std_${ftype}_tmap_${map}_008_06.nii.gz    std_${ftype}_${inmap}_008_06.nii.gz \
      008  07       std_${ftype}_tmap_${map}_008_07.nii.gz    std_${ftype}_${inmap}_008_07.nii.gz \
      008  08       std_${ftype}_tmap_${map}_008_08.nii.gz    std_${ftype}_${inmap}_008_08.nii.gz \
      008  09       std_${ftype}_tmap_${map}_008_09.nii.gz    std_${ftype}_${inmap}_008_09.nii.gz \
      008  10       std_${ftype}_tmap_${map}_008_10.nii.gz    std_${ftype}_${inmap}_008_10.nii.gz \
      009  01       std_${ftype}_tmap_${map}_009_01.nii.gz    std_${ftype}_${inmap}_009_01.nii.gz \
      009  02       std_${ftype}_tmap_${map}_009_02.nii.gz    std_${ftype}_${inmap}_009_02.nii.gz \
      009  03       std_${ftype}_tmap_${map}_009_03.nii.gz    std_${ftype}_${inmap}_009_03.nii.gz \
      009  04       std_${ftype}_tmap_${map}_009_04.nii.gz    std_${ftype}_${inmap}_009_04.nii.gz \
      009  05       std_${ftype}_tmap_${map}_009_05.nii.gz    std_${ftype}_${inmap}_009_05.nii.gz \
      009  06       std_${ftype}_tmap_${map}_009_06.nii.gz    std_${ftype}_${inmap}_009_06.nii.gz \
      009  07       std_${ftype}_tmap_${map}_009_07.nii.gz    std_${ftype}_${inmap}_009_07.nii.gz \
      009  08       std_${ftype}_tmap_${map}_009_08.nii.gz    std_${ftype}_${inmap}_009_08.nii.gz \
      009  09       std_${ftype}_tmap_${map}_009_09.nii.gz    std_${ftype}_${inmap}_009_09.nii.gz \
      009  10       std_${ftype}_tmap_${map}_009_10.nii.gz    std_${ftype}_${inmap}_009_10.nii.gz

done
done

echo "End of script!"

cd ${cwd}