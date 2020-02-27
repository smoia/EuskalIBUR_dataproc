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

for sub in 001 002 003 004 007 008 009
do
	for ses in $(seq -f %02g 1 10)
	do
		qsub -q long.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/${sub}_${ses}_pipe -e ${wdr}/../LogFiles/${sub}_${ses}_pipe ${wdr}/98.hcp/run_subject_pipeline.sh ${sub} ${ses}
	done
done

for ftype in meica-aggr meica-orth meica-cons meica-mvar optcom echo-2
do
	qsub -q veryshort.q -N "${ftype}_EuskalIBUR" -o ${wdr}/../LogFiles/${ftype}_pipe -e ${wdr}/../LogFiles/${ftype}_pipe ${wdr}/98.hcp/run_cvr_reliability.sh ${ftype}
done

# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		qsub -q veryshort.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe -e ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe ${wdr}/98.hcp/run_cvr_dvars.sh ${sub} ${ses}
# 	done
# done

qsub -q short.q -N "s_010_11_prep" -o ${wdr}/../LogFiles/010_11_pipe -e ${wdr}/../LogFiles/010_11_pipe ${wdr}/tmp.preproc_10.sh

# qsub -q veryshort.q -N "mot_EuskalIBUR" -o ${wdr}/../LogFiles/motion_pipe -e ${wdr}/../LogFiles/motion_pipe ${wdr}/98.hcp/run_motion_plot.sh

