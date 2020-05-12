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

# Copy files for transformation & create mask
cp /scripts/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz
fslmaths ./reg/MNI_T1_brain.nii.gz -bin ./reg/MNI_T1_brain_mask.nii.gz

# Copy
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	# this has to be simplified
	# imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain.nii.gz \
	# 	 ./reg/${sub}_sbref_brain.nii.gz
	# imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask.nii.gz \
	# 	 ./reg/${sub}_sbref_brain_mask.nii.gz
	# imcp ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1InverseWarp.nii.gz \
	# 	 ./reg/${sub}_T1w2std1InverseWarp.nii.gz
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
		# imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_idx_mask.nii.gz \
		# 	 ./${sub}_${ses}_${ftype}_cvr_idx_mask.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.nii.gz \
			 ./${sub}_${ses}_${ftype}_lag.nii.gz
		imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap.nii.gz \
			 ./${sub}_${ses}_${ftype}_tmap.nii.gz
		# imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_abs_mask.nii.gz \
		# 	 ./${sub}_${ses}_${ftype}_tstat_mask.nii.gz

		for inmap in cvr lag tmap  # cvr_idx_mask tstat_mask
		do
			echo "Transforming ${inmap} maps of session ${ses} to MNI"
			infile=${sub}_${ses}_${ftype}_${inmap}.nii.gz
			antsApplyTransforms -d 3 -i ${infile} -r ./reg/MNI_T1_brain.nii.gz \
								-o ./normalised/std_${infile}.nii.gz -n NearestNeighbor \
								-t ./reg/${sub}_T1w2std1Warp.nii.gz \
								-t ./reg/${sub}_T1w2std0GenericAffine.mat \
								-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
								-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
			imrm ${infile}
		done
	done
done

cd normalised

for inmap in cvr lag
do

3dICC -prefix ../ICC2_${inmap}_${ftype}.nii.gz -jobs 10                                    \
      -mask ../reg/MNI_T1_brain_mask.nii.gz                                                \
      -model  '1+(1|session)+(1|Subj)'                                                     \
      -tStat 'tFile'                                                                       \
      -dataTable                                                                           \
      Subj session         tFile                             InputFile                     \
      001  01       std_001_01_${ftype}_tmap.nii.gz    std_001_01_${ftype}_${inmap}.nii.gz \
      001  02       std_001_02_${ftype}_tmap.nii.gz    std_001_02_${ftype}_${inmap}.nii.gz \
      001  03       std_001_03_${ftype}_tmap.nii.gz    std_001_03_${ftype}_${inmap}.nii.gz \
      001  04       std_001_04_${ftype}_tmap.nii.gz    std_001_04_${ftype}_${inmap}.nii.gz \
      001  05       std_001_05_${ftype}_tmap.nii.gz    std_001_05_${ftype}_${inmap}.nii.gz \
      001  06       std_001_06_${ftype}_tmap.nii.gz    std_001_06_${ftype}_${inmap}.nii.gz \
      001  07       std_001_07_${ftype}_tmap.nii.gz    std_001_07_${ftype}_${inmap}.nii.gz \
      001  08       std_001_08_${ftype}_tmap.nii.gz    std_001_08_${ftype}_${inmap}.nii.gz \
      001  09       std_001_09_${ftype}_tmap.nii.gz    std_001_09_${ftype}_${inmap}.nii.gz \
      001  10       std_001_10_${ftype}_tmap.nii.gz    std_001_10_${ftype}_${inmap}.nii.gz \
      002  01       std_002_01_${ftype}_tmap.nii.gz    std_002_01_${ftype}_${inmap}.nii.gz \
      002  02       std_002_02_${ftype}_tmap.nii.gz    std_002_02_${ftype}_${inmap}.nii.gz \
      002  03       std_002_03_${ftype}_tmap.nii.gz    std_002_03_${ftype}_${inmap}.nii.gz \
      002  04       std_002_04_${ftype}_tmap.nii.gz    std_002_04_${ftype}_${inmap}.nii.gz \
      002  05       std_002_05_${ftype}_tmap.nii.gz    std_002_05_${ftype}_${inmap}.nii.gz \
      002  06       std_002_06_${ftype}_tmap.nii.gz    std_002_06_${ftype}_${inmap}.nii.gz \
      002  07       std_002_07_${ftype}_tmap.nii.gz    std_002_07_${ftype}_${inmap}.nii.gz \
      002  08       std_002_08_${ftype}_tmap.nii.gz    std_002_08_${ftype}_${inmap}.nii.gz \
      002  09       std_002_09_${ftype}_tmap.nii.gz    std_002_09_${ftype}_${inmap}.nii.gz \
      002  10       std_002_10_${ftype}_tmap.nii.gz    std_002_10_${ftype}_${inmap}.nii.gz \
      003  01       std_003_01_${ftype}_tmap.nii.gz    std_003_01_${ftype}_${inmap}.nii.gz \
      003  02       std_003_02_${ftype}_tmap.nii.gz    std_003_02_${ftype}_${inmap}.nii.gz \
      003  03       std_003_03_${ftype}_tmap.nii.gz    std_003_03_${ftype}_${inmap}.nii.gz \
      003  04       std_003_04_${ftype}_tmap.nii.gz    std_003_04_${ftype}_${inmap}.nii.gz \
      003  05       std_003_05_${ftype}_tmap.nii.gz    std_003_05_${ftype}_${inmap}.nii.gz \
      003  06       std_003_06_${ftype}_tmap.nii.gz    std_003_06_${ftype}_${inmap}.nii.gz \
      003  07       std_003_07_${ftype}_tmap.nii.gz    std_003_07_${ftype}_${inmap}.nii.gz \
      003  08       std_003_08_${ftype}_tmap.nii.gz    std_003_08_${ftype}_${inmap}.nii.gz \
      003  09       std_003_09_${ftype}_tmap.nii.gz    std_003_09_${ftype}_${inmap}.nii.gz \
      003  10       std_003_10_${ftype}_tmap.nii.gz    std_003_10_${ftype}_${inmap}.nii.gz \
      004  01       std_004_01_${ftype}_tmap.nii.gz    std_004_01_${ftype}_${inmap}.nii.gz \
      004  02       std_004_02_${ftype}_tmap.nii.gz    std_004_02_${ftype}_${inmap}.nii.gz \
      004  03       std_004_03_${ftype}_tmap.nii.gz    std_004_03_${ftype}_${inmap}.nii.gz \
      004  04       std_004_04_${ftype}_tmap.nii.gz    std_004_04_${ftype}_${inmap}.nii.gz \
      004  05       std_004_05_${ftype}_tmap.nii.gz    std_004_05_${ftype}_${inmap}.nii.gz \
      004  06       std_004_06_${ftype}_tmap.nii.gz    std_004_06_${ftype}_${inmap}.nii.gz \
      004  07       std_004_07_${ftype}_tmap.nii.gz    std_004_07_${ftype}_${inmap}.nii.gz \
      004  08       std_004_08_${ftype}_tmap.nii.gz    std_004_08_${ftype}_${inmap}.nii.gz \
      004  09       std_004_09_${ftype}_tmap.nii.gz    std_004_09_${ftype}_${inmap}.nii.gz \
      004  10       std_004_10_${ftype}_tmap.nii.gz    std_004_10_${ftype}_${inmap}.nii.gz \
      007  01       std_007_01_${ftype}_tmap.nii.gz    std_007_01_${ftype}_${inmap}.nii.gz \
      007  02       std_007_02_${ftype}_tmap.nii.gz    std_007_02_${ftype}_${inmap}.nii.gz \
      007  03       std_007_03_${ftype}_tmap.nii.gz    std_007_03_${ftype}_${inmap}.nii.gz \
      007  04       std_007_04_${ftype}_tmap.nii.gz    std_007_04_${ftype}_${inmap}.nii.gz \
      007  05       std_007_05_${ftype}_tmap.nii.gz    std_007_05_${ftype}_${inmap}.nii.gz \
      007  06       std_007_06_${ftype}_tmap.nii.gz    std_007_06_${ftype}_${inmap}.nii.gz \
      007  07       std_007_07_${ftype}_tmap.nii.gz    std_007_07_${ftype}_${inmap}.nii.gz \
      007  08       std_007_08_${ftype}_tmap.nii.gz    std_007_08_${ftype}_${inmap}.nii.gz \
      007  09       std_007_09_${ftype}_tmap.nii.gz    std_007_09_${ftype}_${inmap}.nii.gz \
      007  10       std_007_10_${ftype}_tmap.nii.gz    std_007_10_${ftype}_${inmap}.nii.gz \
      008  01       std_008_01_${ftype}_tmap.nii.gz    std_008_01_${ftype}_${inmap}.nii.gz \
      008  02       std_008_02_${ftype}_tmap.nii.gz    std_008_02_${ftype}_${inmap}.nii.gz \
      008  03       std_008_03_${ftype}_tmap.nii.gz    std_008_03_${ftype}_${inmap}.nii.gz \
      008  04       std_008_04_${ftype}_tmap.nii.gz    std_008_04_${ftype}_${inmap}.nii.gz \
      008  05       std_008_05_${ftype}_tmap.nii.gz    std_008_05_${ftype}_${inmap}.nii.gz \
      008  06       std_008_06_${ftype}_tmap.nii.gz    std_008_06_${ftype}_${inmap}.nii.gz \
      008  07       std_008_07_${ftype}_tmap.nii.gz    std_008_07_${ftype}_${inmap}.nii.gz \
      008  08       std_008_08_${ftype}_tmap.nii.gz    std_008_08_${ftype}_${inmap}.nii.gz \
      008  09       std_008_09_${ftype}_tmap.nii.gz    std_008_09_${ftype}_${inmap}.nii.gz \
      008  10       std_008_10_${ftype}_tmap.nii.gz    std_008_10_${ftype}_${inmap}.nii.gz \
      009  01       std_009_01_${ftype}_tmap.nii.gz    std_009_01_${ftype}_${inmap}.nii.gz \
      009  02       std_009_02_${ftype}_tmap.nii.gz    std_009_02_${ftype}_${inmap}.nii.gz \
      009  03       std_009_03_${ftype}_tmap.nii.gz    std_009_03_${ftype}_${inmap}.nii.gz \
      009  04       std_009_04_${ftype}_tmap.nii.gz    std_009_04_${ftype}_${inmap}.nii.gz \
      009  05       std_009_05_${ftype}_tmap.nii.gz    std_009_05_${ftype}_${inmap}.nii.gz \
      009  06       std_009_06_${ftype}_tmap.nii.gz    std_009_06_${ftype}_${inmap}.nii.gz \
      009  07       std_009_07_${ftype}_tmap.nii.gz    std_009_07_${ftype}_${inmap}.nii.gz \
      009  08       std_009_08_${ftype}_tmap.nii.gz    std_009_08_${ftype}_${inmap}.nii.gz \
      009  09       std_009_09_${ftype}_tmap.nii.gz    std_009_09_${ftype}_${inmap}.nii.gz \
      009  10       std_009_10_${ftype}_tmap.nii.gz    std_009_10_${ftype}_${inmap}.nii.gz

done

cd ${cwd}