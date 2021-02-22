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
ses=$2
task=${3}
wdr=${4:-/data}
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr} || exit
flpr=sub-${sub}_ses-${ses}_task-${task}

tmp=${tmp}/tmp.${flpr}_08rtgim
replace_and mkdir ${tmp}

if_missing_do mkdir Mennes_replication
if_missing_do mkdir Mennes_replication/GLM
if_missing_do mkdir Mennes_replication/GLM/${task} Mennes_replication/GLM/${task}/output

cd Mennes_replication/GLM

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
func=${fdir}/00.${flpr}_optcom_bold_native_preprocessed
fout=${wdr}/Mennes_replication/GLM/${task}/output
ospr=${fdir}/onsets/${flpr}

# SPC func
fslmaths ${func} -Tmean ${tmp}/${flpr}_mean
fslmaths ${func} -sub ${tmp}/${flpr}_mean -div ${tmp}/${flpr}_mean ${tmp}/${flpr}_spc


# Create Names for output files
# =============================
cbuck=${fout}/${sub}_${ses}_task-${task}_spm-cbuck
rbuck=${fout}/${sub}_${ses}_task-${task}_spm
fitts=${fout}/${sub}_${ses}_task-${task}_spm-fitts
mat=${fout}/${sub}_${ses}_task-${task}_spm-mat

# Run 3dDeconvolve on a trial-by-trial basis with the stim_IM option
echo "Compute statistical maps of activation per individual event ocurrence"
echo "====================================================================="

run3dDeconvolve="3dDeconvolve -overwrite -input ${tmp}/${flpr}_spc.nii.gz -mask ${mask}.nii.gz"
run3dDeconvolve="${run3dDeconvolve} -polort 4"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_demean.par motderiv"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_deriv1.par motdemean"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_concat_bold_bet_rej_ort.1D meica_rej_ort"
run3dDeconvolve="${run3dDeconvolve} -bucket ${cbuck}-IM.nii.gz"
run3dDeconvolve="${run3dDeconvolve} -x1D ${mat}-IM.1D -xjpeg ${mat}-IM.jpg -x1D_stop"

case ${task} in
	motor )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 5"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 finger_left -stim_times_IM 1 ${ospr}_finger_left_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 finger_right -stim_times_IM 2 ${ospr}_finger_right_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 toe_left -stim_times_IM 3 ${ospr}_toe_left_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 toe_right -stim_times_IM 4 ${ospr}_toe_right_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 tongue -stim_times_IM 5 ${ospr}_tongue_onset.1D 'SPMG1(15)'"
	;;
	simon )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 8"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 congruent -stim_times_IM 1 ${ospr}_left_congruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 incongruent -stim_times_IM 2 ${ospr}_right_congruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 left -stim_times_IM 3 ${ospr}_left_incongruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 right -stim_times_IM 4 ${ospr}_right_incongruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 wrong_lc -stim_times_IM 5 ${ospr}_left_congruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 wrong_rc -stim_times_IM 6 ${ospr}_right_congruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 wrong_li -stim_times_IM 7 ${ospr}_left_incongruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 wrong_ri -stim_times_IM 8 ${ospr}_right_incongruent_incorrect_onset.1D dmUBLOCK"
		# Since the incorrect onsets might be absent, tell 3dDeconvolve it's ok.
		run3dDeconvolve="${run3dDeconvolve} -allzero_OK"
	;;
	pinel )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 10"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 acalc -stim_times_IM 1 ${ospr}_acalc_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 amot_left -stim_times_IM 2 ${ospr}_amot_left_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 amot_right -stim_times_IM 3 ${ospr}_amot_right_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 asent -stim_times_IM 4 ${ospr}_asent_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 chbh -stim_times_IM 5 ${ospr}_chbh_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 chbv -stim_times_IM 6 ${ospr}_chbv_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 vcalc -stim_times_IM 7 ${ospr}_vcalc_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 vmot_left -stim_times_IM 8 ${ospr}_vmot_left_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 9 vmot_right -stim_times_IM 9 ${ospr}_vmot_right_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 10 vsent -stim_times_IM 10 ${ospr}_vsent_onset.1D 'SPMG1(0)'"
	;;
	* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
esac


# Run 3dDeconvolve
eval ${run3dDeconvolve}
3dREMLfit -overwrite -matrix ${mat}-IM.1D	\
		  -mask	 ${mask}.nii.gz \
		  -input ${tmp}/${flpr}_spc.nii.gz	\
		  -tout -verb -GOFORIT				  \
		  -Rfitts ${fitts}-IM.nii.gz		 \
		  -Rbuck  ${rbuck}-IM.nii.gz

rm -rf ${tmp}

cd ${cwd}