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

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

lastses=${1:-10}
wdr=${2:-/data}
scriptdir=${2:-/scripts}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if_missing_do mkdir CVR_correlation

cd CVR_correlation

tmp=${tmp}/tmp.${task}_08cqc

replace_and mkdir ${tmp}
if_missing_do mkdir ${tmp}/reg ${tmp}/normalised ${tmp}/cov

# Copy files for transformation & create mask
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ${tmp}/reg/MNI_T1_brain.nii.gz

if_missing_do mask ${tmp}/reg/MNI_T1_brain.nii.gz ${tmp}/reg/MNI_T1_brain_mask.nii.gz

# Copy & normalising
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
				  ${tmp}/reg/${sub}_T1w2std1Warp.nii.gz
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
				  ${tmp}/reg/${sub}_T1w2std0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
				  ${tmp}/reg/${sub}_T2w2sbref0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
				  ${tmp}/reg/${sub}_T2w2T1w0GenericAffine.mat

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Check if normalisation is needed for session ${ses} masked"

		for inmap in cvr lag
		do
			if [ ${inmap} == "lag" ]; then origmap=cvr_lag; else origmap=${inmap}; fi
			inmap=${inmap}_masked
			if [ ! -e ./normalised/std_optcom_${inmap}_${sub}_${ses}.nii.gz ]
			then
				imcp ${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_${origmap}_masked.nii.gz \
					 ./${sub}_${ses}_optcom_${inmap}.nii.gz

				echo "Transforming ${inmap} maps of session ${ses} to MNI"
				antsApplyTransforms -d 3 -i ./${sub}_${ses}_optcom_${inmap}.nii.gz -r ${tmp}/reg/MNI_T1_brain.nii.gz \
									-o ./normalised/std_optcom_${inmap}_${sub}_${ses}.nii.gz -n NearestNeighbor \
									-t ${tmp}/reg/${sub}_T1w2std1Warp.nii.gz \
									-t ${tmp}/reg/${sub}_T1w2std0GenericAffine.mat \
									-t ${tmp}/reg/${sub}_T2w2T1w0GenericAffine.mat \
									-t [${tmp}/reg/${sub}_T2w2sbref0GenericAffine.mat,1]
				imrm ${sub}_${ses}_optcom_${inmap}.nii.gz
			fi
		done
	done
done

cd normalised

for inmap in cvr lag
do
	# Compute ICC
	inmap=${inmap}_masked
	rm ../LMEr_${inmap}.nii.gz

	run3dLMEr="3dLMEr -prefix ../LMEr_${inmap}.nii.gz -jobs 10"
	run3dLMEr="${run3dLMEr} -mask ${tmp}/reg/MNI_T1_brain_mask.nii.gz"
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

echo "End of script!"

cd ${cwd}