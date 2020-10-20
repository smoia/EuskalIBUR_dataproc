#!/usr/bin/env bash

lastses=${1:-10}
wdr=${2:-/data}
scriptdir=${2:-/scripts}
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
	cp ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz
fi
if [ ! -e ./reg/MNI_T1_brain_mask.nii.gz ]
then
	fslmaths ./reg/MNI_T1_brain.nii.gz -bin ./reg/MNI_T1_brain_mask.nii.gz
fi


# Copy & normalising
for ftype in echo-2 optcom meica-aggr meica-orth meica-cons
do
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
				if [[ ! -e ./normalised/std_${ftype}_cvr_${map}_${sub}_${ses}.nii.gz ||  ! -e ./normalised/std_${ftype}_lag_${map}_${sub}_${ses}.nii.gz ||  ! -e ./normalised/std_${ftype}_tmap_${map}_${sub}_${ses}.nii.gz ]]
				then
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
				fi
			done
		done
	done
done

for map in masked_physio_only # corrected
do
for inmap in cvr lag
do
# Compute ICC
inmap=${inmap}_${map}
rm ../LMEr_${inmap}.nii.gz

 
3dLMEr -prefix ../LMEr_${inmap}.nii.gz -jobs 1                \
       -mask ../reg/MNI_T1_brain_mask.nii.gz                           \
       -model  'model+(1|session)+(1|Subj)'                            \
       -gltCode echo-2_vs_optcom  'model : 1*echo-2 -1*optcom'         \
       -gltCode echo-2_vs_meica-aggr  'model : 1*echo-2 -1*meica-aggr' \
       -gltCode echo-2_vs_meica-orth  'model : 1*echo-2 -1*meica-orth' \
       -gltCode echo-2_vs_meica-cons  'model : 1*echo-2 -1*meica-cons' \
       -gltCode optcom_vs_meica-aggr  'model : 1*optcom -1*meica-aggr' \
       -gltCode optcom_vs_meica-orth  'model : 1*optcom -1*meica-orth' \
       -gltCode optcom_vs_meica-cons  'model : 1*optcom -1*meica-cons' \
       -gltCode meica-aggr_vs_meica-orth  'model : 1*meica-aggr -1*meica-orth' \
       -gltCode meica-aggr_vs_meica-cons  'model : 1*meica-aggr -1*meica-cons' \
       -gltCode meica-orth_vs_meica-cons  'model : 1*meica-orth -1*meica-cons' \
       -glfCode all_vs_echo-2  'model : 1*echo-2 -1*optcom & 1*echo-2 -1*meica-aggr & 1*echo-2 -1*meica-orth & 1*echo-2 -1*meica-cons' \
       -dataTable                                                      \
       Subj session  model       InputFile                             \
       001  01       echo-2      std_echo-2_${inmap}_001_01.nii.gz     \
       001  02       echo-2      std_echo-2_${inmap}_001_02.nii.gz     \
       001  03       echo-2      std_echo-2_${inmap}_001_03.nii.gz     \
       001  04       echo-2      std_echo-2_${inmap}_001_04.nii.gz     \
       001  05       echo-2      std_echo-2_${inmap}_001_05.nii.gz     \
       001  06       echo-2      std_echo-2_${inmap}_001_06.nii.gz     \
       001  07       echo-2      std_echo-2_${inmap}_001_07.nii.gz     \
       001  08       echo-2      std_echo-2_${inmap}_001_08.nii.gz     \
       001  09       echo-2      std_echo-2_${inmap}_001_09.nii.gz     \
       001  10       echo-2      std_echo-2_${inmap}_001_10.nii.gz     \
       002  01       echo-2      std_echo-2_${inmap}_002_01.nii.gz     \
       002  02       echo-2      std_echo-2_${inmap}_002_02.nii.gz     \
       002  03       echo-2      std_echo-2_${inmap}_002_03.nii.gz     \
       002  04       echo-2      std_echo-2_${inmap}_002_04.nii.gz     \
       002  05       echo-2      std_echo-2_${inmap}_002_05.nii.gz     \
       002  06       echo-2      std_echo-2_${inmap}_002_06.nii.gz     \
       002  07       echo-2      std_echo-2_${inmap}_002_07.nii.gz     \
       002  08       echo-2      std_echo-2_${inmap}_002_08.nii.gz     \
       002  09       echo-2      std_echo-2_${inmap}_002_09.nii.gz     \
       002  10       echo-2      std_echo-2_${inmap}_002_10.nii.gz     \
       003  01       echo-2      std_echo-2_${inmap}_003_01.nii.gz     \
       003  02       echo-2      std_echo-2_${inmap}_003_02.nii.gz     \
       003  03       echo-2      std_echo-2_${inmap}_003_03.nii.gz     \
       003  04       echo-2      std_echo-2_${inmap}_003_04.nii.gz     \
       003  05       echo-2      std_echo-2_${inmap}_003_05.nii.gz     \
       003  06       echo-2      std_echo-2_${inmap}_003_06.nii.gz     \
       003  07       echo-2      std_echo-2_${inmap}_003_07.nii.gz     \
       003  08       echo-2      std_echo-2_${inmap}_003_08.nii.gz     \
       003  09       echo-2      std_echo-2_${inmap}_003_09.nii.gz     \
       003  10       echo-2      std_echo-2_${inmap}_003_10.nii.gz     \
       004  01       echo-2      std_echo-2_${inmap}_004_01.nii.gz     \
       004  02       echo-2      std_echo-2_${inmap}_004_02.nii.gz     \
       004  03       echo-2      std_echo-2_${inmap}_004_03.nii.gz     \
       004  04       echo-2      std_echo-2_${inmap}_004_04.nii.gz     \
       004  05       echo-2      std_echo-2_${inmap}_004_05.nii.gz     \
       004  06       echo-2      std_echo-2_${inmap}_004_06.nii.gz     \
       004  07       echo-2      std_echo-2_${inmap}_004_07.nii.gz     \
       004  08       echo-2      std_echo-2_${inmap}_004_08.nii.gz     \
       004  09       echo-2      std_echo-2_${inmap}_004_09.nii.gz     \
       004  10       echo-2      std_echo-2_${inmap}_004_10.nii.gz     \
       007  01       echo-2      std_echo-2_${inmap}_007_01.nii.gz     \
       007  02       echo-2      std_echo-2_${inmap}_007_02.nii.gz     \
       007  03       echo-2      std_echo-2_${inmap}_007_03.nii.gz     \
       007  04       echo-2      std_echo-2_${inmap}_007_04.nii.gz     \
       007  05       echo-2      std_echo-2_${inmap}_007_05.nii.gz     \
       007  06       echo-2      std_echo-2_${inmap}_007_06.nii.gz     \
       007  07       echo-2      std_echo-2_${inmap}_007_07.nii.gz     \
       007  08       echo-2      std_echo-2_${inmap}_007_08.nii.gz     \
       007  09       echo-2      std_echo-2_${inmap}_007_09.nii.gz     \
       007  10       echo-2      std_echo-2_${inmap}_007_10.nii.gz     \
       008  01       echo-2      std_echo-2_${inmap}_008_01.nii.gz     \
       008  02       echo-2      std_echo-2_${inmap}_008_02.nii.gz     \
       008  03       echo-2      std_echo-2_${inmap}_008_03.nii.gz     \
       008  04       echo-2      std_echo-2_${inmap}_008_04.nii.gz     \
       008  05       echo-2      std_echo-2_${inmap}_008_05.nii.gz     \
       008  06       echo-2      std_echo-2_${inmap}_008_06.nii.gz     \
       008  07       echo-2      std_echo-2_${inmap}_008_07.nii.gz     \
       008  08       echo-2      std_echo-2_${inmap}_008_08.nii.gz     \
       008  09       echo-2      std_echo-2_${inmap}_008_09.nii.gz     \
       008  10       echo-2      std_echo-2_${inmap}_008_10.nii.gz     \
       009  01       echo-2      std_echo-2_${inmap}_009_01.nii.gz     \
       009  02       echo-2      std_echo-2_${inmap}_009_02.nii.gz     \
       009  03       echo-2      std_echo-2_${inmap}_009_03.nii.gz     \
       009  04       echo-2      std_echo-2_${inmap}_009_04.nii.gz     \
       009  05       echo-2      std_echo-2_${inmap}_009_05.nii.gz     \
       009  06       echo-2      std_echo-2_${inmap}_009_06.nii.gz     \
       009  07       echo-2      std_echo-2_${inmap}_009_07.nii.gz     \
       009  08       echo-2      std_echo-2_${inmap}_009_08.nii.gz     \
       009  09       echo-2      std_echo-2_${inmap}_009_09.nii.gz     \
       009  10       echo-2      std_echo-2_${inmap}_009_10.nii.gz     \
       001  01       optcom      std_optcom_${inmap}_001_01.nii.gz     \
       001  02       optcom      std_optcom_${inmap}_001_02.nii.gz     \
       001  03       optcom      std_optcom_${inmap}_001_03.nii.gz     \
       001  04       optcom      std_optcom_${inmap}_001_04.nii.gz     \
       001  05       optcom      std_optcom_${inmap}_001_05.nii.gz     \
       001  06       optcom      std_optcom_${inmap}_001_06.nii.gz     \
       001  07       optcom      std_optcom_${inmap}_001_07.nii.gz     \
       001  08       optcom      std_optcom_${inmap}_001_08.nii.gz     \
       001  09       optcom      std_optcom_${inmap}_001_09.nii.gz     \
       001  10       optcom      std_optcom_${inmap}_001_10.nii.gz     \
       002  01       optcom      std_optcom_${inmap}_002_01.nii.gz     \
       002  02       optcom      std_optcom_${inmap}_002_02.nii.gz     \
       002  03       optcom      std_optcom_${inmap}_002_03.nii.gz     \
       002  04       optcom      std_optcom_${inmap}_002_04.nii.gz     \
       002  05       optcom      std_optcom_${inmap}_002_05.nii.gz     \
       002  06       optcom      std_optcom_${inmap}_002_06.nii.gz     \
       002  07       optcom      std_optcom_${inmap}_002_07.nii.gz     \
       002  08       optcom      std_optcom_${inmap}_002_08.nii.gz     \
       002  09       optcom      std_optcom_${inmap}_002_09.nii.gz     \
       002  10       optcom      std_optcom_${inmap}_002_10.nii.gz     \
       003  01       optcom      std_optcom_${inmap}_003_01.nii.gz     \
       003  02       optcom      std_optcom_${inmap}_003_02.nii.gz     \
       003  03       optcom      std_optcom_${inmap}_003_03.nii.gz     \
       003  04       optcom      std_optcom_${inmap}_003_04.nii.gz     \
       003  05       optcom      std_optcom_${inmap}_003_05.nii.gz     \
       003  06       optcom      std_optcom_${inmap}_003_06.nii.gz     \
       003  07       optcom      std_optcom_${inmap}_003_07.nii.gz     \
       003  08       optcom      std_optcom_${inmap}_003_08.nii.gz     \
       003  09       optcom      std_optcom_${inmap}_003_09.nii.gz     \
       003  10       optcom      std_optcom_${inmap}_003_10.nii.gz     \
       004  01       optcom      std_optcom_${inmap}_004_01.nii.gz     \
       004  02       optcom      std_optcom_${inmap}_004_02.nii.gz     \
       004  03       optcom      std_optcom_${inmap}_004_03.nii.gz     \
       004  04       optcom      std_optcom_${inmap}_004_04.nii.gz     \
       004  05       optcom      std_optcom_${inmap}_004_05.nii.gz     \
       004  06       optcom      std_optcom_${inmap}_004_06.nii.gz     \
       004  07       optcom      std_optcom_${inmap}_004_07.nii.gz     \
       004  08       optcom      std_optcom_${inmap}_004_08.nii.gz     \
       004  09       optcom      std_optcom_${inmap}_004_09.nii.gz     \
       004  10       optcom      std_optcom_${inmap}_004_10.nii.gz     \
       007  01       optcom      std_optcom_${inmap}_007_01.nii.gz     \
       007  02       optcom      std_optcom_${inmap}_007_02.nii.gz     \
       007  03       optcom      std_optcom_${inmap}_007_03.nii.gz     \
       007  04       optcom      std_optcom_${inmap}_007_04.nii.gz     \
       007  05       optcom      std_optcom_${inmap}_007_05.nii.gz     \
       007  06       optcom      std_optcom_${inmap}_007_06.nii.gz     \
       007  07       optcom      std_optcom_${inmap}_007_07.nii.gz     \
       007  08       optcom      std_optcom_${inmap}_007_08.nii.gz     \
       007  09       optcom      std_optcom_${inmap}_007_09.nii.gz     \
       007  10       optcom      std_optcom_${inmap}_007_10.nii.gz     \
       008  01       optcom      std_optcom_${inmap}_008_01.nii.gz     \
       008  02       optcom      std_optcom_${inmap}_008_02.nii.gz     \
       008  03       optcom      std_optcom_${inmap}_008_03.nii.gz     \
       008  04       optcom      std_optcom_${inmap}_008_04.nii.gz     \
       008  05       optcom      std_optcom_${inmap}_008_05.nii.gz     \
       008  06       optcom      std_optcom_${inmap}_008_06.nii.gz     \
       008  07       optcom      std_optcom_${inmap}_008_07.nii.gz     \
       008  08       optcom      std_optcom_${inmap}_008_08.nii.gz     \
       008  09       optcom      std_optcom_${inmap}_008_09.nii.gz     \
       008  10       optcom      std_optcom_${inmap}_008_10.nii.gz     \
       009  01       optcom      std_optcom_${inmap}_009_01.nii.gz     \
       009  02       optcom      std_optcom_${inmap}_009_02.nii.gz     \
       009  03       optcom      std_optcom_${inmap}_009_03.nii.gz     \
       009  04       optcom      std_optcom_${inmap}_009_04.nii.gz     \
       009  05       optcom      std_optcom_${inmap}_009_05.nii.gz     \
       009  06       optcom      std_optcom_${inmap}_009_06.nii.gz     \
       009  07       optcom      std_optcom_${inmap}_009_07.nii.gz     \
       009  08       optcom      std_optcom_${inmap}_009_08.nii.gz     \
       009  09       optcom      std_optcom_${inmap}_009_09.nii.gz     \
       009  10       optcom      std_optcom_${inmap}_009_10.nii.gz     \
       001  01       meica-aggr  std_meica-aggr_${inmap}_001_01.nii.gz \
       001  02       meica-aggr  std_meica-aggr_${inmap}_001_02.nii.gz \
       001  03       meica-aggr  std_meica-aggr_${inmap}_001_03.nii.gz \
       001  04       meica-aggr  std_meica-aggr_${inmap}_001_04.nii.gz \
       001  05       meica-aggr  std_meica-aggr_${inmap}_001_05.nii.gz \
       001  06       meica-aggr  std_meica-aggr_${inmap}_001_06.nii.gz \
       001  07       meica-aggr  std_meica-aggr_${inmap}_001_07.nii.gz \
       001  08       meica-aggr  std_meica-aggr_${inmap}_001_08.nii.gz \
       001  09       meica-aggr  std_meica-aggr_${inmap}_001_09.nii.gz \
       001  10       meica-aggr  std_meica-aggr_${inmap}_001_10.nii.gz \
       002  01       meica-aggr  std_meica-aggr_${inmap}_002_01.nii.gz \
       002  02       meica-aggr  std_meica-aggr_${inmap}_002_02.nii.gz \
       002  03       meica-aggr  std_meica-aggr_${inmap}_002_03.nii.gz \
       002  04       meica-aggr  std_meica-aggr_${inmap}_002_04.nii.gz \
       002  05       meica-aggr  std_meica-aggr_${inmap}_002_05.nii.gz \
       002  06       meica-aggr  std_meica-aggr_${inmap}_002_06.nii.gz \
       002  07       meica-aggr  std_meica-aggr_${inmap}_002_07.nii.gz \
       002  08       meica-aggr  std_meica-aggr_${inmap}_002_08.nii.gz \
       002  09       meica-aggr  std_meica-aggr_${inmap}_002_09.nii.gz \
       002  10       meica-aggr  std_meica-aggr_${inmap}_002_10.nii.gz \
       003  01       meica-aggr  std_meica-aggr_${inmap}_003_01.nii.gz \
       003  02       meica-aggr  std_meica-aggr_${inmap}_003_02.nii.gz \
       003  03       meica-aggr  std_meica-aggr_${inmap}_003_03.nii.gz \
       003  04       meica-aggr  std_meica-aggr_${inmap}_003_04.nii.gz \
       003  05       meica-aggr  std_meica-aggr_${inmap}_003_05.nii.gz \
       003  06       meica-aggr  std_meica-aggr_${inmap}_003_06.nii.gz \
       003  07       meica-aggr  std_meica-aggr_${inmap}_003_07.nii.gz \
       003  08       meica-aggr  std_meica-aggr_${inmap}_003_08.nii.gz \
       003  09       meica-aggr  std_meica-aggr_${inmap}_003_09.nii.gz \
       003  10       meica-aggr  std_meica-aggr_${inmap}_003_10.nii.gz \
       004  01       meica-aggr  std_meica-aggr_${inmap}_004_01.nii.gz \
       004  02       meica-aggr  std_meica-aggr_${inmap}_004_02.nii.gz \
       004  03       meica-aggr  std_meica-aggr_${inmap}_004_03.nii.gz \
       004  04       meica-aggr  std_meica-aggr_${inmap}_004_04.nii.gz \
       004  05       meica-aggr  std_meica-aggr_${inmap}_004_05.nii.gz \
       004  06       meica-aggr  std_meica-aggr_${inmap}_004_06.nii.gz \
       004  07       meica-aggr  std_meica-aggr_${inmap}_004_07.nii.gz \
       004  08       meica-aggr  std_meica-aggr_${inmap}_004_08.nii.gz \
       004  09       meica-aggr  std_meica-aggr_${inmap}_004_09.nii.gz \
       004  10       meica-aggr  std_meica-aggr_${inmap}_004_10.nii.gz \
       007  01       meica-aggr  std_meica-aggr_${inmap}_007_01.nii.gz \
       007  02       meica-aggr  std_meica-aggr_${inmap}_007_02.nii.gz \
       007  03       meica-aggr  std_meica-aggr_${inmap}_007_03.nii.gz \
       007  04       meica-aggr  std_meica-aggr_${inmap}_007_04.nii.gz \
       007  05       meica-aggr  std_meica-aggr_${inmap}_007_05.nii.gz \
       007  06       meica-aggr  std_meica-aggr_${inmap}_007_06.nii.gz \
       007  07       meica-aggr  std_meica-aggr_${inmap}_007_07.nii.gz \
       007  08       meica-aggr  std_meica-aggr_${inmap}_007_08.nii.gz \
       007  09       meica-aggr  std_meica-aggr_${inmap}_007_09.nii.gz \
       007  10       meica-aggr  std_meica-aggr_${inmap}_007_10.nii.gz \
       008  01       meica-aggr  std_meica-aggr_${inmap}_008_01.nii.gz \
       008  02       meica-aggr  std_meica-aggr_${inmap}_008_02.nii.gz \
       008  03       meica-aggr  std_meica-aggr_${inmap}_008_03.nii.gz \
       008  04       meica-aggr  std_meica-aggr_${inmap}_008_04.nii.gz \
       008  05       meica-aggr  std_meica-aggr_${inmap}_008_05.nii.gz \
       008  06       meica-aggr  std_meica-aggr_${inmap}_008_06.nii.gz \
       008  07       meica-aggr  std_meica-aggr_${inmap}_008_07.nii.gz \
       008  08       meica-aggr  std_meica-aggr_${inmap}_008_08.nii.gz \
       008  09       meica-aggr  std_meica-aggr_${inmap}_008_09.nii.gz \
       008  10       meica-aggr  std_meica-aggr_${inmap}_008_10.nii.gz \
       009  01       meica-aggr  std_meica-aggr_${inmap}_009_01.nii.gz \
       009  02       meica-aggr  std_meica-aggr_${inmap}_009_02.nii.gz \
       009  03       meica-aggr  std_meica-aggr_${inmap}_009_03.nii.gz \
       009  04       meica-aggr  std_meica-aggr_${inmap}_009_04.nii.gz \
       009  05       meica-aggr  std_meica-aggr_${inmap}_009_05.nii.gz \
       009  06       meica-aggr  std_meica-aggr_${inmap}_009_06.nii.gz \
       009  07       meica-aggr  std_meica-aggr_${inmap}_009_07.nii.gz \
       009  08       meica-aggr  std_meica-aggr_${inmap}_009_08.nii.gz \
       009  09       meica-aggr  std_meica-aggr_${inmap}_009_09.nii.gz \
       009  10       meica-aggr  std_meica-aggr_${inmap}_009_10.nii.gz \
       001  01       meica-orth  std_meica-orth_${inmap}_001_01.nii.gz \
       001  02       meica-orth  std_meica-orth_${inmap}_001_02.nii.gz \
       001  03       meica-orth  std_meica-orth_${inmap}_001_03.nii.gz \
       001  04       meica-orth  std_meica-orth_${inmap}_001_04.nii.gz \
       001  05       meica-orth  std_meica-orth_${inmap}_001_05.nii.gz \
       001  06       meica-orth  std_meica-orth_${inmap}_001_06.nii.gz \
       001  07       meica-orth  std_meica-orth_${inmap}_001_07.nii.gz \
       001  08       meica-orth  std_meica-orth_${inmap}_001_08.nii.gz \
       001  09       meica-orth  std_meica-orth_${inmap}_001_09.nii.gz \
       001  10       meica-orth  std_meica-orth_${inmap}_001_10.nii.gz \
       002  01       meica-orth  std_meica-orth_${inmap}_002_01.nii.gz \
       002  02       meica-orth  std_meica-orth_${inmap}_002_02.nii.gz \
       002  03       meica-orth  std_meica-orth_${inmap}_002_03.nii.gz \
       002  04       meica-orth  std_meica-orth_${inmap}_002_04.nii.gz \
       002  05       meica-orth  std_meica-orth_${inmap}_002_05.nii.gz \
       002  06       meica-orth  std_meica-orth_${inmap}_002_06.nii.gz \
       002  07       meica-orth  std_meica-orth_${inmap}_002_07.nii.gz \
       002  08       meica-orth  std_meica-orth_${inmap}_002_08.nii.gz \
       002  09       meica-orth  std_meica-orth_${inmap}_002_09.nii.gz \
       002  10       meica-orth  std_meica-orth_${inmap}_002_10.nii.gz \
       003  01       meica-orth  std_meica-orth_${inmap}_003_01.nii.gz \
       003  02       meica-orth  std_meica-orth_${inmap}_003_02.nii.gz \
       003  03       meica-orth  std_meica-orth_${inmap}_003_03.nii.gz \
       003  04       meica-orth  std_meica-orth_${inmap}_003_04.nii.gz \
       003  05       meica-orth  std_meica-orth_${inmap}_003_05.nii.gz \
       003  06       meica-orth  std_meica-orth_${inmap}_003_06.nii.gz \
       003  07       meica-orth  std_meica-orth_${inmap}_003_07.nii.gz \
       003  08       meica-orth  std_meica-orth_${inmap}_003_08.nii.gz \
       003  09       meica-orth  std_meica-orth_${inmap}_003_09.nii.gz \
       003  10       meica-orth  std_meica-orth_${inmap}_003_10.nii.gz \
       004  01       meica-orth  std_meica-orth_${inmap}_004_01.nii.gz \
       004  02       meica-orth  std_meica-orth_${inmap}_004_02.nii.gz \
       004  03       meica-orth  std_meica-orth_${inmap}_004_03.nii.gz \
       004  04       meica-orth  std_meica-orth_${inmap}_004_04.nii.gz \
       004  05       meica-orth  std_meica-orth_${inmap}_004_05.nii.gz \
       004  06       meica-orth  std_meica-orth_${inmap}_004_06.nii.gz \
       004  07       meica-orth  std_meica-orth_${inmap}_004_07.nii.gz \
       004  08       meica-orth  std_meica-orth_${inmap}_004_08.nii.gz \
       004  09       meica-orth  std_meica-orth_${inmap}_004_09.nii.gz \
       004  10       meica-orth  std_meica-orth_${inmap}_004_10.nii.gz \
       007  01       meica-orth  std_meica-orth_${inmap}_007_01.nii.gz \
       007  02       meica-orth  std_meica-orth_${inmap}_007_02.nii.gz \
       007  03       meica-orth  std_meica-orth_${inmap}_007_03.nii.gz \
       007  04       meica-orth  std_meica-orth_${inmap}_007_04.nii.gz \
       007  05       meica-orth  std_meica-orth_${inmap}_007_05.nii.gz \
       007  06       meica-orth  std_meica-orth_${inmap}_007_06.nii.gz \
       007  07       meica-orth  std_meica-orth_${inmap}_007_07.nii.gz \
       007  08       meica-orth  std_meica-orth_${inmap}_007_08.nii.gz \
       007  09       meica-orth  std_meica-orth_${inmap}_007_09.nii.gz \
       007  10       meica-orth  std_meica-orth_${inmap}_007_10.nii.gz \
       008  01       meica-orth  std_meica-orth_${inmap}_008_01.nii.gz \
       008  02       meica-orth  std_meica-orth_${inmap}_008_02.nii.gz \
       008  03       meica-orth  std_meica-orth_${inmap}_008_03.nii.gz \
       008  04       meica-orth  std_meica-orth_${inmap}_008_04.nii.gz \
       008  05       meica-orth  std_meica-orth_${inmap}_008_05.nii.gz \
       008  06       meica-orth  std_meica-orth_${inmap}_008_06.nii.gz \
       008  07       meica-orth  std_meica-orth_${inmap}_008_07.nii.gz \
       008  08       meica-orth  std_meica-orth_${inmap}_008_08.nii.gz \
       008  09       meica-orth  std_meica-orth_${inmap}_008_09.nii.gz \
       008  10       meica-orth  std_meica-orth_${inmap}_008_10.nii.gz \
       009  01       meica-orth  std_meica-orth_${inmap}_009_01.nii.gz \
       009  02       meica-orth  std_meica-orth_${inmap}_009_02.nii.gz \
       009  03       meica-orth  std_meica-orth_${inmap}_009_03.nii.gz \
       009  04       meica-orth  std_meica-orth_${inmap}_009_04.nii.gz \
       009  05       meica-orth  std_meica-orth_${inmap}_009_05.nii.gz \
       009  06       meica-orth  std_meica-orth_${inmap}_009_06.nii.gz \
       009  07       meica-orth  std_meica-orth_${inmap}_009_07.nii.gz \
       009  08       meica-orth  std_meica-orth_${inmap}_009_08.nii.gz \
       009  09       meica-orth  std_meica-orth_${inmap}_009_09.nii.gz \
       009  10       meica-orth  std_meica-orth_${inmap}_009_10.nii.gz \
       001  01       meica-cons  std_meica-cons_${inmap}_001_01.nii.gz \
       001  02       meica-cons  std_meica-cons_${inmap}_001_02.nii.gz \
       001  03       meica-cons  std_meica-cons_${inmap}_001_03.nii.gz \
       001  04       meica-cons  std_meica-cons_${inmap}_001_04.nii.gz \
       001  05       meica-cons  std_meica-cons_${inmap}_001_05.nii.gz \
       001  06       meica-cons  std_meica-cons_${inmap}_001_06.nii.gz \
       001  07       meica-cons  std_meica-cons_${inmap}_001_07.nii.gz \
       001  08       meica-cons  std_meica-cons_${inmap}_001_08.nii.gz \
       001  09       meica-cons  std_meica-cons_${inmap}_001_09.nii.gz \
       001  10       meica-cons  std_meica-cons_${inmap}_001_10.nii.gz \
       002  01       meica-cons  std_meica-cons_${inmap}_002_01.nii.gz \
       002  02       meica-cons  std_meica-cons_${inmap}_002_02.nii.gz \
       002  03       meica-cons  std_meica-cons_${inmap}_002_03.nii.gz \
       002  04       meica-cons  std_meica-cons_${inmap}_002_04.nii.gz \
       002  05       meica-cons  std_meica-cons_${inmap}_002_05.nii.gz \
       002  06       meica-cons  std_meica-cons_${inmap}_002_06.nii.gz \
       002  07       meica-cons  std_meica-cons_${inmap}_002_07.nii.gz \
       002  08       meica-cons  std_meica-cons_${inmap}_002_08.nii.gz \
       002  09       meica-cons  std_meica-cons_${inmap}_002_09.nii.gz \
       002  10       meica-cons  std_meica-cons_${inmap}_002_10.nii.gz \
       003  01       meica-cons  std_meica-cons_${inmap}_003_01.nii.gz \
       003  02       meica-cons  std_meica-cons_${inmap}_003_02.nii.gz \
       003  03       meica-cons  std_meica-cons_${inmap}_003_03.nii.gz \
       003  04       meica-cons  std_meica-cons_${inmap}_003_04.nii.gz \
       003  05       meica-cons  std_meica-cons_${inmap}_003_05.nii.gz \
       003  06       meica-cons  std_meica-cons_${inmap}_003_06.nii.gz \
       003  07       meica-cons  std_meica-cons_${inmap}_003_07.nii.gz \
       003  08       meica-cons  std_meica-cons_${inmap}_003_08.nii.gz \
       003  09       meica-cons  std_meica-cons_${inmap}_003_09.nii.gz \
       003  10       meica-cons  std_meica-cons_${inmap}_003_10.nii.gz \
       004  01       meica-cons  std_meica-cons_${inmap}_004_01.nii.gz \
       004  02       meica-cons  std_meica-cons_${inmap}_004_02.nii.gz \
       004  03       meica-cons  std_meica-cons_${inmap}_004_03.nii.gz \
       004  04       meica-cons  std_meica-cons_${inmap}_004_04.nii.gz \
       004  05       meica-cons  std_meica-cons_${inmap}_004_05.nii.gz \
       004  06       meica-cons  std_meica-cons_${inmap}_004_06.nii.gz \
       004  07       meica-cons  std_meica-cons_${inmap}_004_07.nii.gz \
       004  08       meica-cons  std_meica-cons_${inmap}_004_08.nii.gz \
       004  09       meica-cons  std_meica-cons_${inmap}_004_09.nii.gz \
       004  10       meica-cons  std_meica-cons_${inmap}_004_10.nii.gz \
       007  01       meica-cons  std_meica-cons_${inmap}_007_01.nii.gz \
       007  02       meica-cons  std_meica-cons_${inmap}_007_02.nii.gz \
       007  03       meica-cons  std_meica-cons_${inmap}_007_03.nii.gz \
       007  04       meica-cons  std_meica-cons_${inmap}_007_04.nii.gz \
       007  05       meica-cons  std_meica-cons_${inmap}_007_05.nii.gz \
       007  06       meica-cons  std_meica-cons_${inmap}_007_06.nii.gz \
       007  07       meica-cons  std_meica-cons_${inmap}_007_07.nii.gz \
       007  08       meica-cons  std_meica-cons_${inmap}_007_08.nii.gz \
       007  09       meica-cons  std_meica-cons_${inmap}_007_09.nii.gz \
       007  10       meica-cons  std_meica-cons_${inmap}_007_10.nii.gz \
       008  01       meica-cons  std_meica-cons_${inmap}_008_01.nii.gz \
       008  02       meica-cons  std_meica-cons_${inmap}_008_02.nii.gz \
       008  03       meica-cons  std_meica-cons_${inmap}_008_03.nii.gz \
       008  04       meica-cons  std_meica-cons_${inmap}_008_04.nii.gz \
       008  05       meica-cons  std_meica-cons_${inmap}_008_05.nii.gz \
       008  06       meica-cons  std_meica-cons_${inmap}_008_06.nii.gz \
       008  07       meica-cons  std_meica-cons_${inmap}_008_07.nii.gz \
       008  08       meica-cons  std_meica-cons_${inmap}_008_08.nii.gz \
       008  09       meica-cons  std_meica-cons_${inmap}_008_09.nii.gz \
       008  10       meica-cons  std_meica-cons_${inmap}_008_10.nii.gz \
       009  01       meica-cons  std_meica-cons_${inmap}_009_01.nii.gz \
       009  02       meica-cons  std_meica-cons_${inmap}_009_02.nii.gz \
       009  03       meica-cons  std_meica-cons_${inmap}_009_03.nii.gz \
       009  04       meica-cons  std_meica-cons_${inmap}_009_04.nii.gz \
       009  05       meica-cons  std_meica-cons_${inmap}_009_05.nii.gz \
       009  06       meica-cons  std_meica-cons_${inmap}_009_06.nii.gz \
       009  07       meica-cons  std_meica-cons_${inmap}_009_07.nii.gz \
       009  08       meica-cons  std_meica-cons_${inmap}_009_08.nii.gz \
       009  09       meica-cons  std_meica-cons_${inmap}_009_09.nii.gz \
       009  10       meica-cons  std_meica-cons_${inmap}_009_10.nii.gz \

done
done

echo "End of script!"

cd ${cwd}