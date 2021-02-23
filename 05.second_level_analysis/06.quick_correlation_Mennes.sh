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
	case ${task} in
		motor )
			# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
			3dbucket -prefix ${tmp}/${sub}_allmotors_${ses}.nii.gz -abuc ${rbuck}'[13]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_allmotors_vs_sham_${ses}.nii.gz -abuc ${rbuck}'[15]' -overwrite
			fslmerge 
		;;
		simon )
			# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
			3dbucket -prefix ${tmp}/${sub}_all_congruent_${ses}.nii.gz -abuc ${rbuck}'[17]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_all_incongruent_${ses}.nii.gz -abuc ${rbuck}'[19]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_congruent_vs_incongruent_${ses}.nii.gz -abuc ${rbuck}'[21]' -overwrite
			3dbucket -prefix ${tmp}/${sub}_congruent_and_incongruent_${ses}.nii.gz -abuc ${rbuck}'[23]' -overwrite
		;;
		* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
	esac
done

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
if_missing_do copy ${mask}.nii.gz ${tmp}/${sub}_${ses}_mask.nii.gz
for ses in $(seq -f %02g 1 10)
do
	# Copy CVR maps
	cvrmap=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr.nii.gz
	if_missing_do copy ${cvrmap} CVR/${sub}_${ses}_cvr.nii.gz
	if_missing_do copy CVR/${sub}_${ses}_cvr.nii.gz ${tmp}/CVR/${sub}_${ses}.nii.gz

	# Copy RSFA & FALFF maps
	if_missing_do copy fALFF/sub-${sub}_ses-${ses}_task-rest_run-01_fALFF.nii.gz ${tmp}/fALFF_${sub}_${ses}.nii.gz
	if_missing_do copy RSFA/sub-${sub}_ses-${ses}_task-rest_run-01_RSFA.nii.gz ${tmp}/RSFA_${sub}_${ses}.nii.gz

	rbuck=GLM/${task}/output/${sub}_${ses}_task-${task}_spm.nii.gz
	for brick in $(seq 0 ${lastbrick})
	do
		# Break bricks
		brickname=$( 3dinfo -verb ${rbuck} | grep 'brick #${brick} ' | awk -F "'" '{ print $2 }' )
		3dbucket -prefix ${tmp}/${brickname}_${sub}_${ses}.nii.gz -abuc ${rbuck}'[${brick}]' -overwrite
	done
done
# Merge CVR
fslmerge -t ${tmp}/${sub}_cvr ${tmp}/${task}/CVR/${sub}*
# Merge RSFA
fslmerge -t ${tmp}/${task}/${sub}_fALFF ${tmp}/${task}/fALFF_${sub}*
fslmerge -t ${tmp}/${task}/${sub}_RSFA ${tmp}/${task}/RSFA_${sub}*
for brick in $(seq 0 ${lastbrick})
do
	# Merge bricks
	brickname=$( 3dinfo -verb ${rbuck} | grep 'brick #${brick} ' | awk -F "'" '{ print $2 }' )
	fslmerge -t ${tmp}/${task}/${sub}_${brickname} ${tmp}/${task}/${brickname}_${sub}*
	# Compute correlations
	for map in cvr fALFF RSFA
	do
		3dTcorrelate -pearson -polort -1 -prefix corr/${sub}_${map}_${task}_${brickname}.nii.gz \
					 ${tmp}/${task}/${sub}_${brickname}.nii.gz ${tmp}/${task}/${sub}_${map}.nii.gz -overwrite
		if [ ${map} != "cvr" ]
		then
			3dTcorrelate -pearson -polort -1 -partial ${tmp}/${task}/${sub}_cvr.nii.gz\
						 -prefix parcorr/${sub}_${map}_${task}_${brickname}.nii.gz \
						 ${tmp}/${task}/${sub}_${brickname}.nii.gz ${tmp}/${task}/${sub}_${map}.nii.gz -overwrite
		fi
	done
done

rm -rf ${tmp}/${task}

cd ${cwd}