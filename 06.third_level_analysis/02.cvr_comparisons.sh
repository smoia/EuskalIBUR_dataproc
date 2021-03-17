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

lastses=${1:-10}
wdr=${2:-/data}
scriptdir=${2:-/scripts}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit


echo "Creating folders"
if_missing_do mkdir CVR_reliability

cd CVR_reliability

if_missing_do mkdir reg normalised cov

# Copy files for transformation & create mask
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz

if_missing_do mask ./reg/MNI_T1_brain.nii.gz ./reg/MNI_T1_brain_mask.nii.gz

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
		if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
					  ./reg/${sub}_T1w2std1Warp.nii.gz
		if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
					  ./reg/${sub}_T1w2std0GenericAffine.mat
		if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
					  ./reg/${sub}_T2w2sbref0GenericAffine.mat
		if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
					  ./reg/${sub}_T2w2T1w0GenericAffine.mat

		for map in masked  # _physio_only # corrected
		do
			for ses in $( seq -f %02g 1 ${lastses} )
			do
				echo "Check if normalisation is needed for session ${ses} ${map}"

				for inmap in cvr lag tmap
				do
					if [ ${inmap} == "lag" ]; then origmap=cvr_lag; else origmap=${inmap}; fi
					inmap=${inmap}_${map}
					if [ ! -e ./normalised/std_${ftype}_${inmap}_${sub}_${ses}.nii.gz ]
					then
						imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_${origmap}_${map}.nii.gz \
							 ./${sub}_${ses}_${ftype}_${inmap}.nii.gz

						echo "Transforming ${inmap} maps of session ${ses} to MNI"
						antsApplyTransforms -d 3 -i ./${sub}_${ses}_${ftype}_${inmap}.nii.gz -r ./reg/MNI_T1_brain.nii.gz \
											-o ./normalised/std_${ftype}_${inmap}_${sub}_${ses}.nii.gz -n NearestNeighbor \
											-t ./reg/${sub}_T1w2std1Warp.nii.gz \
											-t ./reg/${sub}_T1w2std0GenericAffine.mat \
											-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
											-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
						imrm ${sub}_${ses}_${ftype}_${inmap}.nii.gz
					fi
				done
			done
		done
	done
done

cd normalised

for map in masked  # _physio_only # corrected
do
	for inmap in cvr lag
	do
		# Compute ICC
		inmap=${inmap}_${map}
		rm ../LMEr_${inmap}.nii.gz

		run3dLMEr="3dLMEr -prefix ../LMEr_${inmap}.nii.gz -jobs 10"
		run3dLMEr="${run3dLMEr} -mask ../reg/MNI_T1_brain_mask.nii.gz"
		run3dLMEr="${run3dLMEr} -model  'model+(1|session)+(1|Subj)'"
		run3dLMEr="${run3dLMEr} -gltCode echo-2_vs_optcom  'model : 1*echo-2 -1*optcom'"
		run3dLMEr="${run3dLMEr} -gltCode echo-2_vs_meica-cons  'model : 1*echo-2 -1*meica-cons'"
		run3dLMEr="${run3dLMEr} -gltCode echo-2_vs_meica-orth  'model : 1*echo-2 -1*meica-orth'"
		run3dLMEr="${run3dLMEr} -gltCode echo-2_vs_meica-aggr  'model : 1*echo-2 -1*meica-aggr'"
		run3dLMEr="${run3dLMEr} -gltCode optcom_vs_meica-cons  'model : 1*optcom -1*meica-cons'"
		run3dLMEr="${run3dLMEr} -gltCode optcom_vs_meica-orth  'model : 1*optcom -1*meica-orth'"
		run3dLMEr="${run3dLMEr} -gltCode optcom_vs_meica-aggr  'model : 1*optcom -1*meica-aggr'"
		run3dLMEr="${run3dLMEr} -gltCode meica-cons_vs_meica-orth  'model : 1*meica-cons -1*meica-orth'"
		run3dLMEr="${run3dLMEr} -gltCode meica-cons_vs_meica-aggr  'model : 1*meica-cons -1*meica-aggr'"
		run3dLMEr="${run3dLMEr} -gltCode meica-orth_vs_meica-aggr  'model : 1*meica-orth -1*meica-aggr'"
		run3dLMEr="${run3dLMEr} -glfCode all_vs_echo-2  'model : 1*echo-2 -1*optcom & 1*echo-2 -1*meica-aggr & 1*echo-2 -1*meica-orth & 1*echo-2 -1*meica-cons'"
		run3dLMEr="${run3dLMEr} -dataTable                                                     "
		run3dLMEr="${run3dLMEr}       Subj session  model       InputFile                        "
		for sub in 001 002 003 004 007 008 009
		do
			for ses in $( seq -f %02g 1 10)
			do
				for model in echo-2 optcom meica-cons meica-orth meica-aggr
				do
					run3dLMEr="${run3dLMEr}       ${sub}  ${ses}       ${model}      std_${model}_${inmap}_${sub}_${ses}.nii.gz"
				done
			done
		done
		echo ""
		echo "${run3dLMEr}"
		echo ""
		eval ${run3dLMEr}
	done
done

echo "End of script!"

cd ${cwd}