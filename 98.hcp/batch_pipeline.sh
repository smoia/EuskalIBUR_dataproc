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
# # # Run surrogates
# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe
# 		qsub -q long.q -N "surr_${sub}_${ses}_EuskalIBUR" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe \
# 		${wdr}/98.hcp/run_surrogates.sh ${sub} ${ses}
# 		joblist=surr_${sub}_${ses}_EuskalIBUR,
# 	done
# done

# joblist=${joblist::-1}

for n in $(seq -f %03g 0 11 1000)
do
	rm ${wdr}/../LogFiles/${n}_surr_icc_pipe
	qsub -q short.q -N "icc_surr_${n}_EuskalIBUR" \
	-o ${wdr}/../LogFiles/${n}_surr_icc_pipe \
	-e ${wdr}/../LogFiles/${n}_surr_icc_pipe \
	${wdr}/98.hcp/run_surrogate_icc_split.sh cvr ${n} 10
	# -hold_jid "${joblist}" \
done