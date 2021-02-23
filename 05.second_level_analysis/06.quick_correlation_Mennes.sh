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
		* ) "and you shouldn't see this"; exit ;;
	esac
fi
}

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

sub=$1
task=$2
wdr=${3:-/data}
tmp=${4:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/GLM/${task}/output || exit

tmp=${tmp}/tmp.${sub}_${task}_06qcm
replace_and mkdir ${tmp}

if [[ ! -d "${wdr}/CVR" ]]; then echo "Missing CVR computations"; exit; fi
if_missing_do mkdir CVR
if_missing_do mkdir corr parcorr
if_missing_do mkdir ${tmp}/CVR

# Prepare to break GLM bricks
for ses in $( seq -f %02g 1 10; echo "allses" )
do
	# Consider only contrasts of interest
	rbuck=GLM/${task}/output/${sub}_${ses}_task-${task}_spm.nii.gz
	case ${task} in
		motor )
			# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
			3dbucket -prefix ${tmp}/${sub}_allmotors_${ses}.nii.gz -abuc ${rbuck}'[13]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_motors_vs_sham_${ses}.nii.gz -abuc ${rbuck}'[15]' -overwrite
			bricks=$( allmotors motors_vs_sham )
		;;
		simon )
			# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
			3dbucket -prefix ${tmp}/${sub}_all_congruent_${ses}.nii.gz -abuc ${rbuck}'[17]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_all_incongruent_${ses}.nii.gz -abuc ${rbuck}'[19]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_congruent_vs_incongruent_${ses}.nii.gz -abuc ${rbuck}'[21]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_congruent_and_incongruent_${ses}.nii.gz -abuc ${rbuck}'[23]' -overwrite
			bricks=$( all_congruent all_incongruent congruent_vs_incongruent congruent_and_incongruent )
		;;
		* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
	esac

	# Copy CVR maps
	cvrmap=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr.nii.gz
	if_missing_do copy ${cvrmap} CVR/${sub}_${ses}_cvr.nii.gz
	if_missing_do copy CVR/${sub}_${ses}_cvr.nii.gz ${tmp}/CVR/${sub}_${ses}.nii.gz

	# Copy RSFA & FALFF maps
	for run in $( seq -f %02g 1 4 )
	do
		if_missing_do copy fALFF/sub-${sub}_ses-${ses}_task-rest_run-${run}_fALFF.nii.gz ${tmp}/fALFF_${sub}_r${run}_${ses}.nii.gz
		if_missing_do copy RSFA/sub-${sub}_ses-${ses}_task-rest_run-${run}_RSFA.nii.gz ${tmp}/RSFA_${sub}_r${run}_${ses}.nii.gz
	done
done

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
if_missing_do copy ${mask}.nii.gz ${tmp}/${sub}_${ses}_mask.nii.gz
# Merge CVR
fslmerge -t ${tmp}/${sub}_cvr ${tmp}/CVR/${sub}*
# Merge RSFA
for run in $( seq -f %02g 1 4 )
do
	fslmerge -t ${tmp}/${sub}_r${run}_fALFF ${tmp}/fALFF_${sub}_r${run}*
	fslmerge -t ${tmp}/${sub}_r${run}_RSFA ${tmp}/RSFA_${sub}_r${run}*
done

for brick in "${bricks[@]}"
do
	# Merge bricks
	fslmerge -t ${tmp}/${sub}_${brick} ${tmp}/${sub}_${brick}_*
	
	3dTcorrelate -pearson -polort -1 -prefix corr/${sub}_${task}_${brick}_cvr.nii.gz \
				 ${tmp}/${sub}_${brick}.nii.gz ${tmp}/${sub}_cvr.nii.gz -overwrite

	# Compute correlations
	for map in fALFF RSFA
	do
		for run in $( seq -f %02g 1 4 )
		do
			3dTcorrelate -pearson -polort -1 -prefix corr/${sub}_${task}_${brick}_${map}_r${run}.nii.gz \
						 ${tmp}/${sub}_${brick}.nii.gz ${tmp}/${sub}_r${run}_${map}.nii.gz -overwrite

			3dTcorrelate -pearson -polort -1 -partial ${tmp}/${sub}_cvr.nii.gz\
						 -prefix parcorr/${sub}_${task}_${brick}_${map}_r${run}.nii.gz \
						 ${tmp}/${sub}_${brick}.nii.gz ${tmp}/${sub}_r${run}_${map}.nii.gz -overwrite
		done
	done
done

rm -rf ${tmp}

cd ${cwd}