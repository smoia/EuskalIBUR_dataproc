#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu


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
		rm ${wdr}/../LogFiles/${sub}_${ses}_check
		qsub -q veryshort.q -N "s_${sub}_${ses}_check" \
		-o ${wdr}/../LogFiles/${sub}_${ses}_check \
		-e ${wdr}/../LogFiles/${sub}_${ses}_check \
		${wdr}/98.hcp/run_check.sh ${sub} ${ses} /bcbl/home/public/PJMASK_2
	done
done
