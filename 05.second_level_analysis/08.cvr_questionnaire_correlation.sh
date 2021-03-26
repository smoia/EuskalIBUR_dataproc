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

tmp=${tmp}/tmp.08cqc

replace_and mkdir ${tmp}
if_missing_do mkdir reg ${tmp}/norm

# Copy files for transformation & create mask
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz reg/MNI_T1_brain.nii.gz

if_missing_do mask reg/MNI_T1_brain.nii.gz reg/MNI_T1_brain_mask.nii.gz

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
				  reg/${sub}_T1w2std1Warp.nii.gz
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
				  reg/${sub}_T1w2std0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
				  reg/${sub}_T2w2sbref0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
				  reg/${sub}_T2w2T1w0GenericAffine.mat

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Check if normalisation is needed for session ${ses} masked"

		for inmap in cvr lag
		do
			if [ ${inmap} == "lag" ]; then origmap=cvr_lag; else origmap=${inmap}; fi
			inmap=${inmap}_masked
			if [ ! -e ${tmp}/norm/std_optcom_${inmap}_${sub}_${ses}.nii.gz ]
			then
				infile=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_${origmap}_masked.nii.gz

				echo "Transforming ${inmap##*/} maps of session ${ses} to MNI"
				antsApplyTransforms -d 3 -i ${infile} -r reg/MNI_T1_brain.nii.gz \
									-o ${tmp}/norm/std_optcom_${inmap}_${sub}_${ses}.nii.gz -n NearestNeighbor \
									-t reg/${sub}_T1w2std1Warp.nii.gz \
									-t reg/${sub}_T1w2std0GenericAffine.mat \
									-t reg/${sub}_T2w2T1w0GenericAffine.mat \
									-t [reg/${sub}_T2w2sbref0GenericAffine.mat,1]
				imrm ${sub}_${ses}_optcom_${inmap}.nii.gz
			fi
		done
	done
done

# Copy questionnaire and read it into arrays
sub=( $(csvtool -t TAB namedcol subject ${wdr}/phenotype/questionnaire.tsv ) )
ses=( $(csvtool -t TAB namedcol session ${wdr}/phenotype/questionnaire.tsv ) )
sex=( $(csvtool -t TAB namedcol sex ${wdr}/phenotype/questionnaire.tsv ) )
sleep=( $(csvtool -t TAB namedcol sleep_hours_today ${wdr}/phenotype/questionnaire.tsv ) )
exercise=( $(csvtool -t TAB namedcol exercise_hours_week_total_7days ${wdr}/phenotype/questionnaire.tsv ) )
water=( $(csvtool -t TAB namedcol water_litres_day_average_7days ${wdr}/phenotype/questionnaire.tsv ) )
coffee=( $(csvtool -t TAB namedcol coffee_units_day_average_7days ${wdr}/phenotype/questionnaire.tsv ) )
alcohol=( $(csvtool -t TAB namedcol alcohol_units_week_average_7days ${wdr}/phenotype/questionnaire.tsv ) )
systolic=( $(csvtool -t TAB namedcol systolic_tension_avg ${wdr}/phenotype/questionnaire.tsv ) )
diastolic=( $(csvtool -t TAB namedcol diastolic_tension_avg ${wdr}/phenotype/questionnaire.tsv ) )
pulse=( $(csvtool -t TAB namedcol pulse_avg ${wdr}/phenotype/questionnaire.tsv ) )

let nrep=${#sub[@]}-1
# # Compute complete model
# for inmap in cvr lag
# do
# 	# Compute ICC
# 	inmap=${inmap}_masked
# 	rm LMEr_${inmap}_allregr.nii.gz

# 	run3dLMEr="3dLMEr -prefix LMEr_${inmap}_allregr.nii.gz -jobs 10"
# 	run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
# 	run3dLMEr="${run3dLMEr} -model 'sex*(sleep+exercise+water+coffee+alcohol+systolic+diastolic+pulse)+(1|session)+(1|Subj)'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sleep:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'exercise:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'water:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'coffee:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'alcohol:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'systolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'diastolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'pulse:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F sleep:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F exercise:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F water:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F coffee:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F alcohol:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F systolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F diastolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F pulse:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M sleep:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M exercise:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M water:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M coffee:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M alcohol:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M systolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M diastolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M pulse:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F sleep:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F exercise:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F water:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F coffee:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F alcohol:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F systolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F diastolic:1'"
# 	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F pulse:1'"
# 	run3dLMEr="${run3dLMEr} -qVars 'sleep,exercise,water,coffee,alcohol,systolic,diastolic,pulse'"
# 	run3dLMEr="${run3dLMEr} -dataTable  "
# 	run3dLMEr="${run3dLMEr}       Subj session sex sleep exercise water coffee alcohol systolic diastolic pulse InputFile                        "

# 	for k in $(seq 1 ${nrep})
# 	do
# 		run3dLMEr="${run3dLMEr}       ${sub[$k]}  ${ses[$k]} ${sex[$k]} ${sleep[$k]} ${exercise[$k]} ${water[$k]} ${coffee[$k]} ${alcohol[$k]} ${systolic[$k]} ${diastolic[$k]} ${pulse[$k]} ${tmp}/norm/std_optcom_${inmap}_${sub[$k]}_${ses[$k]}.nii.gz"
# 	done
# 	echo ""
# 	echo "${run3dLMEr}"
# 	echo ""
# 	eval ${run3dLMEr}
# done

# Compute only tension model
for inmap in cvr lag
do
	# Compute ICC
	inmap=${inmap}_masked
	rm LMEr_${inmap}_onlytension.nii.gz

	run3dLMEr="3dLMEr -prefix LMEr_${inmap}_onlytension.nii.gz -jobs 10"
	run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
	run3dLMEr="${run3dLMEr} -model 'sex*(systolic+diastolic+pulse)+(1|session)+(1|Subj)'"
	run3dLMEr="${run3dLMEr} -gltCode 'systolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'diastolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F systolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F diastolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M -1*F pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M systolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M diastolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*M pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F systolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F diastolic :'"
	run3dLMEr="${run3dLMEr} -gltCode 'sex: 1*F pulse :'"
	run3dLMEr="${run3dLMEr} -qVars 'systolic,diastolic,pulse'"
	run3dLMEr="${run3dLMEr} -dataTable  "
	run3dLMEr="${run3dLMEr}       Subj session sex systolic diastolic pulse InputFile                        "

	for k in $(seq 1 ${nrep})
	do
		run3dLMEr="${run3dLMEr}       ${sub[$k]}  ${ses[$k]} ${sex[$k]} ${systolic[$k]} ${diastolic[$k]} ${pulse[$k]} ${tmp}/norm/std_optcom_${inmap}_${sub[$k]}_${ses[$k]}.nii.gz"
	done
	echo ""
	echo "${run3dLMEr}"
	echo ""
	eval ${run3dLMEr}
done

echo "End of script!"

cd ${cwd}