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

# for task in simon motor pinel
# do
# 	for sub in 001 002 003 004 007 008 009
# 	do
# 		for ses in 01 allses # $( seq -f %02g 2 10) # $( seq -f %02g 1 10; echo "allses" )
# 		do
# 			rm ${wdr}/../LogFiles/${sub}_${ses}_icc_pipe
# 			qsub -q short.q -N "icc_${sub}_${ses}_EuskalIBUR" \
# 			-o ${wdr}/../LogFiles/${sub}_${ses}_icc_pipe \
# 			-e ${wdr}/../LogFiles/${sub}_${ses}_icc_pipe \
# 			${wdr}/98.hcp/run_glm_norm.sh ${task} ${sub} ${ses}
# 		done
# 	done
# done

# for brick in ../preproc/Dataset_QC/norm/001_allses_*_Coef.nii.gz
# do
# 	brick=${brick#*allses_}
# 	brick=${brick%_Coef*}
# 	rm ${wdr}/../LogFiles/${brick}_icc_pipe
# 	qsub -q short.q -N "icc_${brick}_EuskalIBUR" \
# 	-o ${wdr}/../LogFiles/${brick}_icc_pipe \
# 	-e ${wdr}/../LogFiles/${brick}_icc_pipe \
# 	${wdr}/98.hcp/run_glm_icc.sh ${brick%_Coef*}
# done

# # Run falff
# joblist=""
# for sub in 001 002 003 004 007 008 009
# do
# 	for ses in $( seq -f %02g 1 10)
# 	do
# 		rm ${wdr}/../LogFiles/${sub}_${ses}_rsfc_pipe
# 		qsub -q veryshort.q -N "rsfc_${sub}_${ses}_EuskalIBUR" \
# 		-o ${wdr}/../LogFiles/${sub}_${ses}_rsfc_pipe \
# 		-e ${wdr}/../LogFiles/${sub}_${ses}_rsfc_pipe \
# 		${wdr}/98.hcp/run_falff.sh ${sub} ${ses}
# 		joblist=${joblist}rsfc_${sub}_${ses}_EuskalIBUR,
# 	done
# done

# joblist=${joblist::-1}

# Run LME for CVR, RSFC, and GLM
qsub -q long.q -N "lme_nd_falff_cvr_EuskalIBUR" \
-o ${wdr}/../LogFiles/lme_nd_falff_cvr_pipe \
-e ${wdr}/../LogFiles/lme_nd_falff_cvr_pipe \
${wdr}/98.hcp/run_lme_nd_glm_cvr.sh falff
# -hold_jid "${joblist}" \

for task in motor simon
do
	qsub -q long.q -N "lme_nd_${task}_cvr_EuskalIBUR" \
	-o ${wdr}/../LogFiles/lme_nd_${task}_cvr_pipe \
	-e ${wdr}/../LogFiles/lme_nd_${task}_cvr_pipe \
	${wdr}/98.hcp/run_lme_nd_glm_cvr.sh ${task}
	# -hold_jid "lme_falff_cvr_EuskalIBUR" \
done

# # Run LME for questionnaire
# qsub -q long.q -N "lme_cvr_questionnaire_EuskalIBUR" \
# -o ${wdr}/../LogFiles/lme_cvr_questionnaire_pipe \
# -e ${wdr}/../LogFiles/lme_cvr_questionnaire_pipe \
# ${wdr}/98.hcp/run_lme_cvr_questionnaire.sh
