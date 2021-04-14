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

# for sub in 002 003 004 007 008 009
# do
# 	rm ${wdr}/../LogFiles/${sub}_01_preproc_pipe
# 	qsub -q long.q -N "s_${sub}_01_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/${sub}_01_preproc_pipe \
# 	-e ${wdr}/../LogFiles/${sub}_01_preproc_pipe \
# 	${wdr}/98.hcp/run_full_preproc_pipeline.sh ${sub} 01
# 	joblist=${joblist}s_${sub}_01_EuskalIBUR,
# done

# joblist=${joblist::-1}

# for sub in 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 2 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe
# 		qsub -q long.q -N "s_${sub}_${ses}_EuskalIBUR" \
# 		-hold_jid "${joblist}" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_preproc_pipe \
# 		${wdr}/98.hcp/run_full_preproc_pipeline.sh ${sub} ${ses}
# 	done
# 	# joblist=""
# 	# for ses in $(seq -f %02g 1 10)
# 	# do
# 	# 	joblist=${joblist}s_${sub}_${ses}_EuskalIBUR,
# 	# done
# 	# joblist=${joblist::-1}
# done

# # Run fALFF
# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $(seq -f %02g 1 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_falff_pipe
# 		qsub -q short.q -N "falff_${sub}_${ses}_EuskalIBUR" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_falff_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_falff_pipe \
# 		${wdr}/98.hcp/run_falff.sh ${sub} ${ses}
# 		# -hold_jid "${joblist}" \
# 	done
# done

# # Run GLMs
# for sub in 001 002 003 004 007 008 009
# do
# 	# for ses in $(seq -f %02g 1 10)
# 	# do
# 	# 	rm ${wdr}/../LogFiles/${sub}_${ses}_glm_pipe
# 	# 	qsub -q long.q -N "glm_${sub}_${ses}_EuskalIBUR" \
# 	# 	-o ${wdr}/../LogFiles/${sub}_${ses}_glm_pipe \
# 	# 	-e ${wdr}/../LogFiles/${sub}_${ses}_glm_pipe \
# 	# 	${wdr}/98.hcp/run_ses_glm.sh ${sub} ${ses}
# 	# 	# -hold_jid "${joblist}" \
# 	# done

# 	rm ${wdr}/../LogFiles/${sub}_allses_glm_pipe
# 	qsub -q long.q -N "glm_${sub}_allses_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/${sub}_allses_glm_pipe \
# 	-e ${wdr}/../LogFiles/${sub}_allses_glm_pipe \
# 	${wdr}/98.hcp/run_Mennes.sh ${sub}
# 	# -hold_jid "${joblist}" \
# done

# # Run LME for CVR
# for task in simon #motor simon
# do
# 	qsub -q long.q -N "lme_${task}_cvr_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/lme_${task}_cvr_pipe \
# 	-e ${wdr}/../LogFiles/lme_${task}_cvr_pipe \
# 	${wdr}/98.hcp/run_lme_glm_cvr.sh ${task}
# done

# Run LME for questionnaire
qsub -q long.q -N "lme_cvr_questionnaire_EuskalIBUR" \
-o ${wdr}/../LogFiles/lme_cvr_questionnaire_pipe \
-e ${wdr}/../LogFiles/lme_cvr_questionnaire_pipe \
${wdr}/98.hcp/run_lme_cvr_questionnaire.sh
