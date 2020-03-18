#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date

wdr=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${wdr}

if [[ ! -d ../LogFiles ]]
then
	mkdir ../LogFiles
fi

# joblist=""
# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		qsub -q long.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/${sub}_${ses}_pipe -e ${wdr}/../LogFiles/${sub}_${ses}_pipe ${wdr}/98.hcp/run_subject_pipeline.sh ${sub} ${ses}
# 		joblist=${joblist}s_${sub}_${ses}_EuskalIBUR,
# 	done
# done

# qsub -q short.q -N "s_002_07_EuskalIBUR" -o ${wdr}/../LogFiles/002_07_pipe -e ${wdr}/../LogFiles/002_07_pipe ${wdr}/98.hcp/run_subject_pipeline.sh 002 07
# joblist=${joblist}s_002_07_EuskalIBUR,

# joblist=${joblist::-1}

# qsub -q short.q -N "optcom_EuskalIBUR" -o ${wdr}/../LogFiles/${ftype}_pipe -e ${wdr}/../LogFiles/${ftype}_pipe ${wdr}/98.hcp/run_cvr_reliability.sh ${ftype}
# qsub -q short.q -hold_jid "optcom_EuskalIBUR" -N "meica-aggr_EuskalIBUR" -o ${wdr}/../LogFiles/meica-aggr_pipe -e ${wdr}/../LogFiles/meica-aggr_pipe ${wdr}/98.hcp/run_cvr_reliability.sh meica-aggr
# qsub -q short.q -hold_jid "meica-aggr_EuskalIBUR" -N "meica-orth_EuskalIBUR" -o ${wdr}/../LogFiles/meica-orth_pipe -e ${wdr}/../LogFiles/meica-orth_pipe ${wdr}/98.hcp/run_cvr_reliability.sh meica-orth
# qsub -q short.q -hold_jid "meica-orth_EuskalIBUR" -N "meica-cons_EuskalIBUR" -o ${wdr}/../LogFiles/meica-cons_pipe -e ${wdr}/../LogFiles/meica-cons_pipe ${wdr}/98.hcp/run_cvr_reliability.sh meica-cons
# qsub -q short.q -hold_jid "meica-cons_EuskalIBUR" -N "meica-mvar_EuskalIBUR" -o ${wdr}/../LogFiles/meica-mvar_pipe -e ${wdr}/../LogFiles/meica-mvar_pipe ${wdr}/98.hcp/run_cvr_reliability.sh meica-mvar
# qsub -q short.q -hold_jid "meica-mvar_EuskalIBUR" -N "echo-2_EuskalIBUR" -o ${wdr}/../LogFiles/echo-2_pipe -e ${wdr}/../LogFiles/echo-2_pipe ${wdr}/98.hcp/run_cvr_reliability.sh echo-2
# qsub -q short.q -hold_jid "echo-2_EuskalIBUR" -N "meica-aggr-twosteps_EuskalIBUR" -o ${wdr}/../LogFiles/meica-aggr-twosteps_pipe -e ${wdr}/../LogFiles/meica-aggr-twosteps_pipe ${wdr}/98.hcp/run_cvr_reliability.sh meica-aggr-twosteps
# qsub -q short.q -hold_jid "meica-aggr_EuskalIBUR-twosteps" -N "meica-orth_EuskalIBUR-twosteps" -o ${wdr}/../LogFiles/meica-orth_pipe-twosteps -e ${wdr}/../LogFiles/meica-orth_pipe-twosteps ${wdr}/98.hcp/run_cvr_reliability.sh meica-orth-twosteps
# qsub -q short.q -hold_jid "meica-orth_EuskalIBUR-twosteps" -N "meica-cons_EuskalIBUR-twosteps" -o ${wdr}/../LogFiles/meica-cons_pipe-twosteps -e ${wdr}/../LogFiles/meica-cons_pipe-twosteps ${wdr}/98.hcp/run_cvr_reliability.sh meica-cons-twosteps


# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		qsub -q veryshort.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe -e ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe ${wdr}/98.hcp/run_cvr_dvars.sh ${sub} ${ses}
# 	done
# done

qsub -q veryshort.q -N "mot_EuskalIBUR" -o ${wdr}/../LogFiles/motion_pipe -e ${wdr}/../LogFiles/motion_pipe ${wdr}/98.hcp/run_motion_plot.sh

# qsub -q short.q -N "s_010_11_prep" -o ${wdr}/../LogFiles/010_11_pipe -e ${wdr}/../LogFiles/010_11_pipe ${wdr}/tmp.preproc_10.sh
