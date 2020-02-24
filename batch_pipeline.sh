#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.5.2

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

# for sub in $(seq -f %03g 1 10)
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		qsub -q long.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/${sub}_${ses}_pipe -e ${wdr}/../LogFiles/${sub}_${ses}_pipe ${wdr}/run_subject_pipeline.sh ${sub} ${ses}
# 	done
# done

# for ftype in meica-aggr meica-orth meica-cons meica-mvar optcom echo-2
# do
# 	qsub -q long.q -N "${ftype}_EuskalIBUR" -o ${wdr}/../LogFiles/${sub}_${ses}_pipe -e ${wdr}/../LogFiles/${sub}_${ses}_pipe ${wdr}/run_cvr_reliability.sh ${ftype}
# done

for sub in 001 002 003 004 007 008 009
do
	for ses in $(seq -f %02g 1 10)
	do
		qsub -q short.q -N "s_${sub}_${ses}_EuskalIBUR" -o ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe -e ${wdr}/../LogFiles/s_${sub}_${ses}_EuskalIBUR_pipe ${wdr}/run_cvr_dvars.sh ${sub} ${ses}
	done
done
