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
task=${2}
wdr=${3:-/data}
tmp=${4:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)


cd ${wdr} || exit

tmp=${tmp}/tmp.${sub}_${task}_07rtgs
replace_and mkdir ${tmp}

if_missing_do mkdir Mennes_replication
if_missing_do mkdir Mennes_replication/GLM
if_missing_do mkdir Mennes_replication/GLM/${task} Mennes_replication/GLM/${task}/output

cd Mennes_replication/GLM

#Initialise regressors files
replace_and touch ${tmp}/mot_demean.par
replace_and touch ${tmp}/mot_deriv1.par
replace_and touch ${tmp}/meica_rej_ort.1D 

case ${task} in
	motor )
		replace_and touch ${tmp}/finger_left_onset
		replace_and touch ${tmp}/finger_right_onset
		replace_and touch ${tmp}/toe_left_onset
		replace_and touch ${tmp}/toe_right_onset
		replace_and touch ${tmp}/tongue_onset
		replace_and touch ${tmp}/star_onset.1D
	;;
	simon )
		replace_and touch ${tmp}/left_congruent_correct_onset
		replace_and touch ${tmp}/right_congruent_correct_onset
		replace_and touch ${tmp}/left_incongruent_correct_onset
		replace_and touch ${tmp}/right_incongruent_correct_onset.1D
	;;
	pinel )
		replace_and touch ${tmp}/acalc_onset
		replace_and touch ${tmp}/amot_left_onset
		replace_and touch ${tmp}/amot_right_onset
		replace_and touch ${tmp}/asent_onset
		replace_and touch ${tmp}/chbh_onset
		replace_and touch ${tmp}/chbv_onset
		replace_and touch ${tmp}/vcalc_onset
		replace_and touch ${tmp}/vmot_left_onset
		replace_and touch ${tmp}/vmot_right_onset
		replace_and touch ${tmp}/vsent_onset.1D
	;;
	* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
esac

# Start preparing calls to programs
run3dDeconvolve="3dDeconvolve -overwrite -input"
run3dREMLfit="3dREMLfit -overwrite -input"

# Prepare inputs
for ses in $( seq -f %02g 1 10 )
do
	fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
	sub=_${task}sub-${sub}_ses-${ses}_task-${task}
	func=${fdir}/00.${sub}_${task}_optcom_bold_native_preprocessed
	ospr=${fdir}/onsets/${sub}_${task}

	# SPC func
	fslmaths ${func} -Tmean ${tmp}/${sub}_${task}_mean
	fslmaths ${func} -sub ${tmp}/${flpr}_mean -div ${tmp}/${flpr}_mean ${tmp}/${flpr}_spc

	# Add input to 3dDeconvolve call
	run3dDeconvolve="${run3dDeconvolve} ${tmp}/${flpr}_spc.nii.gz"
	run3dREMLfit="${run3dREMLfit} ${tmp}/${flpr}_spc.nii.gz"

	# Pad noise regressors and concatenate them!
	1d_tool.py -infile ${fdir}/${flpr}_echo-1_bold_mcf_demean.par -pad_into_many_runs ${ses} 10 -write ${tmp}/${ses}_demean.par
	1d_tool.py -infile ${fdir}/${flpr}_echo-1_bold_mcf_deriv1.par -pad_into_many_runs ${ses} 10 -write ${tmp}/${ses}_deriv1.par
	1d_tool.py -infile ${fdir}/${flpr}_concat_bold_bet_rej_ort.1D -pad_into_many_runs ${ses} 10 -write ${tmp}/${ses}_rej_ort.1D
	paste -d ' ' ${tmp}/mot_demean.par ${tmp}/${ses}_demean.par > ${tmp}/mot_demean.par 
	paste -d ' ' ${tmp}/mot_deriv1.par ${tmp}/${ses}_deriv1.par > ${tmp}/mot_deriv1.par 
	paste -d ' ' ${tmp}/meica_rej_ort.1D ${tmp}/${ses}_rej_ort.1D > ${tmp}/meica_rej_ort.1D 

	# Concatenate onsets for multirun file
	case ${task} in
		motor )
			cat ${tmp}/finger_left_onset.1D ${ospr}_finger_left_onset.1D
			cat ${tmp}/finger_right_onset.1D ${ospr}_finger_right_onset.1D
			cat ${tmp}/toe_left_onset.1D ${ospr}_toe_left_onset.1D
			cat ${tmp}/toe_right_onset.1D ${ospr}_toe_right_onset.1D
			cat ${tmp}/tongue_onset.1D ${ospr}_tongue_onset.1D
			cat ${tmp}/star_onset.1D ${ospr}_star_onset.1D
		;;
		simon )
			cat ${tmp}/left_congruent_correct_onset.1D ${ospr}_left_congruent_correct_onset.1D
			cat ${tmp}/right_congruent_correct_onset.1D ${ospr}_right_congruent_correct_onset.1D
			cat ${tmp}/left_incongruent_correct_onset.1D ${ospr}_left_incongruent_correct_onset.1D
			cat ${tmp}/right_incongruent_correct_onset.1D ${ospr}_right_incongruent_correct_onset.1D
		;;
		pinel )
			cat ${tmp}/acalc_onset.1D ${ospr}_acalc_onset.1D
			cat ${tmp}/amot_left_onset.1D ${ospr}_amot_left_onset.1D
			cat ${tmp}/amot_right_onset.1D ${ospr}_amot_right_onset.1D
			cat ${tmp}/asent_onset.1D ${ospr}_asent_onset.1D
			cat ${tmp}/chbh_onset.1D ${ospr}_chbh_onset.1D
			cat ${tmp}/chbv_onset.1D ${ospr}_chbv_onset.1D
			cat ${tmp}/vcalc_onset.1D ${ospr}_vcalc_onset.1D
			cat ${tmp}/vmot_left_onset.1D ${ospr}_vmot_left_onset.1D
			cat ${tmp}/vmot_right_onset.1D ${ospr}_vmot_right_onset.1D
			cat ${tmp}/vsent_onset.1D ${ospr}_vsent_onset.1D
		;;
		* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
	esac

done

# Other variables to run GLMs
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
fout=${wdr}/Mennes_replication/GLM/${task}/output
cbuck=${fout}/${sub}_${ses}_task-${task}_spm-cbuck
rbuck=${fout}/${sub}_${ses}_task-${task}_spm
fitts=${fout}/${sub}_${ses}_task-${task}_spm-fitts
ertts=${fout}/${sub}_${ses}_task-${task}_spm-errts
mat=${fout}/${sub}_${ses}_task-${task}_spm-mat

# Prepare 3dDeconvolve on the full run
echo "Compute statistical maps of activation per subject"
echo "=================================================="
run3dDeconvolve="${run3dDeconvolve} -mask ${mask}.nii.gz"
run3dDeconvolve="${run3dDeconvolve} -polort 4"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${tmp}/mot_demean.par motderiv"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${tmp}/mot_deriv1.par motdemean"
run3dDeconvolve="${run3dDeconvolve} -ortvec ${tmp}/meica_rej_ort.1D meica_rej_ort"
run3dDeconvolve="${run3dDeconvolve} -bucket ${cbuck}-subj.nii.gz"
run3dDeconvolve="${run3dDeconvolve} -x1D ${mat}-subj.1D -xjpeg ${mat}-subj.jpg -x1D_stop"
run3dDeconvolve="${run3dDeconvolve} -x1D_stop"

case ${task} in
	motor )
		# Motor has five "actions" and a star fixation equivalent to a sham
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 6"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 finger_left -stim_times 1 ${tmp}/finger_left_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 finger_right -stim_times 2 ${tmp}/finger_right_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 toe_left -stim_times 3 ${tmp}/toe_left_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 toe_right -stim_times 4 ${tmp}/toe_right_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 tongue -stim_times 5 ${tmp}/tongue_onset.1D 'SPMG1(15)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 sham -stim_times 6 ${tmp}/star_onset.1D 'SPMG1(15)'"
		# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
		run3dDeconvolve="${run3dDeconvolve} -gltsym 'SYM: +finger_left +finger_right +toe_left +toe_right +tongue"
		run3dDeconvolve="${run3dDeconvolve} \\ +finger_left +finger_right +toe_left +toe_right +tongue -sham'"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 1 allmotors"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 2 allmotors_vs_sham"
	;;
	simon )
		# Simon has four conditions, congruent/incongruent and left/right
		# We can also account for good vs wrong answers
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 8"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 left_congruent -stim_times_AM1 1 ${tmp}/left_congruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 right_congruent -stim_times_AM1 2 ${tmp}/right_congruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 left_incongruent -stim_times_AM1 3 ${tmp}/left_incongruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 right_incongruent -stim_times_AM1 4 ${tmp}/right_incongruent_correct_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 wrong_lc -stim_times_AM1 5 ${tmp}/left_congruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 wrong_rc -stim_times_AM1 6 ${tmp}/right_congruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 wrong_li -stim_times_AM1 7 ${tmp}/left_incongruent_incorrect_onset.1D dmUBLOCK"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 wrong_ri -stim_times_AM1 8 ${tmp}/right_incongruent_incorrect_onset.1D dmUBLOCK"
		# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
		# See Mennes et al. 2010 or 2011 for details.
		run3dDeconvolve="${run3dDeconvolve} -gltsym 'SYM: +left_congruent +right_congruent"
		run3dDeconvolve="${run3dDeconvolve} \\ +left_incongruent +right_incongruent"
		run3dDeconvolve="${run3dDeconvolve} \\ +left_congruent +right_congruent -left_incongruent -right_incongruent"
		run3dDeconvolve="${run3dDeconvolve} \\ +left_congruent +right_congruent +left_incongruent +right_incongruent'"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 1 all_congruent"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 2 all_incongruent"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 3 congruent_vs_incongruent"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 4 congruent_and_incongruent"
		# Since the incorrect onsets might be absent, tell 3dDeconvolve it's ok.
		run3dDeconvolve="${run3dDeconvolve} -allzero_OK"
	;;
	pinel )
		# Pinel has ten possible conditions (see Pinel 2007)
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 10"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 acalc -stim_times 1 ${tmp}/acalc_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 amot_left -stim_times 2 ${tmp}/amot_left_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 amot_right -stim_times 3 ${tmp}/amot_right_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 asent -stim_times 4 ${tmp}/asent_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 chbh -stim_times 5 ${tmp}/chbh_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 chbv -stim_times 6 ${tmp}/chbv_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 vcalc -stim_times 7 ${tmp}/vcalc_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 vmot_left -stim_times 8 ${tmp}/vmot_left_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 9 vmot_right -stim_times 9 ${tmp}/vmot_right_onset.1D 'SPMG1(0)'"
		run3dDeconvolve="${run3dDeconvolve} -stim_label 10 vsent -stim_times 10 ${tmp}/vsent_onset.1D 'SPMG1(0)'"
		# Pinel models 8 contrasts: right vs left hand, vertical vs horizontal checkers, auditory stims, visual stims, 
		# auditory calc vs auditory noncalc, visual calc vs visual noncalc, auditory vs visual, visual vs checkerboards.
		run3dDeconvolve="${run3dDeconvolve} -gltsym 'SYM: +amot_right +vmot_right -amot_left -vmot_left"
		run3dDeconvolve="${run3dDeconvolve} \\ +chbv -chbh"
		run3dDeconvolve="${run3dDeconvolve} \\ +acalc +amot_left +amot_right +asent"
		run3dDeconvolve="${run3dDeconvolve} \\ +vcalc +vmot_left +vmot_right +vsent"
		run3dDeconvolve="${run3dDeconvolve} \\ +acalc -amot_left -amot_right -asent"
		run3dDeconvolve="${run3dDeconvolve} \\ +vcalc -vmot_left -vmot_right -vsent"
		run3dDeconvolve="${run3dDeconvolve} \\ +acalc +amot_left +amot_right +asent -vcalc -vmot_left -vmot_right -vsent"
		run3dDeconvolve="${run3dDeconvolve} \\ +vcalc +vmot_left +vmot_right +vsent -chbv -chbh'"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 1 right_vs_left"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 2 vertical_vs_horizontal_cb"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 3 all_auditory"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 4 all_visual"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 5 auditory_calc_vs_noncalc"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 6 visual_calc_vs_noncalc"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 7 auditory_vs_visual"
		run3dDeconvolve="${run3dDeconvolve} -glt_label 8 visual_vs_cb"
	;;
	* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
esac

# Run 3dDeconvolve
echo "${run3dDeconvolve}"
eval ${run3dDeconvolve}

run3dREMLfit="${run3dREMLfit} -matrix ${mat}-subj.1D"
run3dREMLfit="${run3dREMLfit} -mask ${mask}.nii.gz"
run3dREMLfit="${run3dREMLfit} -tout -verb -GOFORIT"
run3dREMLfit="${run3dREMLfit} -Rfitts ${fitts}-subj.nii.gz"
run3dREMLfit="${run3dREMLfit} -Rbuck  ${rbuck}-subj.nii.gz"
run3dREMLfit="${run3dREMLfit} -Rerrts ${ertts}-subj.nii.gz"

# Run 3dREMLfit
echo "${run3dREMLfit}"
eval ${run3dREMLfit}

rm -rf ${tmp}

cd ${cwd}