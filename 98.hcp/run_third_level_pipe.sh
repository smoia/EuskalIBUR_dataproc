#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date

wdir=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${wdir}

logname = third_level_pipe

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdir}/log" ]]; then mkdir ${wdir}/log; fi
if [[ -e "${wdir}/log/${logname}" ]]; then rm ${wdir}/log/${logname}; fi

echo "************************************" >> ${wdir}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdir}/log/${logname} 2>&1

date
echo "************************************"

# singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data \
# -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts \
# -B /export/home/smoia/scratch:/tmp euskalibur.sif 06.third_level_analysis/01.cvr_post_icc_tests.sh

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data \
-B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts \
-B /export/home/smoia/scratch:/tmp euskalibur.sif 06.third_level_analysis/02.cvr_comparisons.sh
