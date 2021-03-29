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

# Run GLMs
for sub in 001 002 003 004 007 008 009
do
	for ses in $(seq -f %02g 1 10)
	do
		for fmap in cvr lag
		do
			rm ${wdr}/../LogFiles/${sub}_${ses}_${fmap}_avg
			qsub -q veryshort.q -N "avg_${sub}_${ses}_${fmap}_EuskalIBUR" \
			-o ${wdr}/../LogFiles/${sub}_${ses}_${fmap}_avg \
			-e ${wdr}/../LogFiles/${sub}_${ses}_${fmap}_avg \
			${wdr}/98.hcp/tmp_avg.sh ${sub} ${ses} ${fmap}
		done
	done
done