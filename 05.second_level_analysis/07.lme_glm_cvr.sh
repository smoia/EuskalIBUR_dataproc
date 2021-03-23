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
	wait) if [ -d $2 ]; then rm -rf $2; fi;;
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
				if [ ! -e ./norm/${sub}_${ses}_allmotors.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_motors_vs_sham.nii.gz ]
				then
					# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
					extract_and_average 34 42 ${tmp}/${sub}_${ses}_allmotors ${rbuck}
					extract_and_average 45 53 ${tmp}/${sub}_${ses}_motors_vs_sham ${rbuck}
				fi
				bricks=( allmotors motors_vs_sham )
			;;
			simon )
				if [ ! -e ./norm/${sub}_${ses}_all_congruent.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_congruent_vs_incongruent.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_congruent_and_incongruent.nii.gz ]
				then
					# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
					3dbucket -prefix ${tmp}/${sub}_${ses}_all_congruent.nii.gz -abuc ${rbuck}'[25]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_vs_incongruent.nii.gz -abuc ${rbuck}'[31]' -overwrite
					3dbucket -prefix ${tmp}/${sub}_${ses}_congruent_and_incongruent.nii.gz -abuc ${rbuck}'[34]' -overwrite
				fi
				bricks=( all_congruent congruent_vs_incongruent congruent_and_incongruent )
			;;
			* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
		esac

		# Copy CVR maps
		if [ ! -e ./norm/${sub}_${ses}_cvr.nii.gz ]
		then
			if_missing_do copy CVR/${sub}_${ses}_cvr.nii.gz ${tmp}/${sub}_${ses}_cvr.nii.gz
		fi

		rsfc=()
		# Copy RSFA & FALFF maps
		for run in $( seq -f %02g 1 4 )
		do
			if [ ! -e ./norm/${sub}_${ses}_r${run}_fALFF.nii.gz ] || [ ! -e ./norm/${sub}_${ses}_r${run}_RSFA.nii.gz ]
			then
				if_missing_do copy fALFF/sub-${sub}_ses-${ses}_task-rest_run-${run}_fALFF.nii.gz ${tmp}/${sub}_${ses}_r${run}_fALFF.nii.gz
				if_missing_do copy RSFA/sub-${sub}_ses-${ses}_task-rest_run-${run}_RSFA.nii.gz ${tmp}/${sub}_${ses}_r${run}_RSFA.nii.gz
			fi
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

if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_fALFF_r-01_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_fALFF_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r01_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r01_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r01_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r01_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r01_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r01_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r01_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r01_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r01_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r01_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r01_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r01_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r01_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r01_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r01_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r01_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r01_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r01_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r01_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r01_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r01_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r01_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r01_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r01_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r01_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r01_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r01_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r01_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r01_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r01_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r01_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r01_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r01_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r01_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r01_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r01_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r01_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r01_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r01_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r01_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r01_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r01_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r01_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r01_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r01_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r01_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r01_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r01_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r01_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r01_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r01_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r01_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r01_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r01_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r01_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r01_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r01_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r01_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r01_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r01_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r01_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r01_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r01_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r01_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r01_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r01_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r01_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r01_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r01_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r01_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz

if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_RSFA_r-01_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_RSFA_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r01_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r01_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r01_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r01_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r01_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r01_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r01_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r01_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r01_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r01_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r01_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r01_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r01_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r01_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r01_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r01_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r01_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r01_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r01_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r01_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r01_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r01_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r01_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r01_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r01_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r01_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r01_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r01_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r01_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r01_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r01_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r01_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r01_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r01_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r01_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r01_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r01_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r01_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r01_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r01_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r01_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r01_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r01_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r01_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r01_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r01_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r01_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r01_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r01_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r01_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r01_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r01_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r01_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r01_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r01_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r01_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r01_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r01_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r01_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r01_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r01_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r01_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r01_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r01_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r01_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r01_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r01_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r01_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r01_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r01_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz


if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_fALFF_r-02_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_fALFF_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r02_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r02_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r02_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r02_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r02_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r02_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r02_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r02_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r02_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r02_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r02_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r02_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r02_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r02_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r02_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r02_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r02_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r02_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r02_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r02_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r02_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r02_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r02_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r02_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r02_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r02_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r02_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r02_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r02_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r02_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r02_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r02_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r02_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r02_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r02_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r02_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r02_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r02_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r02_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r02_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r02_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r02_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r02_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r02_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r02_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r02_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r02_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r02_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r02_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r02_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r02_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r02_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r02_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r02_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r02_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r02_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r02_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r02_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r02_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r02_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r02_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r02_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r02_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r02_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r02_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r02_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r02_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r02_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r02_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r02_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz

if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_RSFA_r-02_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_RSFA_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r02_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r02_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r02_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r02_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r02_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r02_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r02_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r02_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r02_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r02_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r02_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r02_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r02_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r02_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r02_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r02_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r02_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r02_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r02_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r02_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r02_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r02_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r02_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r02_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r02_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r02_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r02_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r02_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r02_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r02_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r02_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r02_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r02_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r02_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r02_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r02_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r02_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r02_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r02_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r02_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r02_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r02_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r02_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r02_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r02_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r02_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r02_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r02_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r02_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r02_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r02_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r02_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r02_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r02_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r02_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r02_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r02_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r02_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r02_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r02_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r02_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r02_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r02_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r02_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r02_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r02_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r02_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r02_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r02_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r02_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz


if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_fALFF_r-03_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_fALFF_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r03_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r03_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r03_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r03_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r03_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r03_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r03_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r03_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r03_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r03_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r03_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r03_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r03_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r03_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r03_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r03_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r03_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r03_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r03_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r03_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r03_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r03_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r03_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r03_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r03_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r03_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r03_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r03_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r03_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r03_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r03_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r03_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r03_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r03_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r03_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r03_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r03_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r03_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r03_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r03_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r03_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r03_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r03_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r03_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r03_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r03_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r03_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r03_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r03_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r03_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r03_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r03_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r03_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r03_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r03_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r03_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r03_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r03_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r03_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r03_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r03_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r03_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r03_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r03_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r03_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r03_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r03_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r03_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r03_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r03_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz

if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_RSFA_r-03_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_RSFA_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r03_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r03_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r03_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r03_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r03_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r03_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r03_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r03_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r03_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r03_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r03_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r03_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r03_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r03_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r03_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r03_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r03_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r03_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r03_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r03_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r03_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r03_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r03_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r03_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r03_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r03_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r03_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r03_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r03_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r03_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r03_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r03_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r03_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r03_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r03_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r03_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r03_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r03_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r03_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r03_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r03_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r03_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r03_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r03_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r03_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r03_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r03_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r03_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r03_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r03_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r03_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r03_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r03_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r03_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r03_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r03_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r03_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r03_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r03_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r03_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r03_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r03_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r03_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r03_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r03_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r03_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r03_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r03_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r03_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r03_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz


if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_fALFF_r-04_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_fALFF_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r04_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r04_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r04_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r04_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r04_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r04_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r04_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r04_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r04_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r04_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r04_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r04_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r04_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r04_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r04_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r04_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r04_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r04_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r04_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r04_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r04_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r04_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r04_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r04_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r04_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r04_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r04_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r04_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r04_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r04_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r04_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r04_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r04_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r04_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r04_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r04_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r04_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r04_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r04_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r04_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r04_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r04_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r04_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r04_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r04_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r04_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r04_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r04_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r04_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r04_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r04_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r04_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r04_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r04_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r04_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r04_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r04_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r04_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r04_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r04_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r04_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r04_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r04_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r04_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r04_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r04_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r04_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r04_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r04_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r04_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz

if_missing_do lme/all_congruent
replace_and wait lme/all_congruent/mod_all_congruent_RSFA_r-04_CVR.nii.gz

3dLMEr -prefix lme/all_congruent/mod_all_congruent_RSFA_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r04_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_all_congruent.nii.gz \
    001  02  norm/001_02_r04_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_all_congruent.nii.gz \
    001  03  norm/001_03_r04_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_all_congruent.nii.gz \
    001  04  norm/001_04_r04_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_all_congruent.nii.gz \
    001  05  norm/001_05_r04_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_all_congruent.nii.gz \
    001  06  norm/001_06_r04_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_all_congruent.nii.gz \
    001  07  norm/001_07_r04_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_all_congruent.nii.gz \
    001  08  norm/001_08_r04_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_all_congruent.nii.gz \
    001  09  norm/001_09_r04_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_all_congruent.nii.gz \
    001  10  norm/001_10_r04_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_all_congruent.nii.gz \
    002  01  norm/002_01_r04_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_all_congruent.nii.gz \
    002  02  norm/002_02_r04_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_all_congruent.nii.gz \
    002  03  norm/002_03_r04_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_all_congruent.nii.gz \
    002  04  norm/002_04_r04_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_all_congruent.nii.gz \
    002  05  norm/002_05_r04_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_all_congruent.nii.gz \
    002  06  norm/002_06_r04_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_all_congruent.nii.gz \
    002  07  norm/002_07_r04_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_all_congruent.nii.gz \
    002  08  norm/002_08_r04_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_all_congruent.nii.gz \
    002  09  norm/002_09_r04_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_all_congruent.nii.gz \
    002  10  norm/002_10_r04_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_all_congruent.nii.gz \
    003  01  norm/003_01_r04_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_all_congruent.nii.gz \
    003  02  norm/003_02_r04_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_all_congruent.nii.gz \
    003  03  norm/003_03_r04_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_all_congruent.nii.gz \
    003  04  norm/003_04_r04_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_all_congruent.nii.gz \
    003  05  norm/003_05_r04_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_all_congruent.nii.gz \
    003  06  norm/003_06_r04_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_all_congruent.nii.gz \
    003  07  norm/003_07_r04_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_all_congruent.nii.gz \
    003  08  norm/003_08_r04_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_all_congruent.nii.gz \
    003  09  norm/003_09_r04_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_all_congruent.nii.gz \
    003  10  norm/003_10_r04_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_all_congruent.nii.gz \
    004  01  norm/004_01_r04_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_all_congruent.nii.gz \
    004  02  norm/004_02_r04_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_all_congruent.nii.gz \
    004  03  norm/004_03_r04_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_all_congruent.nii.gz \
    004  04  norm/004_04_r04_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_all_congruent.nii.gz \
    004  05  norm/004_05_r04_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_all_congruent.nii.gz \
    004  06  norm/004_06_r04_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_all_congruent.nii.gz \
    004  07  norm/004_07_r04_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_all_congruent.nii.gz \
    004  08  norm/004_08_r04_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_all_congruent.nii.gz \
    004  09  norm/004_09_r04_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_all_congruent.nii.gz \
    004  10  norm/004_10_r04_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_all_congruent.nii.gz \
    007  01  norm/007_01_r04_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_all_congruent.nii.gz \
    007  02  norm/007_02_r04_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_all_congruent.nii.gz \
    007  03  norm/007_03_r04_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_all_congruent.nii.gz \
    007  04  norm/007_04_r04_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_all_congruent.nii.gz \
    007  05  norm/007_05_r04_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_all_congruent.nii.gz \
    007  06  norm/007_06_r04_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_all_congruent.nii.gz \
    007  07  norm/007_07_r04_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_all_congruent.nii.gz \
    007  08  norm/007_08_r04_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_all_congruent.nii.gz \
    007  09  norm/007_09_r04_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_all_congruent.nii.gz \
    007  10  norm/007_10_r04_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_all_congruent.nii.gz \
    008  01  norm/008_01_r04_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_all_congruent.nii.gz \
    008  02  norm/008_02_r04_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_all_congruent.nii.gz \
    008  03  norm/008_03_r04_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_all_congruent.nii.gz \
    008  04  norm/008_04_r04_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_all_congruent.nii.gz \
    008  05  norm/008_05_r04_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_all_congruent.nii.gz \
    008  06  norm/008_06_r04_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_all_congruent.nii.gz \
    008  07  norm/008_07_r04_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_all_congruent.nii.gz \
    008  08  norm/008_08_r04_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_all_congruent.nii.gz \
    008  09  norm/008_09_r04_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_all_congruent.nii.gz \
    008  10  norm/008_10_r04_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_all_congruent.nii.gz \
    009  01  norm/009_01_r04_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_all_congruent.nii.gz \
    009  02  norm/009_02_r04_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_all_congruent.nii.gz \
    009  03  norm/009_03_r04_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_all_congruent.nii.gz \
    009  04  norm/009_04_r04_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_all_congruent.nii.gz \
    009  05  norm/009_05_r04_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_all_congruent.nii.gz \
    009  06  norm/009_06_r04_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_all_congruent.nii.gz \
    009  07  norm/009_07_r04_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_all_congruent.nii.gz \
    009  08  norm/009_08_r04_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_all_congruent.nii.gz \
    009  09  norm/009_09_r04_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_all_congruent.nii.gz \
    009  10  norm/009_10_r04_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_all_congruent.nii.gz


if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-01_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r01_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r01_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r01_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r01_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r01_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r01_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r01_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r01_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r01_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r01_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r01_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r01_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r01_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r01_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r01_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r01_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r01_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r01_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r01_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r01_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r01_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r01_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r01_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r01_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r01_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r01_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r01_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r01_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r01_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r01_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r01_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r01_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r01_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r01_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r01_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r01_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r01_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r01_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r01_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r01_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r01_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r01_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r01_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r01_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r01_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r01_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r01_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r01_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r01_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r01_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r01_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r01_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r01_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r01_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r01_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r01_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r01_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r01_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r01_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r01_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r01_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r01_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r01_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r01_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r01_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r01_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r01_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r01_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r01_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r01_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz

if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-01_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r01_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r01_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r01_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r01_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r01_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r01_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r01_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r01_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r01_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r01_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r01_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r01_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r01_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r01_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r01_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r01_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r01_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r01_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r01_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r01_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r01_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r01_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r01_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r01_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r01_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r01_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r01_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r01_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r01_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r01_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r01_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r01_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r01_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r01_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r01_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r01_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r01_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r01_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r01_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r01_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r01_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r01_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r01_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r01_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r01_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r01_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r01_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r01_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r01_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r01_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r01_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r01_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r01_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r01_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r01_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r01_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r01_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r01_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r01_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r01_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r01_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r01_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r01_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r01_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r01_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r01_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r01_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r01_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r01_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r01_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz


if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-02_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r02_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r02_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r02_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r02_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r02_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r02_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r02_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r02_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r02_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r02_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r02_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r02_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r02_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r02_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r02_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r02_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r02_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r02_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r02_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r02_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r02_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r02_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r02_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r02_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r02_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r02_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r02_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r02_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r02_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r02_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r02_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r02_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r02_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r02_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r02_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r02_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r02_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r02_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r02_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r02_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r02_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r02_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r02_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r02_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r02_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r02_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r02_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r02_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r02_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r02_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r02_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r02_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r02_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r02_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r02_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r02_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r02_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r02_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r02_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r02_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r02_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r02_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r02_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r02_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r02_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r02_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r02_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r02_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r02_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r02_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz

if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-02_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r02_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r02_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r02_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r02_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r02_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r02_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r02_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r02_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r02_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r02_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r02_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r02_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r02_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r02_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r02_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r02_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r02_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r02_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r02_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r02_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r02_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r02_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r02_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r02_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r02_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r02_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r02_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r02_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r02_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r02_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r02_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r02_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r02_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r02_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r02_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r02_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r02_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r02_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r02_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r02_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r02_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r02_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r02_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r02_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r02_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r02_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r02_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r02_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r02_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r02_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r02_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r02_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r02_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r02_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r02_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r02_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r02_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r02_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r02_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r02_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r02_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r02_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r02_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r02_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r02_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r02_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r02_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r02_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r02_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r02_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz


if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-03_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r03_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r03_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r03_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r03_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r03_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r03_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r03_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r03_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r03_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r03_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r03_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r03_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r03_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r03_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r03_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r03_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r03_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r03_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r03_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r03_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r03_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r03_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r03_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r03_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r03_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r03_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r03_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r03_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r03_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r03_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r03_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r03_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r03_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r03_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r03_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r03_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r03_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r03_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r03_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r03_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r03_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r03_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r03_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r03_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r03_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r03_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r03_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r03_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r03_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r03_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r03_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r03_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r03_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r03_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r03_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r03_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r03_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r03_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r03_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r03_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r03_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r03_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r03_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r03_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r03_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r03_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r03_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r03_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r03_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r03_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz

if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-03_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r03_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r03_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r03_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r03_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r03_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r03_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r03_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r03_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r03_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r03_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r03_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r03_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r03_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r03_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r03_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r03_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r03_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r03_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r03_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r03_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r03_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r03_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r03_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r03_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r03_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r03_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r03_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r03_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r03_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r03_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r03_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r03_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r03_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r03_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r03_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r03_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r03_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r03_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r03_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r03_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r03_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r03_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r03_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r03_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r03_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r03_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r03_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r03_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r03_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r03_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r03_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r03_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r03_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r03_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r03_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r03_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r03_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r03_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r03_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r03_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r03_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r03_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r03_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r03_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r03_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r03_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r03_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r03_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r03_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r03_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz


if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-04_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_fALFF_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r04_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r04_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r04_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r04_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r04_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r04_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r04_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r04_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r04_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r04_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r04_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r04_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r04_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r04_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r04_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r04_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r04_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r04_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r04_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r04_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r04_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r04_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r04_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r04_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r04_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r04_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r04_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r04_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r04_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r04_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r04_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r04_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r04_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r04_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r04_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r04_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r04_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r04_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r04_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r04_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r04_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r04_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r04_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r04_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r04_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r04_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r04_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r04_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r04_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r04_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r04_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r04_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r04_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r04_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r04_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r04_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r04_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r04_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r04_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r04_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r04_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r04_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r04_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r04_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r04_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r04_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r04_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r04_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r04_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r04_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz

if_missing_do lme/congruent_and_incongruent
replace_and wait lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-04_CVR.nii.gz

3dLMEr -prefix lme/congruent_and_incongruent/mod_congruent_and_incongruent_RSFA_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r04_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_and_incongruent.nii.gz \
    001  02  norm/001_02_r04_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_and_incongruent.nii.gz \
    001  03  norm/001_03_r04_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_and_incongruent.nii.gz \
    001  04  norm/001_04_r04_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_and_incongruent.nii.gz \
    001  05  norm/001_05_r04_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_and_incongruent.nii.gz \
    001  06  norm/001_06_r04_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_and_incongruent.nii.gz \
    001  07  norm/001_07_r04_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_and_incongruent.nii.gz \
    001  08  norm/001_08_r04_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_and_incongruent.nii.gz \
    001  09  norm/001_09_r04_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_and_incongruent.nii.gz \
    001  10  norm/001_10_r04_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_and_incongruent.nii.gz \
    002  01  norm/002_01_r04_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_and_incongruent.nii.gz \
    002  02  norm/002_02_r04_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_and_incongruent.nii.gz \
    002  03  norm/002_03_r04_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_and_incongruent.nii.gz \
    002  04  norm/002_04_r04_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_and_incongruent.nii.gz \
    002  05  norm/002_05_r04_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_and_incongruent.nii.gz \
    002  06  norm/002_06_r04_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_and_incongruent.nii.gz \
    002  07  norm/002_07_r04_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_and_incongruent.nii.gz \
    002  08  norm/002_08_r04_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_and_incongruent.nii.gz \
    002  09  norm/002_09_r04_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_and_incongruent.nii.gz \
    002  10  norm/002_10_r04_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_and_incongruent.nii.gz \
    003  01  norm/003_01_r04_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_and_incongruent.nii.gz \
    003  02  norm/003_02_r04_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_and_incongruent.nii.gz \
    003  03  norm/003_03_r04_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_and_incongruent.nii.gz \
    003  04  norm/003_04_r04_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_and_incongruent.nii.gz \
    003  05  norm/003_05_r04_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_and_incongruent.nii.gz \
    003  06  norm/003_06_r04_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_and_incongruent.nii.gz \
    003  07  norm/003_07_r04_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_and_incongruent.nii.gz \
    003  08  norm/003_08_r04_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_and_incongruent.nii.gz \
    003  09  norm/003_09_r04_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_and_incongruent.nii.gz \
    003  10  norm/003_10_r04_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_and_incongruent.nii.gz \
    004  01  norm/004_01_r04_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_and_incongruent.nii.gz \
    004  02  norm/004_02_r04_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_and_incongruent.nii.gz \
    004  03  norm/004_03_r04_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_and_incongruent.nii.gz \
    004  04  norm/004_04_r04_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_and_incongruent.nii.gz \
    004  05  norm/004_05_r04_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_and_incongruent.nii.gz \
    004  06  norm/004_06_r04_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_and_incongruent.nii.gz \
    004  07  norm/004_07_r04_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_and_incongruent.nii.gz \
    004  08  norm/004_08_r04_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_and_incongruent.nii.gz \
    004  09  norm/004_09_r04_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_and_incongruent.nii.gz \
    004  10  norm/004_10_r04_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_and_incongruent.nii.gz \
    007  01  norm/007_01_r04_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_and_incongruent.nii.gz \
    007  02  norm/007_02_r04_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_and_incongruent.nii.gz \
    007  03  norm/007_03_r04_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_and_incongruent.nii.gz \
    007  04  norm/007_04_r04_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_and_incongruent.nii.gz \
    007  05  norm/007_05_r04_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_and_incongruent.nii.gz \
    007  06  norm/007_06_r04_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_and_incongruent.nii.gz \
    007  07  norm/007_07_r04_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_and_incongruent.nii.gz \
    007  08  norm/007_08_r04_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_and_incongruent.nii.gz \
    007  09  norm/007_09_r04_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_and_incongruent.nii.gz \
    007  10  norm/007_10_r04_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_and_incongruent.nii.gz \
    008  01  norm/008_01_r04_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_and_incongruent.nii.gz \
    008  02  norm/008_02_r04_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_and_incongruent.nii.gz \
    008  03  norm/008_03_r04_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_and_incongruent.nii.gz \
    008  04  norm/008_04_r04_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_and_incongruent.nii.gz \
    008  05  norm/008_05_r04_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_and_incongruent.nii.gz \
    008  06  norm/008_06_r04_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_and_incongruent.nii.gz \
    008  07  norm/008_07_r04_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_and_incongruent.nii.gz \
    008  08  norm/008_08_r04_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_and_incongruent.nii.gz \
    008  09  norm/008_09_r04_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_and_incongruent.nii.gz \
    008  10  norm/008_10_r04_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_and_incongruent.nii.gz \
    009  01  norm/009_01_r04_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_and_incongruent.nii.gz \
    009  02  norm/009_02_r04_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_and_incongruent.nii.gz \
    009  03  norm/009_03_r04_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_and_incongruent.nii.gz \
    009  04  norm/009_04_r04_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_and_incongruent.nii.gz \
    009  05  norm/009_05_r04_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_and_incongruent.nii.gz \
    009  06  norm/009_06_r04_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_and_incongruent.nii.gz \
    009  07  norm/009_07_r04_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_and_incongruent.nii.gz \
    009  08  norm/009_08_r04_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_and_incongruent.nii.gz \
    009  09  norm/009_09_r04_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_and_incongruent.nii.gz \
    009  10  norm/009_10_r04_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_and_incongruent.nii.gz


if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-01_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r01_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r01_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r01_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r01_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r01_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r01_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r01_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r01_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r01_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r01_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r01_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r01_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r01_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r01_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r01_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r01_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r01_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r01_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r01_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r01_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r01_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r01_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r01_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r01_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r01_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r01_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r01_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r01_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r01_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r01_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r01_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r01_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r01_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r01_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r01_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r01_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r01_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r01_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r01_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r01_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r01_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r01_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r01_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r01_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r01_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r01_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r01_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r01_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r01_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r01_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r01_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r01_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r01_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r01_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r01_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r01_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r01_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r01_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r01_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r01_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r01_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r01_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r01_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r01_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r01_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r01_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r01_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r01_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r01_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r01_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz

if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-01_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r01_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r01_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r01_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r01_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r01_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r01_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r01_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r01_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r01_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r01_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r01_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r01_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r01_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r01_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r01_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r01_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r01_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r01_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r01_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r01_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r01_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r01_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r01_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r01_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r01_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r01_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r01_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r01_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r01_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r01_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r01_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r01_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r01_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r01_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r01_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r01_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r01_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r01_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r01_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r01_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r01_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r01_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r01_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r01_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r01_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r01_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r01_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r01_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r01_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r01_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r01_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r01_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r01_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r01_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r01_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r01_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r01_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r01_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r01_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r01_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r01_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r01_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r01_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r01_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r01_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r01_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r01_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r01_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r01_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r01_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz


if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-02_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r02_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r02_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r02_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r02_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r02_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r02_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r02_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r02_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r02_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r02_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r02_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r02_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r02_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r02_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r02_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r02_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r02_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r02_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r02_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r02_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r02_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r02_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r02_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r02_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r02_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r02_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r02_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r02_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r02_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r02_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r02_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r02_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r02_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r02_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r02_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r02_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r02_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r02_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r02_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r02_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r02_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r02_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r02_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r02_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r02_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r02_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r02_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r02_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r02_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r02_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r02_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r02_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r02_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r02_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r02_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r02_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r02_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r02_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r02_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r02_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r02_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r02_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r02_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r02_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r02_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r02_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r02_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r02_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r02_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r02_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz

if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-02_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r02_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r02_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r02_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r02_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r02_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r02_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r02_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r02_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r02_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r02_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r02_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r02_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r02_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r02_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r02_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r02_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r02_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r02_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r02_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r02_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r02_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r02_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r02_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r02_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r02_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r02_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r02_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r02_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r02_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r02_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r02_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r02_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r02_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r02_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r02_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r02_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r02_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r02_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r02_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r02_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r02_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r02_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r02_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r02_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r02_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r02_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r02_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r02_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r02_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r02_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r02_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r02_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r02_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r02_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r02_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r02_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r02_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r02_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r02_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r02_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r02_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r02_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r02_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r02_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r02_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r02_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r02_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r02_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r02_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r02_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz


if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-03_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r03_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r03_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r03_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r03_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r03_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r03_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r03_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r03_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r03_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r03_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r03_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r03_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r03_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r03_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r03_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r03_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r03_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r03_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r03_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r03_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r03_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r03_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r03_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r03_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r03_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r03_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r03_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r03_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r03_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r03_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r03_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r03_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r03_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r03_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r03_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r03_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r03_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r03_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r03_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r03_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r03_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r03_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r03_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r03_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r03_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r03_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r03_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r03_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r03_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r03_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r03_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r03_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r03_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r03_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r03_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r03_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r03_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r03_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r03_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r03_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r03_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r03_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r03_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r03_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r03_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r03_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r03_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r03_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r03_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r03_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz

if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-03_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r03_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r03_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r03_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r03_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r03_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r03_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r03_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r03_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r03_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r03_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r03_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r03_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r03_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r03_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r03_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r03_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r03_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r03_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r03_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r03_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r03_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r03_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r03_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r03_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r03_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r03_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r03_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r03_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r03_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r03_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r03_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r03_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r03_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r03_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r03_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r03_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r03_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r03_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r03_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r03_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r03_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r03_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r03_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r03_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r03_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r03_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r03_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r03_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r03_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r03_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r03_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r03_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r03_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r03_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r03_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r03_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r03_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r03_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r03_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r03_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r03_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r03_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r03_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r03_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r03_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r03_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r03_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r03_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r03_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r03_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz


if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-04_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_fALFF_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r04_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r04_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r04_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r04_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r04_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r04_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r04_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r04_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r04_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r04_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r04_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r04_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r04_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r04_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r04_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r04_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r04_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r04_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r04_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r04_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r04_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r04_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r04_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r04_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r04_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r04_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r04_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r04_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r04_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r04_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r04_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r04_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r04_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r04_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r04_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r04_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r04_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r04_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r04_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r04_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r04_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r04_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r04_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r04_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r04_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r04_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r04_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r04_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r04_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r04_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r04_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r04_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r04_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r04_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r04_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r04_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r04_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r04_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r04_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r04_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r04_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r04_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r04_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r04_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r04_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r04_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r04_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r04_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r04_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r04_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz

if_missing_do lme/congruent_vs_incongruent
replace_and wait lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-04_CVR.nii.gz

3dLMEr -prefix lme/congruent_vs_incongruent/mod_congruent_vs_incongruent_RSFA_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r04_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_congruent_vs_incongruent.nii.gz \
    001  02  norm/001_02_r04_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_congruent_vs_incongruent.nii.gz \
    001  03  norm/001_03_r04_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_congruent_vs_incongruent.nii.gz \
    001  04  norm/001_04_r04_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_congruent_vs_incongruent.nii.gz \
    001  05  norm/001_05_r04_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_congruent_vs_incongruent.nii.gz \
    001  06  norm/001_06_r04_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_congruent_vs_incongruent.nii.gz \
    001  07  norm/001_07_r04_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_congruent_vs_incongruent.nii.gz \
    001  08  norm/001_08_r04_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_congruent_vs_incongruent.nii.gz \
    001  09  norm/001_09_r04_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_congruent_vs_incongruent.nii.gz \
    001  10  norm/001_10_r04_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_congruent_vs_incongruent.nii.gz \
    002  01  norm/002_01_r04_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_congruent_vs_incongruent.nii.gz \
    002  02  norm/002_02_r04_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_congruent_vs_incongruent.nii.gz \
    002  03  norm/002_03_r04_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_congruent_vs_incongruent.nii.gz \
    002  04  norm/002_04_r04_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_congruent_vs_incongruent.nii.gz \
    002  05  norm/002_05_r04_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_congruent_vs_incongruent.nii.gz \
    002  06  norm/002_06_r04_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_congruent_vs_incongruent.nii.gz \
    002  07  norm/002_07_r04_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_congruent_vs_incongruent.nii.gz \
    002  08  norm/002_08_r04_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_congruent_vs_incongruent.nii.gz \
    002  09  norm/002_09_r04_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_congruent_vs_incongruent.nii.gz \
    002  10  norm/002_10_r04_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_congruent_vs_incongruent.nii.gz \
    003  01  norm/003_01_r04_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_congruent_vs_incongruent.nii.gz \
    003  02  norm/003_02_r04_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_congruent_vs_incongruent.nii.gz \
    003  03  norm/003_03_r04_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_congruent_vs_incongruent.nii.gz \
    003  04  norm/003_04_r04_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_congruent_vs_incongruent.nii.gz \
    003  05  norm/003_05_r04_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_congruent_vs_incongruent.nii.gz \
    003  06  norm/003_06_r04_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_congruent_vs_incongruent.nii.gz \
    003  07  norm/003_07_r04_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_congruent_vs_incongruent.nii.gz \
    003  08  norm/003_08_r04_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_congruent_vs_incongruent.nii.gz \
    003  09  norm/003_09_r04_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_congruent_vs_incongruent.nii.gz \
    003  10  norm/003_10_r04_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_congruent_vs_incongruent.nii.gz \
    004  01  norm/004_01_r04_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_congruent_vs_incongruent.nii.gz \
    004  02  norm/004_02_r04_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_congruent_vs_incongruent.nii.gz \
    004  03  norm/004_03_r04_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_congruent_vs_incongruent.nii.gz \
    004  04  norm/004_04_r04_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_congruent_vs_incongruent.nii.gz \
    004  05  norm/004_05_r04_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_congruent_vs_incongruent.nii.gz \
    004  06  norm/004_06_r04_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_congruent_vs_incongruent.nii.gz \
    004  07  norm/004_07_r04_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_congruent_vs_incongruent.nii.gz \
    004  08  norm/004_08_r04_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_congruent_vs_incongruent.nii.gz \
    004  09  norm/004_09_r04_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_congruent_vs_incongruent.nii.gz \
    004  10  norm/004_10_r04_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_congruent_vs_incongruent.nii.gz \
    007  01  norm/007_01_r04_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_congruent_vs_incongruent.nii.gz \
    007  02  norm/007_02_r04_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_congruent_vs_incongruent.nii.gz \
    007  03  norm/007_03_r04_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_congruent_vs_incongruent.nii.gz \
    007  04  norm/007_04_r04_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_congruent_vs_incongruent.nii.gz \
    007  05  norm/007_05_r04_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_congruent_vs_incongruent.nii.gz \
    007  06  norm/007_06_r04_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_congruent_vs_incongruent.nii.gz \
    007  07  norm/007_07_r04_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_congruent_vs_incongruent.nii.gz \
    007  08  norm/007_08_r04_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_congruent_vs_incongruent.nii.gz \
    007  09  norm/007_09_r04_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_congruent_vs_incongruent.nii.gz \
    007  10  norm/007_10_r04_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_congruent_vs_incongruent.nii.gz \
    008  01  norm/008_01_r04_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_congruent_vs_incongruent.nii.gz \
    008  02  norm/008_02_r04_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_congruent_vs_incongruent.nii.gz \
    008  03  norm/008_03_r04_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_congruent_vs_incongruent.nii.gz \
    008  04  norm/008_04_r04_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_congruent_vs_incongruent.nii.gz \
    008  05  norm/008_05_r04_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_congruent_vs_incongruent.nii.gz \
    008  06  norm/008_06_r04_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_congruent_vs_incongruent.nii.gz \
    008  07  norm/008_07_r04_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_congruent_vs_incongruent.nii.gz \
    008  08  norm/008_08_r04_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_congruent_vs_incongruent.nii.gz \
    008  09  norm/008_09_r04_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_congruent_vs_incongruent.nii.gz \
    008  10  norm/008_10_r04_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_congruent_vs_incongruent.nii.gz \
    009  01  norm/009_01_r04_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_congruent_vs_incongruent.nii.gz \
    009  02  norm/009_02_r04_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_congruent_vs_incongruent.nii.gz \
    009  03  norm/009_03_r04_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_congruent_vs_incongruent.nii.gz \
    009  04  norm/009_04_r04_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_congruent_vs_incongruent.nii.gz \
    009  05  norm/009_05_r04_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_congruent_vs_incongruent.nii.gz \
    009  06  norm/009_06_r04_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_congruent_vs_incongruent.nii.gz \
    009  07  norm/009_07_r04_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_congruent_vs_incongruent.nii.gz \
    009  08  norm/009_08_r04_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_congruent_vs_incongruent.nii.gz \
    009  09  norm/009_09_r04_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_congruent_vs_incongruent.nii.gz \
    009  10  norm/009_10_r04_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_congruent_vs_incongruent.nii.gz


if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_fALFF_r-01_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_fALFF_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r01_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r01_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r01_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r01_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r01_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r01_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r01_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r01_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r01_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r01_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r01_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r01_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r01_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r01_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r01_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r01_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r01_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r01_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r01_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r01_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r01_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r01_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r01_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r01_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r01_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r01_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r01_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r01_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r01_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r01_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r01_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r01_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r01_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r01_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r01_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r01_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r01_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r01_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r01_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r01_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r01_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r01_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r01_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r01_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r01_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r01_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r01_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r01_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r01_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r01_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r01_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r01_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r01_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r01_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r01_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r01_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r01_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r01_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r01_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r01_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r01_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r01_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r01_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r01_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r01_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r01_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r01_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r01_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r01_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r01_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz

if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_RSFA_r-01_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_RSFA_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r01_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r01_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r01_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r01_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r01_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r01_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r01_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r01_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r01_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r01_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r01_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r01_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r01_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r01_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r01_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r01_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r01_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r01_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r01_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r01_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r01_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r01_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r01_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r01_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r01_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r01_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r01_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r01_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r01_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r01_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r01_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r01_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r01_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r01_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r01_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r01_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r01_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r01_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r01_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r01_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r01_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r01_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r01_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r01_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r01_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r01_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r01_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r01_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r01_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r01_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r01_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r01_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r01_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r01_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r01_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r01_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r01_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r01_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r01_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r01_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r01_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r01_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r01_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r01_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r01_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r01_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r01_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r01_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r01_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r01_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz


if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_fALFF_r-02_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_fALFF_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r02_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r02_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r02_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r02_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r02_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r02_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r02_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r02_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r02_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r02_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r02_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r02_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r02_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r02_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r02_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r02_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r02_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r02_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r02_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r02_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r02_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r02_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r02_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r02_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r02_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r02_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r02_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r02_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r02_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r02_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r02_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r02_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r02_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r02_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r02_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r02_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r02_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r02_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r02_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r02_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r02_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r02_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r02_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r02_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r02_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r02_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r02_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r02_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r02_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r02_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r02_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r02_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r02_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r02_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r02_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r02_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r02_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r02_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r02_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r02_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r02_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r02_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r02_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r02_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r02_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r02_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r02_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r02_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r02_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r02_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz

if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_RSFA_r-02_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_RSFA_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r02_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r02_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r02_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r02_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r02_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r02_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r02_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r02_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r02_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r02_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r02_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r02_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r02_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r02_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r02_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r02_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r02_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r02_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r02_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r02_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r02_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r02_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r02_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r02_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r02_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r02_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r02_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r02_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r02_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r02_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r02_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r02_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r02_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r02_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r02_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r02_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r02_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r02_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r02_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r02_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r02_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r02_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r02_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r02_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r02_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r02_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r02_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r02_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r02_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r02_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r02_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r02_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r02_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r02_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r02_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r02_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r02_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r02_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r02_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r02_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r02_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r02_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r02_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r02_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r02_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r02_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r02_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r02_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r02_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r02_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz


if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_fALFF_r-03_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_fALFF_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r03_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r03_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r03_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r03_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r03_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r03_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r03_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r03_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r03_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r03_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r03_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r03_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r03_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r03_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r03_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r03_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r03_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r03_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r03_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r03_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r03_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r03_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r03_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r03_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r03_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r03_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r03_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r03_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r03_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r03_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r03_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r03_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r03_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r03_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r03_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r03_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r03_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r03_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r03_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r03_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r03_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r03_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r03_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r03_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r03_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r03_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r03_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r03_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r03_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r03_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r03_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r03_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r03_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r03_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r03_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r03_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r03_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r03_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r03_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r03_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r03_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r03_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r03_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r03_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r03_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r03_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r03_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r03_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r03_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r03_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz

if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_RSFA_r-03_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_RSFA_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r03_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r03_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r03_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r03_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r03_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r03_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r03_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r03_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r03_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r03_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r03_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r03_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r03_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r03_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r03_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r03_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r03_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r03_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r03_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r03_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r03_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r03_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r03_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r03_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r03_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r03_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r03_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r03_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r03_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r03_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r03_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r03_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r03_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r03_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r03_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r03_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r03_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r03_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r03_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r03_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r03_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r03_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r03_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r03_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r03_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r03_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r03_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r03_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r03_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r03_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r03_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r03_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r03_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r03_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r03_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r03_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r03_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r03_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r03_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r03_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r03_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r03_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r03_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r03_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r03_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r03_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r03_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r03_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r03_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r03_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz


if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_fALFF_r-04_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_fALFF_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r04_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r04_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r04_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r04_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r04_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r04_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r04_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r04_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r04_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r04_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r04_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r04_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r04_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r04_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r04_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r04_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r04_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r04_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r04_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r04_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r04_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r04_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r04_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r04_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r04_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r04_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r04_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r04_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r04_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r04_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r04_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r04_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r04_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r04_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r04_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r04_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r04_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r04_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r04_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r04_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r04_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r04_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r04_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r04_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r04_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r04_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r04_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r04_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r04_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r04_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r04_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r04_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r04_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r04_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r04_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r04_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r04_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r04_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r04_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r04_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r04_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r04_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r04_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r04_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r04_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r04_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r04_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r04_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r04_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r04_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz

if_missing_do lme/allmotors
replace_and wait lme/allmotors/mod_allmotors_RSFA_r-04_CVR.nii.gz

3dLMEr -prefix lme/allmotors/mod_allmotors_RSFA_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r04_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_allmotors.nii.gz \
    001  02  norm/001_02_r04_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_allmotors.nii.gz \
    001  03  norm/001_03_r04_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_allmotors.nii.gz \
    001  04  norm/001_04_r04_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_allmotors.nii.gz \
    001  05  norm/001_05_r04_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_allmotors.nii.gz \
    001  06  norm/001_06_r04_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_allmotors.nii.gz \
    001  07  norm/001_07_r04_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_allmotors.nii.gz \
    001  08  norm/001_08_r04_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_allmotors.nii.gz \
    001  09  norm/001_09_r04_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_allmotors.nii.gz \
    001  10  norm/001_10_r04_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_allmotors.nii.gz \
    002  01  norm/002_01_r04_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_allmotors.nii.gz \
    002  02  norm/002_02_r04_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_allmotors.nii.gz \
    002  03  norm/002_03_r04_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_allmotors.nii.gz \
    002  04  norm/002_04_r04_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_allmotors.nii.gz \
    002  05  norm/002_05_r04_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_allmotors.nii.gz \
    002  06  norm/002_06_r04_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_allmotors.nii.gz \
    002  07  norm/002_07_r04_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_allmotors.nii.gz \
    002  08  norm/002_08_r04_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_allmotors.nii.gz \
    002  09  norm/002_09_r04_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_allmotors.nii.gz \
    002  10  norm/002_10_r04_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_allmotors.nii.gz \
    003  01  norm/003_01_r04_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_allmotors.nii.gz \
    003  02  norm/003_02_r04_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_allmotors.nii.gz \
    003  03  norm/003_03_r04_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_allmotors.nii.gz \
    003  04  norm/003_04_r04_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_allmotors.nii.gz \
    003  05  norm/003_05_r04_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_allmotors.nii.gz \
    003  06  norm/003_06_r04_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_allmotors.nii.gz \
    003  07  norm/003_07_r04_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_allmotors.nii.gz \
    003  08  norm/003_08_r04_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_allmotors.nii.gz \
    003  09  norm/003_09_r04_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_allmotors.nii.gz \
    003  10  norm/003_10_r04_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_allmotors.nii.gz \
    004  01  norm/004_01_r04_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_allmotors.nii.gz \
    004  02  norm/004_02_r04_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_allmotors.nii.gz \
    004  03  norm/004_03_r04_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_allmotors.nii.gz \
    004  04  norm/004_04_r04_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_allmotors.nii.gz \
    004  05  norm/004_05_r04_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_allmotors.nii.gz \
    004  06  norm/004_06_r04_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_allmotors.nii.gz \
    004  07  norm/004_07_r04_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_allmotors.nii.gz \
    004  08  norm/004_08_r04_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_allmotors.nii.gz \
    004  09  norm/004_09_r04_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_allmotors.nii.gz \
    004  10  norm/004_10_r04_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_allmotors.nii.gz \
    007  01  norm/007_01_r04_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_allmotors.nii.gz \
    007  02  norm/007_02_r04_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_allmotors.nii.gz \
    007  03  norm/007_03_r04_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_allmotors.nii.gz \
    007  04  norm/007_04_r04_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_allmotors.nii.gz \
    007  05  norm/007_05_r04_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_allmotors.nii.gz \
    007  06  norm/007_06_r04_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_allmotors.nii.gz \
    007  07  norm/007_07_r04_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_allmotors.nii.gz \
    007  08  norm/007_08_r04_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_allmotors.nii.gz \
    007  09  norm/007_09_r04_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_allmotors.nii.gz \
    007  10  norm/007_10_r04_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_allmotors.nii.gz \
    008  01  norm/008_01_r04_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_allmotors.nii.gz \
    008  02  norm/008_02_r04_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_allmotors.nii.gz \
    008  03  norm/008_03_r04_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_allmotors.nii.gz \
    008  04  norm/008_04_r04_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_allmotors.nii.gz \
    008  05  norm/008_05_r04_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_allmotors.nii.gz \
    008  06  norm/008_06_r04_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_allmotors.nii.gz \
    008  07  norm/008_07_r04_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_allmotors.nii.gz \
    008  08  norm/008_08_r04_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_allmotors.nii.gz \
    008  09  norm/008_09_r04_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_allmotors.nii.gz \
    008  10  norm/008_10_r04_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_allmotors.nii.gz \
    009  01  norm/009_01_r04_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_allmotors.nii.gz \
    009  02  norm/009_02_r04_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_allmotors.nii.gz \
    009  03  norm/009_03_r04_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_allmotors.nii.gz \
    009  04  norm/009_04_r04_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_allmotors.nii.gz \
    009  05  norm/009_05_r04_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_allmotors.nii.gz \
    009  06  norm/009_06_r04_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_allmotors.nii.gz \
    009  07  norm/009_07_r04_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_allmotors.nii.gz \
    009  08  norm/009_08_r04_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_allmotors.nii.gz \
    009  09  norm/009_09_r04_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_allmotors.nii.gz \
    009  10  norm/009_10_r04_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_allmotors.nii.gz


if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-01_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r01_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r01_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r01_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r01_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r01_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r01_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r01_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r01_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r01_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r01_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r01_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r01_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r01_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r01_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r01_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r01_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r01_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r01_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r01_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r01_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r01_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r01_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r01_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r01_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r01_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r01_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r01_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r01_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r01_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r01_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r01_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r01_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r01_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r01_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r01_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r01_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r01_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r01_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r01_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r01_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r01_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r01_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r01_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r01_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r01_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r01_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r01_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r01_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r01_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r01_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r01_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r01_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r01_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r01_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r01_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r01_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r01_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r01_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r01_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r01_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r01_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r01_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r01_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r01_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r01_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r01_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r01_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r01_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r01_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r01_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz

if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-01_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-01_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r01_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r01_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r01_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r01_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r01_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r01_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r01_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r01_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r01_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r01_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r01_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r01_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r01_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r01_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r01_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r01_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r01_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r01_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r01_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r01_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r01_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r01_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r01_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r01_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r01_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r01_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r01_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r01_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r01_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r01_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r01_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r01_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r01_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r01_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r01_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r01_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r01_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r01_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r01_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r01_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r01_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r01_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r01_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r01_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r01_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r01_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r01_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r01_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r01_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r01_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r01_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r01_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r01_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r01_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r01_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r01_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r01_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r01_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r01_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r01_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r01_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r01_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r01_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r01_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r01_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r01_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r01_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r01_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r01_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r01_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz


if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-02_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r02_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r02_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r02_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r02_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r02_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r02_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r02_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r02_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r02_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r02_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r02_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r02_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r02_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r02_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r02_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r02_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r02_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r02_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r02_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r02_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r02_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r02_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r02_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r02_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r02_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r02_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r02_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r02_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r02_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r02_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r02_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r02_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r02_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r02_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r02_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r02_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r02_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r02_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r02_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r02_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r02_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r02_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r02_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r02_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r02_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r02_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r02_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r02_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r02_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r02_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r02_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r02_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r02_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r02_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r02_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r02_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r02_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r02_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r02_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r02_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r02_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r02_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r02_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r02_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r02_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r02_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r02_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r02_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r02_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r02_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz

if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-02_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-02_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r02_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r02_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r02_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r02_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r02_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r02_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r02_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r02_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r02_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r02_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r02_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r02_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r02_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r02_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r02_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r02_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r02_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r02_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r02_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r02_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r02_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r02_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r02_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r02_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r02_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r02_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r02_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r02_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r02_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r02_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r02_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r02_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r02_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r02_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r02_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r02_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r02_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r02_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r02_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r02_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r02_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r02_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r02_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r02_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r02_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r02_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r02_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r02_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r02_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r02_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r02_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r02_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r02_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r02_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r02_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r02_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r02_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r02_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r02_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r02_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r02_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r02_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r02_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r02_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r02_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r02_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r02_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r02_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r02_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r02_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz


if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-03_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r03_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r03_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r03_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r03_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r03_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r03_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r03_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r03_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r03_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r03_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r03_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r03_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r03_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r03_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r03_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r03_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r03_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r03_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r03_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r03_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r03_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r03_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r03_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r03_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r03_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r03_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r03_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r03_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r03_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r03_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r03_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r03_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r03_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r03_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r03_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r03_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r03_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r03_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r03_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r03_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r03_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r03_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r03_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r03_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r03_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r03_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r03_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r03_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r03_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r03_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r03_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r03_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r03_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r03_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r03_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r03_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r03_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r03_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r03_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r03_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r03_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r03_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r03_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r03_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r03_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r03_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r03_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r03_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r03_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r03_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz

if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-03_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-03_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r03_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r03_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r03_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r03_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r03_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r03_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r03_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r03_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r03_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r03_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r03_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r03_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r03_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r03_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r03_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r03_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r03_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r03_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r03_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r03_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r03_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r03_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r03_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r03_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r03_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r03_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r03_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r03_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r03_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r03_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r03_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r03_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r03_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r03_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r03_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r03_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r03_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r03_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r03_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r03_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r03_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r03_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r03_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r03_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r03_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r03_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r03_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r03_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r03_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r03_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r03_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r03_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r03_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r03_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r03_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r03_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r03_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r03_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r03_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r03_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r03_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r03_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r03_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r03_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r03_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r03_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r03_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r03_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r03_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r03_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz


if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-04_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_fALFF_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'fALFF*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  fALFF   cvr    InputFile  \
    001  01  norm/001_01_r04_fALFF.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r04_fALFF.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r04_fALFF.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r04_fALFF.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r04_fALFF.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r04_fALFF.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r04_fALFF.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r04_fALFF.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r04_fALFF.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r04_fALFF.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r04_fALFF.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r04_fALFF.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r04_fALFF.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r04_fALFF.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r04_fALFF.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r04_fALFF.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r04_fALFF.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r04_fALFF.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r04_fALFF.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r04_fALFF.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r04_fALFF.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r04_fALFF.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r04_fALFF.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r04_fALFF.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r04_fALFF.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r04_fALFF.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r04_fALFF.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r04_fALFF.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r04_fALFF.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r04_fALFF.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r04_fALFF.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r04_fALFF.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r04_fALFF.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r04_fALFF.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r04_fALFF.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r04_fALFF.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r04_fALFF.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r04_fALFF.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r04_fALFF.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r04_fALFF.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r04_fALFF.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r04_fALFF.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r04_fALFF.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r04_fALFF.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r04_fALFF.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r04_fALFF.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r04_fALFF.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r04_fALFF.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r04_fALFF.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r04_fALFF.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r04_fALFF.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r04_fALFF.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r04_fALFF.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r04_fALFF.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r04_fALFF.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r04_fALFF.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r04_fALFF.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r04_fALFF.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r04_fALFF.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r04_fALFF.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r04_fALFF.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r04_fALFF.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r04_fALFF.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r04_fALFF.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r04_fALFF.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r04_fALFF.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r04_fALFF.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r04_fALFF.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r04_fALFF.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r04_fALFF.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz

if_missing_do lme/motors_vs_sham
replace_and wait lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-04_CVR.nii.gz

3dLMEr -prefix lme/motors_vs_sham/mod_motors_vs_sham_RSFA_r-04_CVR.nii.gz \
-jobs 10 -mask reg/MNI_T1_brain_mask.nii.gz \
-model  'RSFA*cvr+(1|session)+(1|Subj)' \
-dataTable \
    Subj session  RSFA   cvr    InputFile  \
    001  01  norm/001_01_r04_RSFA.nii.gz  norm/001_01_cvr.nii.gz  norm/001_01_motors_vs_sham.nii.gz \
    001  02  norm/001_02_r04_RSFA.nii.gz  norm/001_02_cvr.nii.gz  norm/001_02_motors_vs_sham.nii.gz \
    001  03  norm/001_03_r04_RSFA.nii.gz  norm/001_03_cvr.nii.gz  norm/001_03_motors_vs_sham.nii.gz \
    001  04  norm/001_04_r04_RSFA.nii.gz  norm/001_04_cvr.nii.gz  norm/001_04_motors_vs_sham.nii.gz \
    001  05  norm/001_05_r04_RSFA.nii.gz  norm/001_05_cvr.nii.gz  norm/001_05_motors_vs_sham.nii.gz \
    001  06  norm/001_06_r04_RSFA.nii.gz  norm/001_06_cvr.nii.gz  norm/001_06_motors_vs_sham.nii.gz \
    001  07  norm/001_07_r04_RSFA.nii.gz  norm/001_07_cvr.nii.gz  norm/001_07_motors_vs_sham.nii.gz \
    001  08  norm/001_08_r04_RSFA.nii.gz  norm/001_08_cvr.nii.gz  norm/001_08_motors_vs_sham.nii.gz \
    001  09  norm/001_09_r04_RSFA.nii.gz  norm/001_09_cvr.nii.gz  norm/001_09_motors_vs_sham.nii.gz \
    001  10  norm/001_10_r04_RSFA.nii.gz  norm/001_10_cvr.nii.gz  norm/001_10_motors_vs_sham.nii.gz \
    002  01  norm/002_01_r04_RSFA.nii.gz  norm/002_01_cvr.nii.gz  norm/002_01_motors_vs_sham.nii.gz \
    002  02  norm/002_02_r04_RSFA.nii.gz  norm/002_02_cvr.nii.gz  norm/002_02_motors_vs_sham.nii.gz \
    002  03  norm/002_03_r04_RSFA.nii.gz  norm/002_03_cvr.nii.gz  norm/002_03_motors_vs_sham.nii.gz \
    002  04  norm/002_04_r04_RSFA.nii.gz  norm/002_04_cvr.nii.gz  norm/002_04_motors_vs_sham.nii.gz \
    002  05  norm/002_05_r04_RSFA.nii.gz  norm/002_05_cvr.nii.gz  norm/002_05_motors_vs_sham.nii.gz \
    002  06  norm/002_06_r04_RSFA.nii.gz  norm/002_06_cvr.nii.gz  norm/002_06_motors_vs_sham.nii.gz \
    002  07  norm/002_07_r04_RSFA.nii.gz  norm/002_07_cvr.nii.gz  norm/002_07_motors_vs_sham.nii.gz \
    002  08  norm/002_08_r04_RSFA.nii.gz  norm/002_08_cvr.nii.gz  norm/002_08_motors_vs_sham.nii.gz \
    002  09  norm/002_09_r04_RSFA.nii.gz  norm/002_09_cvr.nii.gz  norm/002_09_motors_vs_sham.nii.gz \
    002  10  norm/002_10_r04_RSFA.nii.gz  norm/002_10_cvr.nii.gz  norm/002_10_motors_vs_sham.nii.gz \
    003  01  norm/003_01_r04_RSFA.nii.gz  norm/003_01_cvr.nii.gz  norm/003_01_motors_vs_sham.nii.gz \
    003  02  norm/003_02_r04_RSFA.nii.gz  norm/003_02_cvr.nii.gz  norm/003_02_motors_vs_sham.nii.gz \
    003  03  norm/003_03_r04_RSFA.nii.gz  norm/003_03_cvr.nii.gz  norm/003_03_motors_vs_sham.nii.gz \
    003  04  norm/003_04_r04_RSFA.nii.gz  norm/003_04_cvr.nii.gz  norm/003_04_motors_vs_sham.nii.gz \
    003  05  norm/003_05_r04_RSFA.nii.gz  norm/003_05_cvr.nii.gz  norm/003_05_motors_vs_sham.nii.gz \
    003  06  norm/003_06_r04_RSFA.nii.gz  norm/003_06_cvr.nii.gz  norm/003_06_motors_vs_sham.nii.gz \
    003  07  norm/003_07_r04_RSFA.nii.gz  norm/003_07_cvr.nii.gz  norm/003_07_motors_vs_sham.nii.gz \
    003  08  norm/003_08_r04_RSFA.nii.gz  norm/003_08_cvr.nii.gz  norm/003_08_motors_vs_sham.nii.gz \
    003  09  norm/003_09_r04_RSFA.nii.gz  norm/003_09_cvr.nii.gz  norm/003_09_motors_vs_sham.nii.gz \
    003  10  norm/003_10_r04_RSFA.nii.gz  norm/003_10_cvr.nii.gz  norm/003_10_motors_vs_sham.nii.gz \
    004  01  norm/004_01_r04_RSFA.nii.gz  norm/004_01_cvr.nii.gz  norm/004_01_motors_vs_sham.nii.gz \
    004  02  norm/004_02_r04_RSFA.nii.gz  norm/004_02_cvr.nii.gz  norm/004_02_motors_vs_sham.nii.gz \
    004  03  norm/004_03_r04_RSFA.nii.gz  norm/004_03_cvr.nii.gz  norm/004_03_motors_vs_sham.nii.gz \
    004  04  norm/004_04_r04_RSFA.nii.gz  norm/004_04_cvr.nii.gz  norm/004_04_motors_vs_sham.nii.gz \
    004  05  norm/004_05_r04_RSFA.nii.gz  norm/004_05_cvr.nii.gz  norm/004_05_motors_vs_sham.nii.gz \
    004  06  norm/004_06_r04_RSFA.nii.gz  norm/004_06_cvr.nii.gz  norm/004_06_motors_vs_sham.nii.gz \
    004  07  norm/004_07_r04_RSFA.nii.gz  norm/004_07_cvr.nii.gz  norm/004_07_motors_vs_sham.nii.gz \
    004  08  norm/004_08_r04_RSFA.nii.gz  norm/004_08_cvr.nii.gz  norm/004_08_motors_vs_sham.nii.gz \
    004  09  norm/004_09_r04_RSFA.nii.gz  norm/004_09_cvr.nii.gz  norm/004_09_motors_vs_sham.nii.gz \
    004  10  norm/004_10_r04_RSFA.nii.gz  norm/004_10_cvr.nii.gz  norm/004_10_motors_vs_sham.nii.gz \
    007  01  norm/007_01_r04_RSFA.nii.gz  norm/007_01_cvr.nii.gz  norm/007_01_motors_vs_sham.nii.gz \
    007  02  norm/007_02_r04_RSFA.nii.gz  norm/007_02_cvr.nii.gz  norm/007_02_motors_vs_sham.nii.gz \
    007  03  norm/007_03_r04_RSFA.nii.gz  norm/007_03_cvr.nii.gz  norm/007_03_motors_vs_sham.nii.gz \
    007  04  norm/007_04_r04_RSFA.nii.gz  norm/007_04_cvr.nii.gz  norm/007_04_motors_vs_sham.nii.gz \
    007  05  norm/007_05_r04_RSFA.nii.gz  norm/007_05_cvr.nii.gz  norm/007_05_motors_vs_sham.nii.gz \
    007  06  norm/007_06_r04_RSFA.nii.gz  norm/007_06_cvr.nii.gz  norm/007_06_motors_vs_sham.nii.gz \
    007  07  norm/007_07_r04_RSFA.nii.gz  norm/007_07_cvr.nii.gz  norm/007_07_motors_vs_sham.nii.gz \
    007  08  norm/007_08_r04_RSFA.nii.gz  norm/007_08_cvr.nii.gz  norm/007_08_motors_vs_sham.nii.gz \
    007  09  norm/007_09_r04_RSFA.nii.gz  norm/007_09_cvr.nii.gz  norm/007_09_motors_vs_sham.nii.gz \
    007  10  norm/007_10_r04_RSFA.nii.gz  norm/007_10_cvr.nii.gz  norm/007_10_motors_vs_sham.nii.gz \
    008  01  norm/008_01_r04_RSFA.nii.gz  norm/008_01_cvr.nii.gz  norm/008_01_motors_vs_sham.nii.gz \
    008  02  norm/008_02_r04_RSFA.nii.gz  norm/008_02_cvr.nii.gz  norm/008_02_motors_vs_sham.nii.gz \
    008  03  norm/008_03_r04_RSFA.nii.gz  norm/008_03_cvr.nii.gz  norm/008_03_motors_vs_sham.nii.gz \
    008  04  norm/008_04_r04_RSFA.nii.gz  norm/008_04_cvr.nii.gz  norm/008_04_motors_vs_sham.nii.gz \
    008  05  norm/008_05_r04_RSFA.nii.gz  norm/008_05_cvr.nii.gz  norm/008_05_motors_vs_sham.nii.gz \
    008  06  norm/008_06_r04_RSFA.nii.gz  norm/008_06_cvr.nii.gz  norm/008_06_motors_vs_sham.nii.gz \
    008  07  norm/008_07_r04_RSFA.nii.gz  norm/008_07_cvr.nii.gz  norm/008_07_motors_vs_sham.nii.gz \
    008  08  norm/008_08_r04_RSFA.nii.gz  norm/008_08_cvr.nii.gz  norm/008_08_motors_vs_sham.nii.gz \
    008  09  norm/008_09_r04_RSFA.nii.gz  norm/008_09_cvr.nii.gz  norm/008_09_motors_vs_sham.nii.gz \
    008  10  norm/008_10_r04_RSFA.nii.gz  norm/008_10_cvr.nii.gz  norm/008_10_motors_vs_sham.nii.gz \
    009  01  norm/009_01_r04_RSFA.nii.gz  norm/009_01_cvr.nii.gz  norm/009_01_motors_vs_sham.nii.gz \
    009  02  norm/009_02_r04_RSFA.nii.gz  norm/009_02_cvr.nii.gz  norm/009_02_motors_vs_sham.nii.gz \
    009  03  norm/009_03_r04_RSFA.nii.gz  norm/009_03_cvr.nii.gz  norm/009_03_motors_vs_sham.nii.gz \
    009  04  norm/009_04_r04_RSFA.nii.gz  norm/009_04_cvr.nii.gz  norm/009_04_motors_vs_sham.nii.gz \
    009  05  norm/009_05_r04_RSFA.nii.gz  norm/009_05_cvr.nii.gz  norm/009_05_motors_vs_sham.nii.gz \
    009  06  norm/009_06_r04_RSFA.nii.gz  norm/009_06_cvr.nii.gz  norm/009_06_motors_vs_sham.nii.gz \
    009  07  norm/009_07_r04_RSFA.nii.gz  norm/009_07_cvr.nii.gz  norm/009_07_motors_vs_sham.nii.gz \
    009  08  norm/009_08_r04_RSFA.nii.gz  norm/009_08_cvr.nii.gz  norm/009_08_motors_vs_sham.nii.gz \
    009  09  norm/009_09_r04_RSFA.nii.gz  norm/009_09_cvr.nii.gz  norm/009_09_motors_vs_sham.nii.gz \
    009  10  norm/009_10_r04_RSFA.nii.gz  norm/009_10_cvr.nii.gz  norm/009_10_motors_vs_sham.nii.gz



rm -rf ${tmp}

cd ${cwd}