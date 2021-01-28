#!/usr/bin/env bash

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

if [[ ! -d "Mennes_replication" ]]; then mkdir Mennes_replication; fi

if [[ ! -d "Mennes_replication/GLM" ]]
then
	mkdir Mennes_replication/GLM Mennes_replication/GLM/${task} Mennes_replication/GLM/${task}/output
fi

cd Mennes_replication/GLM

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}_task-${task}
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
func=${fdir}/00.${flpr}_optcom_bold_native_preprocessed
fout=${wdr}/Mennes_replication/GLM/${task}/output
ospr=${fdir}/onsets/${flpr}

# Create Names for output files
# =============================
cbuck=${fout}/${sub}_${ses}_task-${task}_spm-cbuck
rbuck=${fout}/${sub}_${ses}_task-${task}_spm
fitts=${fout}/${sub}_${ses}_task-${task}_spm-fitts
ertts=${fout}/${sub}_${ses}_task-${task}_spm-errts
mat=${fout}/${sub}_${ses}_task-${task}_spm-mat

# Prepare 3dDeconvolve on the full run
echo "Compute statistical maps of activation per individual event ocurrence"
echo "=============================================================================="
run3dDeconvolve="3dDeconvolve -overwrite -input ${func}.nii.gz -mask ${mask}.nii.gz "
run3dDeconvolve="${run3dDeconvolve} -polort 4 "

case ${task} in
	motor )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 5 "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 finger_left -stim_times 1 ${ospr}_finger_left_onset.1D 'SPMG1(15)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 finger_right -stim_times 2 ${ospr}_finger_right_onset.1D 'SPMG1(15)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 toe_left -stim_times 3 ${ospr}_toe_left_onset.1D 'SPMG1(15)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 toe_right -stim_times 4 ${ospr}_toe_right_onset.1D 'SPMG1(15)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 tongue -stim_times 5 ${ospr}_tongue_onset.1D 'SPMG1(15)' "
	;;
	simon )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 8 "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 congruent -stim_times 1 ${ospr}_left_congruent_correct_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 incongruent -stim_times 2 ${ospr}_right_congruent_correct_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 left -stim_times 3 ${ospr}_left_incongruent_correct_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 right -stim_times 4 ${ospr}_right_incongruent_correct_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 wrong_lc -stim_times 5 ${ospr}_left_congruent_wrong_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 wrong_rc -stim_times 6 ${ospr}_right_congruent_wrong_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 wrong_li -stim_times 7 ${ospr}_left_incongruent_wrong_onset.1D 'dmUBLOCK' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 wrong_ri -stim_times 8 ${ospr}_right_incongruent_wrong_onset.1D 'dmUBLOCK' "
	;;
	pinel )
		run3dDeconvolve="${run3dDeconvolve} -num_stimts 10 "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 acalc -stim_times 1 ${ospr}_acalc_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 amot_left -stim_times 2 ${ospr}_amot_left_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 amot_right -stim_times 3 ${ospr}_amot_right_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 asent -stim_times 4 ${ospr}_asent_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 chbh -stim_times 5 ${ospr}_chbh_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 chbv -stim_times 6 ${ospr}_chbv_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 vcalc -stim_times 7 ${ospr}_vcalc_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 vmot_left -stim_times 8 ${ospr}_vmot_left_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 9 vmot_right -stim_times 9 ${ospr}_vmot_right_onset.1D 'SPMG1(0)' "
		run3dDeconvolve="${run3dDeconvolve} -stim_label 10 vsent -stim_times 10 ${ospr}_vsent_onset.1D 'SPMG1(0)' "
	;;
	* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
esac

run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_demean.par "
run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_deriv1.par "
run3dDeconvolve="${run3dDeconvolve} -bucket ${cbuck}.nii.gz "
run3dDeconvolve="${run3dDeconvolve} -x1D ${mat}.1D "
run3dDeconvolve="${run3dDeconvolve} -x1D_stop"

# Run 3dDeconvolve
${run3dDeconvolve}

3dREMLfit -overwrite -matrix ${mat}.1D \
		  -mask ${mask}.nii.gz         \
		  -input ${func}.nii.gz        \
		  -tout -verb                  \
		  -Rfitts ${fitts}.nii.gz      \
		  -Rbuck  ${rbuck}.nii.gz      \
		  -Rerrts ${ertts}.nii.gz

# # Run 3dDeconvolve on a trial-by-trial basis with the stim_IM option
# echo "Compute statistical maps of activation per individual event ocurrence"
# echo "=============================================================================="

# run3dDeconvolve="3dDeconvolve -overwrite -input ${func}.nii.gz -mask ${mask}.nii.gz "
# run3dDeconvolve="${run3dDeconvolve} -polort 4 "


# case ${task} in
# 	motor )
# 		run3dDeconvolve="${run3dDeconvolve} -num_stimts 5 "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 finger_left -stim_times_IM 1 ${ospr}_finger_left_onset.1D 'SPMG1(15)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 finger_right -stim_times_IM 2 ${ospr}_finger_right_onset.1D 'SPMG1(15)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 toe_left -stim_times_IM 3 ${ospr}_toe_left_onset.1D 'SPMG1(15)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 toe_right -stim_times_IM 4 ${ospr}_toe_right_onset.1D 'SPMG1(15)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 tongue -stim_times_IM 5 ${ospr}_tongue_onset.1D 'SPMG1(15)' "
# 	;;
# 	simon )
# 		run3dDeconvolve="${run3dDeconvolve} -num_stimts 8 "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 congruent -stim_times_IM 1 ${ospr}_left_congruent_correct_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 incongruent -stim_times_IM 2 ${ospr}_right_congruent_correct_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 left -stim_times_IM 3 ${ospr}_left_incongruent_correct_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 right -stim_times_IM 4 ${ospr}_right_incongruent_correct_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 wrong_lc -stim_times_IM 5 ${ospr}_left_congruent_wrong_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 wrong_rc -stim_times_IM 6 ${ospr}_right_congruent_wrong_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 wrong_li -stim_times_IM 7 ${ospr}_left_incongruent_wrong_onset.1D 'dmUBLOCK' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 wrong_ri -stim_times_IM 8 ${ospr}_right_incongruent_wrong_onset.1D 'dmUBLOCK' "
# 	;;
# 	pinel )
# 		run3dDeconvolve="${run3dDeconvolve} -num_stimts 10 "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 1 acalc -stim_times_IM 1 ${ospr}_acalc_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 2 amot_left -stim_times_IM 2 ${ospr}_amot_left_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 3 amot_right -stim_times_IM 3 ${ospr}_amot_right_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 4 asent -stim_times_IM 4 ${ospr}_asent_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 5 chbh -stim_times_IM 5 ${ospr}_chbh_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 6 chbv -stim_times_IM 6 ${ospr}_chbv_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 7 vcalc -stim_times_IM 7 ${ospr}_vcalc_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 8 vmot_left -stim_times_IM 8 ${ospr}_vmot_left_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 9 vmot_right -stim_times_IM 9 ${ospr}_vmot_right_onset.1D 'SPMG1(0)' "
# 		run3dDeconvolve="${run3dDeconvolve} -stim_label 10 vsent -stim_times_IM 10 ${ospr}_vsent_onset.1D 'SPMG1(0)' "
# 	;;
# 	* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
# esac

# run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_demean.par "
# run3dDeconvolve="${run3dDeconvolve} -ortvec ${fdir}/${flpr}_echo-1_bold_mcf_deriv1.par "
# run3dDeconvolve="${run3dDeconvolve} -bucket ${cbuck}-IM.nii.gz "
# run3dDeconvolve="${run3dDeconvolve} -x1D ${mat}-IM.1D "
# run3dDeconvolve="${run3dDeconvolve} -x1D_stop"

# # Run 3dDeconvolve
# ${run3dDeconvolve}
# 3dREMLfit -overwrite -matrix ${mat}.1D	\
# 		  -mask	 ${mask}.nii.gz \
# 		  -input ${func}.nii.gz	\
# 		  -tout -verb				  \
# 		  -Rfitts ${fitts}-IM.nii.gz		 \
# 		  -Rbuck  ${rbuck}-IM.nii.gz

cd ${cwd}