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

extract_and_average() {
k=1
for n in $(seq ${1} 2 ${2})
do
	3dbucket -prefix ${3}_${k}.nii.gz -abuc ${4}[${n}] -overwrite
	let k++
done
fslmerge -t ${3} ${3}_?.nii.gz
fslmaths ${3} -Tmean ${3}
}


task=$1
wdr=${2:-/data}
sdr=${3:-/scripts}
tmp=${4:-.}

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
if_missing_do mask reg/MNI_T1_brain.nii.gz reg/MNI_T1_brain_mask.nii.gz

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

	for ses in $( seq -f %02g 1 10 ) #; echo "allses" )
	do
		# Consider only contrasts of interest
		rbuck=GLM/${task}/${sub}/${sub}_${ses}_task-${task}_spm.nii.gz
		case ${task} in
			motor )
				# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
				if [ ! -e ./norm/${sub}_${ses}_allmotors.nii.gz ]
				then
					# extract_and_average 34 42 ${tmp}/${sub}_${ses}_allmotors ${rbuck}
					# 3dbucket -prefix ${tmp}/${sub}_${ses}_finger_left.nii.gz ${rbuck} -abuc ${rbuck}'[1]' -overwrite
					# 3dbucket -prefix ${tmp}/${sub}_${ses}_finger_right.nii.gz ${rbuck} -abuc ${rbuck}'[4]' -overwrite
					# 3dbucket -prefix ${tmp}/${sub}_${ses}_toe_left.nii.gz ${rbuck} -abuc ${rbuck}'[7]' -overwrite
					# 3dbucket -prefix ${tmp}/${sub}_${ses}_toe_right.nii.gz ${rbuck} -abuc ${rbuck}'[10]' -overwrite
					# 3dbucket -prefix ${tmp}/${sub}_${ses}_tongue.nii.gz ${rbuck} -abuc ${rbuck}'[13]' -overwrite
					# extract_and_average 45 53 ${tmp}/${sub}_${ses}_motors_vs_sham ${rbuck}
					3dbucket -prefix ${tmp}/${sub}_${ses}_finger_left_vs_sham.nii.gz ${rbuck} -abuc ${rbuck}'[19]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_finger_right_vs_sham.nii.gz ${rbuck} -abuc ${rbuck}'[22]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_toe_left_vs_sham.nii.gz ${rbuck} -abuc ${rbuck}'[25]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_toe_right_vs_sham.nii.gz ${rbuck} -abuc ${rbuck}'[28]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_tongue_vs_sham.nii.gz ${rbuck} -abuc ${rbuck}'[31]' -overwrite
				fi
				bricks=( finger_left_vs_sham finger_right_vs_sham toe_left_vs_sham toe_right_vs_sham tongue_vs_sham ) #allmotors motors_vs_sham finger_left finger_right toe_left toe_right tongue finger_left_vs_sham finger_right_vs_sham toe_left_vs_sham toe_right_vs_sham tongue_vs_sham )
			;;
			simon )
				# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
				if [ ! -e ./norm/${sub}_${ses}_all_congruent.nii.gz ]
				then
					3dbucket -prefix ${tmp}/${sub}_${ses}_all_congruent.nii.gz -abuc ${rbuck}'[25]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_vs_incongruent.nii.gz -abuc ${rbuck}'[31]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_and_incongruent.nii.gz -abuc ${rbuck}'[34]' -overwrite
				fi
				bricks=( all_congruent congruent_vs_incongruent congruent_and_incongruent )
			;;
			falff ) echo "Skip task" ;;
			* ) echo " !!! Warning !!! Invalid task: ${task}"; exit ;;
		esac

		# Copy CVR maps, clip it, mask outliers, and slightly smooth
		if_missing_do copy CVR/${sub}_${ses}_cvr.nii.gz ${tmp}/${sub}_${ses}_cvr.nii.gz
		fslmaths ${tmp}/${sub}_${ses}_cvr.nii.gz -min 3 -max -3 ${tmp}/${sub}_${ses}_cvr.nii.gz
		fslmaths ${tmp}/${sub}_${ses}_cvr.nii.gz -abs -bin ${tmp}/${sub}_${ses}_cvr_mask.nii.gz
		fslmaths ${tmp}/${sub}_${ses}_cvr.nii.gz -mas ${tmp}/${sub}_${ses}_cvr_mask.nii.gz ${tmp}/${sub}_${ses}_cvr.nii.gz

		3dBlurInMask -input ${tmp}/${sub}_${ses}_cvr.nii.gz -mask ${tmp}/${sub}_${ses}_cvr_mask.nii.gz \
					 -prefix ${tmp}/${sub}_${ses}_cvr.nii.gz -FWHM 5 -overwrite

		rsfc=()
		# Copy RSFA & FALFF & ALFF maps
		for run in $( seq -f %02g 1 4 )
		do
			if [ ! -e ./norm/${sub}_${ses}_r${run}_fALFF.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_r${run}_RSFA.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_r${run}_ALFF.nii.gz ]
			then
				if_missing_do copy fALFF/sub-${sub}_ses-${ses}_task-rest_run-${run}_fALFF.nii.gz ${tmp}/${sub}_${ses}_r${run}_fALFF.nii.gz
				if_missing_do copy ALFF/sub-${sub}_ses-${ses}_task-rest_run-${run}_ALFF.nii.gz ${tmp}/${sub}_${ses}_r${run}_ALFF.nii.gz
				if_missing_do copy RSFA/sub-${sub}_ses-${ses}_task-rest_run-${run}_RSFA.nii.gz ${tmp}/${sub}_${ses}_r${run}_RSFA.nii.gz
			fi
			rsfc+=(r${run}_fALFF r${run}_ALFF r${run}_RSFA)
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

for map in $( echo "cvr"; echo "${rsfc[@]}"; echo "${bricks[@]}" )
do
	for sub in 001 002 003 004 007 008 009
	do
		if [ ! -e ./norm/${sub}_10_${map}_demean.nii.gz ]
		then
			echo "Preparing to demean ${map} in sub ${sub}"
			fslmerge -t ${tmp}/${map}_${sub} norm/${sub}_??_${map}.nii.gz
			fslmaths ${tmp}/${map}_${sub} -Tmean ${tmp}/${map}_${sub}_mean
			for ses in $( seq -f %02g 1 10 )
			do
				fslmaths norm/${sub}_${ses}_${map} -sub ${tmp}/${map}_${sub}_mean norm/${sub}_${ses}_${map}_demean
			done
		fi
	done
done

for brick in "${bricks[@]}"
do
	if_missing_do mkdir lme/${brick}
	# Compute 3dLME for CVR and GLM
	outfile=lme/${brick}/cause_${brick}_CVR.nii.gz
	rm ${outfile}

	run3dLMEr="3dLMEr -prefix ${outfile} -jobs 10"
	run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
	run3dLMEr="${run3dLMEr} -model 'cvr+(cvr|session)+(cvr|Subj)'"
	run3dLMEr="${run3dLMEr} -gltCode cvr 'cvr :'"
	run3dLMEr="${run3dLMEr} -vVars 'cvr'"
	run3dLMEr="${run3dLMEr} -vVarCenters 0"
	run3dLMEr="${run3dLMEr} -dataTable"
	run3dLMEr="${run3dLMEr}	 Subj session  cvr    InputFile"
	for sub in 001 002 003 004 007 008 009
	do
		for ses in $( seq -f %02g 1 10 )
		do
			run3dLMEr="${run3dLMEr}	 ${sub}  ${ses}  norm/${sub}_${ses}_cvr_demean.nii.gz  norm/${sub}_${ses}_${brick}_demean.nii.gz"
		done
	done
	echo ""
	echo "${run3dLMEr}"
	echo ""
	eval ${run3dLMEr}
done

for brick in "${bricks[@]}"
do
	if_missing_do mkdir lme/${brick}
	# Compute 3dLME
	for map in fALFF RSFA ALFF
	do
		for run in 01 #$( seq -f %02g 1 4 )
		do
			outfile=lme/${brick}/cause_${brick}_${map}_r-${run}.nii.gz
			rm ${outfile}

			run3dLMEr="3dLMEr -prefix ${outfile} -jobs 10"
			run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
			run3dLMEr="${run3dLMEr} -model '${map}+(${map}|session)+(${map}|Subj)'"
			run3dLMEr="${run3dLMEr} -gltCode ${map} '${map} :'"
			run3dLMEr="${run3dLMEr} -vVars '${map}'"
			run3dLMEr="${run3dLMEr} -vVarCenters 0"
			run3dLMEr="${run3dLMEr} -dataTable"
			run3dLMEr="${run3dLMEr}	 Subj session  ${map}     InputFile"
			for sub in 001 002 003 004 007 008 009
			do
				for ses in $( seq -f %02g 1 10 )
				do
					run3dLMEr="${run3dLMEr}	 ${sub}  ${ses}  norm/${sub}_${ses}_r${run}_${map}_demean.nii.gz  norm/${sub}_${ses}_${brick}_demean.nii.gz"
				done
			done
			echo ""
			echo "${run3dLMEr}"
			echo ""
			eval ${run3dLMEr}
		done
	done
done

if [ "${task}" == "falff" ]
then
	if_missing_do mkdir lme/RSF
	# Compute 3dLME
	for map in fALFF RSFA ALFF
	do
		for run in 01 #$( seq -f %02g 1 4 )
		do
			outfile=lme/RSF/cause_${map}_r-${run}_CVR.nii.gz
			rm ${outfile}

			run3dLMEr="3dLMEr -prefix ${outfile} -jobs 10"
			run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
			run3dLMEr="${run3dLMEr} -model 'cvr+(cvr|session)+(cvr|Subj)'"
			run3dLMEr="${run3dLMEr} -gltCode cvr 'cvr :'"
			run3dLMEr="${run3dLMEr} -vVars 'cvr'"
			run3dLMEr="${run3dLMEr} -vVarCenters 0"
			run3dLMEr="${run3dLMEr} -dataTable"
			run3dLMEr="${run3dLMEr}	 Subj session  cvr    InputFile"
			for sub in 001 002 003 004 007 008 009
			do
				for ses in $( seq -f %02g 1 10 )
				do
					run3dLMEr="${run3dLMEr}	 ${sub}  ${ses}  norm/${sub}_${ses}_cvr_demean.nii.gz  norm/${sub}_${ses}_r${run}_${map}_demean.nii.gz"
				done
			done
			echo ""
			echo "${run3dLMEr}"
			echo ""
			eval ${run3dLMEr}
		done
	done
fi

rm -rf ${tmp}

cd ${cwd}