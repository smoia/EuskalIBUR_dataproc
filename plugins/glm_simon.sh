#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -q short.q

module load afni/latest

SBJ=$1
SES=$2

PRJDIR=/export/home/eurunuela/public/PJMASK_2/preproc/${SBJ}/${SES}/func_preproc

cd ${PRJDIR}

echo $(pwd)

INPUT_FILE=${SBJ}_${SES}_SPC_preprocessed.nii.gz
MASK=${SBJ}_${SES}_mask.nii.gz

# Create Names for output files
# =============================
CBUCK_FILE=${SBJ}_${SES}_task-simon_spm-cbuck.nii.gz
RBUCK_FILE=${SBJ}_${SES}_task-simon_spm.nii.gz
FITTS_FILE=${SBJ}_${SES}_task-simon_spm-fitts.nii.gz
ERRTS_FILE=${SBJ}_${SES}_task-simon_spm-errts.nii.gz
X1D_FILE=${SBJ}_${SES}_task-simon_spm-xmat.1D

# Run 3dDeconvolve on a trial-by-trial basis with the stim_IM option
# ==================================================================
echo -e "\033[0;32m++ STEP (1) Compute statistical maps of activation per individual event ocurrence\033[0m"
echo -e "\033[0;32m++ ==============================================================================\033[0m"
3dDeconvolve -overwrite -input ${INPUT_FILE}    \
             -mask             ${MASK}          \
             -polort A -jobs 12                  \
             -num_stimts 20                      \
             -stim_label 1 CONGRUENT -stim_times 1 onsets/${SBJ}_${SES}_task-simon_left_congruent_correct_onset.1D "dmUBLOCK"                    \
             -stim_label 2 INCONGRUENT -stim_times 2 onsets/${SBJ}_${SES}_task-simon_right_congruent_correct_onset.1D "dmUBLOCK"                 \
             -stim_label 3 LEFT -stim_times 3 onsets/${SBJ}_${SES}_task-simon_left_incongruent_correct_onset.1D "dmUBLOCK"                       \
             -stim_label 4 RIGHT -stim_times 4 onsets/${SBJ}_${SES}_task-simon_right_incongruent_correct_onset.1D "dmUBLOCK"                     \
             -stim_label 5 CORRECT -stim_times 5 onsets/${SBJ}_${SES}_task-simon_left_congruent_wrong_onset.1D "dmUBLOCK"                        \
             -stim_label 6 WRONG -stim_times 6 onsets/${SBJ}_${SES}_task-simon_right_congruent_wrong_onset.1D "dmUBLOCK"                         \
             -stim_label 7 WRONG -stim_times 7 onsets/${SBJ}_${SES}_task-simon_left_incongruent_wrong_onset.1D "dmUBLOCK"                        \
             -stim_label 8 WRONG -stim_times 8 onsets/${SBJ}_${SES}_task-simon_right_incongruent_wrong_onset.1D "dmUBLOCK"                       \
             -stim_base  9 -stim_file 9 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[0]' -stim_label 9  roll                 \
             -stim_base  10 -stim_file 10 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[1]' -stim_label 10  pitch             \
             -stim_base  11 -stim_file 11 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[2]' -stim_label 11  yaw               \
             -stim_base  12 -stim_file 12 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[3]' -stim_label 12  dS                \
             -stim_base  13 -stim_file 13 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[4]' -stim_label 13 dL                 \
             -stim_base  14 -stim_file 14 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[5]' -stim_label 14 dP                 \
             -stim_base  15 -stim_file 15 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[0]' -stim_label 15 roll_d1            \
             -stim_base  16 -stim_file 16 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[1]' -stim_label 16 pitch_d1           \
             -stim_base  17 -stim_file 17 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[2]' -stim_label 17 yaw_d1             \
             -stim_base  18 -stim_file 18 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[3]' -stim_label 18 dS_d1              \
             -stim_base  19 -stim_file 19 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[4]' -stim_label 19 dL_d1              \
             -stim_base  20 -stim_file 20 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[5]' -stim_label 20 dP_d1              \
             -tout                                                                                                  \
             -bucket ${CBUCK_FILE} \
             -x1D ${X1D_FILE}                                                                                       \
             -x1D_stop

# export OMP_NUM_THREADS=32
3dREMLfit -overwrite -matrix ${X1D_FILE}  \
          -mask              ${MASK}              \
          -input ${INPUT_FILE}                    \
          -tout -verb                             \
          -Rfitts ${FITTS_FILE}                   \
          -Rbuck  ${RBUCK_FILE}                   \
          -Rerrts ${ERRTS_FILE}


CBUCK_FILE=${SBJ}_${SES}_task-simon_spm-IM-cbuck.nii.gz
RBUCK_FILE=${SBJ}_${SES}_task-simon_spm-IM.nii.gz
FITTS_FILE=${SBJ}_${SES}_task-simon_spm-fitts-IM.nii.gz
X1D_FILE=${SBJ}_${SES}_task-simon_spm-IM-xmat.1D

# Run 3dDeconvolve on a trial-by-trial basis with the stim_IM option
# ==================================================================
echo -e "\033[0;32m++ STEP (1) Compute statistical maps of activation per individual event ocurrence\033[0m"
echo -e "\033[0;32m++ ==============================================================================\033[0m"
3dDeconvolve -overwrite -input ${INPUT_FILE}                                                                        \
             -mask             ${MASK}                                                                       \
             -polort A -jobs 12                                                                             \
             -num_stimts 20                      \
             -stim_label 1 CONGRUENT -stim_times_IM 1 onsets/${SBJ}_${SES}_task-simon_left_congruent_correct_onset.1D "dmUBLOCK"                    \
             -stim_label 2 INCONGRUENT -stim_times_IM 2 onsets/${SBJ}_${SES}_task-simon_right_congruent_correct_onset.1D "dmUBLOCK"                 \
             -stim_label 3 LEFT -stim_times_IM 3 onsets/${SBJ}_${SES}_task-simon_left_incongruent_correct_onset.1D "dmUBLOCK"                       \
             -stim_label 4 RIGHT -stim_times_IM 4 onsets/${SBJ}_${SES}_task-simon_right_incongruent_correct_onset.1D "dmUBLOCK"                     \
             -stim_label 5 CORRECT -stim_times_IM 5 onsets/${SBJ}_${SES}_task-simon_left_congruent_wrong_onset.1D "dmUBLOCK"                        \
             -stim_label 6 WRONG -stim_times_IM 6 onsets/${SBJ}_${SES}_task-simon_right_congruent_wrong_onset.1D "dmUBLOCK"                         \
             -stim_label 7 WRONG -stim_times_IM 7 onsets/${SBJ}_${SES}_task-simon_left_incongruent_wrong_onset.1D "dmUBLOCK"                        \
             -stim_label 8 WRONG -stim_times_IM 8 onsets/${SBJ}_${SES}_task-simon_right_incongruent_wrong_onset.1D "dmUBLOCK"                       \
             -stim_base  9 -stim_file 9 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[0]' -stim_label 9  roll                 \
             -stim_base  10 -stim_file 10 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[1]' -stim_label 10  pitch             \
             -stim_base  11 -stim_file 11 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[2]' -stim_label 11  yaw               \
             -stim_base  12 -stim_file 12 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[3]' -stim_label 12  dS                \
             -stim_base  13 -stim_file 13 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[4]' -stim_label 13 dL                 \
             -stim_base  14 -stim_file 14 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_demean.par'[5]' -stim_label 14 dP                 \
             -stim_base  15 -stim_file 15 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[0]' -stim_label 15 roll_d1            \
             -stim_base  16 -stim_file 16 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[1]' -stim_label 16 pitch_d1           \
             -stim_base  17 -stim_file 17 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[2]' -stim_label 17 yaw_d1             \
             -stim_base  18 -stim_file 18 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[3]' -stim_label 18 dS_d1              \
             -stim_base  19 -stim_file 19 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[4]' -stim_label 19 dL_d1              \
             -stim_base  20 -stim_file 20 ${SBJ}_${SES}_task-simon_echo-1_bold_mcf_deriv1.par'[5]' -stim_label 20 dP_d1              \
             -tout                                                                                                  \
             -x1D ${X1D_FILE}                                                                                       \
             -bucket ${CBUCK_FILE}                                                                                 \
             -xjpeg ${SBJ}_${SES}_task-simon_IM-Design-Matrix.jpg                                                              \
             -x1D_stop


3dREMLfit -overwrite -matrix ${X1D_FILE}  \
          -mask              ${MASK}              \
          -input ${INPUT_FILE}                    \
          -tout -verb                             \
          -Rfitts ${FITTS_FILE}                   \
          -Rbuck  ${RBUCK_FILE}