#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date

sub=$1
task=$2

wdr=/bcbl/home/public/PJMASK_2/preproc
sdr=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${sdr}

logname=Mennes_${sub}_${task}_pipe

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${logname}" ]]; then rm ${wdr}/log/${logname}; fi

echo "************************************" >> ${wdr}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdr}/log/${logname} 2>&1

date
echo "************************************"

singularity exec -e --no-home \
-B ${wdr}:/data -B ${sdr}:/scripts \
-B /export/home/smoia/scratch:/tmp \
euskalibur.sif 05.second_level_analysis/07.run_task_glm_subjectwise.sh ${sub} ${task} /data /tmp

# echo "************************************"
# echo "************************************"
# singularity exec -e --no-home \
# -B ${wdr}:/data -B ${sdr}:/scripts \
# -B /export/home/smoia/scratch:/tmp \
# euskalibur.sif 05.second_level_analysis/06.quick_correlation_Mennes.sh ${sub} ${task} /data /tmp