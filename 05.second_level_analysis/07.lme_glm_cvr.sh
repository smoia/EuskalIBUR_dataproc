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

task=$2
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication || exit

tmp=${tmp}/tmp.${task}_07lgc
replace_and mkdir ${tmp}

if_missing_do mkdir lme norm reg
if_missing_do copy ${sdr}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz reg/MNI_T1_brain.nii.gz

# Prepare to break GLM bricks
for sub in 001 002 003 004 007 008 009
do
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

	for ses in $( seq -f %02g 1 10; echo "allses" )
	do
		# Consider only contrasts of interest
		rbuck=GLM/${task}/output/${sub}_${ses}_task-${task}_spm.nii.gz
		case ${task} in
			motor )
				# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
				3dbucket -prefix ${tmp}/${sub}_${ses}_allmotors.nii.gz -abuc ${rbuck}'[13]' -overwrite
				3dbucket -prefix ${tmp}/${sub}_${ses}_motors_vs_sham.nii.gz -abuc ${rbuck}'[15]' -overwrite
				bricks=$( allmotors motors_vs_sham )
			;;
			simon )
				# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
				3dbucket -prefix ${tmp}/${sub}_${ses}_all_congruent.nii.gz -abuc ${rbuck}'[17]' -overwrite
				3dbucket -prefix ${tmp}/${sub}_${ses}_all_incongruent.nii.gz -abuc ${rbuck}'[19]' -overwrite
				3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_vs_incongruent.nii.gz -abuc ${rbuck}'[21]' -overwrite
				3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_and_incongruent.nii.gz -abuc ${rbuck}'[23]' -overwrite
				bricks=$( all_congruent all_incongruent congruent_vs_incongruent congruent_and_incongruent )
			;;
			* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
		esac

		# Copy CVR maps
		if_missing_do copy CVR/${sub}_${ses}_cvr.nii.gz ${tmp}/${sub}_${ses}_cvr.nii.gz

		rsfc=()
		# Copy RSFA & FALFF maps
		for run in $( seq -f %02g 1 4 )
		do
			if_missing_do copy fALFF/sub-${sub}_ses-${ses}_task-rest_run-${run}_fALFF.nii.gz ${tmp}/${sub}_${ses}_r${run}_fALFF.nii.gz
			if_missing_do copy RSFA/sub-${sub}_ses-${ses}_task-rest_run-${run}_RSFA.nii.gz ${tmp}/${sub}_${ses}_r${run}_RSFA.nii.gz
			rsfc+=(r${run}_fALFF r${run}_RSFA)
		done

		for map in $( echo "cvr"; echo "${rsfc[@]}"; echo "${bricks[@]}" )
		do
			if [ ! -e ./norm/${sub}_${ses}_${map}.nii.gz ]
			then
				antsApplyTransforms -d 3 -i ${tmp}/${sub}_${ses}_${map}.nii.gz -r ./reg/MNI_T1_brain.nii.gz \
									-o ./norm/${sub}_${ses}_${map}.nii.gz -n NearestNeighbor \
									-t ./reg/${sub}_T1w2std1Warp.nii.gz \
									-t ./reg/${sub}_T1w2std0GenericAffine.mat \
									-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
									-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
			fi
		done
	done
done

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
if_missing_do copy ${mask}.nii.gz ${tmp}/${sub}_${ses}_mask.nii.gz

for brick in "${bricks[@]}"
do
	if_missing_do mkdir lme/${brick}
	# Compute 3dLME
	for map in fALFF RSFA
	do
		for run in $( seq -f %02g 1 4 )
		do
			outfile=lme/${brick}/mod_${brick}_${map}_r-${run}_CVR.nii.gz
			rm ${outfile}

			run3dLMEr="3dLMEr -prefix ${outfile} -jobs 10"
			run3dLMEr="${run3dLMEr} -mask ${tmp}/${sub}_${ses}_mask.nii.gz"
			run3dLMEr="${run3dLMEr} -model  '${brick}~${map}*cvr+(1|session)+(1|Subj)'"
			run3dLMEr="${run3dLMEr} -dataTable"
			run3dLMEr="${run3dLMEr}     Subj session  model       InputFile"

			listbrick=""
			listmap=""
			listcvr=""
			for sub in 001 002 003 004 007 008 009
			do
				for ses in $( seq -f %02g 1 10; echo "allses" )
				do
					listbrick="${listbrick}     ${sub}  ${ses}       ${brick}      norm/${sub}_${ses}_${brick}.nii.gz"
					listmap="${listmap}     ${sub}  ${ses}       ${map}      norm/${sub}_${ses}_r${run}_${map}.nii.gz"
					listcvr="${listcvr}     ${sub}  ${ses}       cvr      norm/${sub}_${ses}_cvr.nii.gz"
				done
			done
			run3dLMEr="${run3dLMEr} ${listbrick} ${listmap} ${listcvr}"
			echo ""
			echo "${run3dLMEr}"
			echo ""
			eval ${run3dLMEr}
		done
	done
done

rm -rf ${tmp}

cd ${cwd}