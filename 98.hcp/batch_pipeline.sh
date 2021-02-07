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

# # Run full preproc
# joblist=""

# for ses in $(seq -f %02g 1 10)
# do
# 	rm ${wdr}/../LogFiles/001_${ses}_preproc_pipe
# 	qsub -q long.q -N "s_001_${ses}_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/001_${ses}_preproc_pipe \
# 	-e ${wdr}/../LogFiles/001_${ses}_preproc_pipe \
# 	${wdr}/98.hcp/run_full_preproc_pipeline.sh 001 ${ses}
# 	joblist=${joblist}s_001_${ses}_EuskalIBUR,
# done

# joblist=${joblist::-1}

# for sub in 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe
# 		qsub -q long.q -N "s_${sub}_${ses}_EuskalIBUR" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe \
# 		${wdr}/98.hcp/run_full_preproc_pipeline.sh ${sub} ${ses}
# 		# -hold_jid "${joblist}" \
# 	done
# 	joblist=""
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		joblist=${joblist}s_${sub}_${ses}_EuskalIBUR,
# 	done
# 	joblist=${joblist::-1}
# done




# joblist=""
# # Run surrogates
# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe
# 		qsub -q long.q -N "surr_${sub}_${ses}_EuskalIBUR" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_surr_pipe \
# 		${wdr}/98.hcp/run_surrogates.sh ${sub} ${ses}
# 		joblist=${joblist}surr_${sub}_${ses}_EuskalIBUR,
# 	done
# done

# joblist=${joblist::-1}

# for map in cvr lag
# do
# 	rm ${wdr}/../LogFiles/${map}_surr_pipe
# 	qsub -q long.q -N "surr_${map}_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/${map}_surr_pipe \
# 	-e ${wdr}/../LogFiles/${map}_surr_pipe \
# 	${wdr}/98.hcp/run_surrogate_icc.sh ${map}
# done
# 	# -hold_jid "${joblist}" \


rm ${wdr}/../LogFiles/simple_icc_t_pipe
qsub -q long.q -N "simple_icc_t_EuskalIBUR" \
-o ${wdr}/../LogFiles/simple_icc_t_pipe \
-e ${wdr}/../LogFiles/simple_icc_t_pipe \
${wdr}/98.hcp/run_cvr_reliability.sh optcom
