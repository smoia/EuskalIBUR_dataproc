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
ses=$2

wdir=/bcbl/home/public/PJMASK_2/preproc
scriptdir=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${scriptdir}

logname=falff_${sub}_${ses}_pipe

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdir}/log" ]]; then mkdir ${wdir}/log; fi
if [[ -e "${wdir}/log/${logname}" ]]; then rm ${wdir}/log/${logname}; fi

echo "************************************" >> ${wdir}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdir}/log/${logname} 2>&1

date
echo "************************************"

# # Run fALFF
# singularity exec -e --no-home \
# -B ${wdir}:/data -B ${scriptdir}:/scripts \
# -B /export/home/smoia/scratch:/tmp \
# euskalibur.sif 04.first_level_analysis/07.compute_rsfc.sh ${sub} ${ses} /data /tmp

# Run GLMs
for task in motor simon pinel
do
	singularity exec -e --no-home \
	-B ${wdir}:/data -B ${scriptdir}:/scripts \
	-B /export/home/smoia/scratch:/tmp \
	euskalibur.sif 04.first_level_analysis/08.run_task_glm.sh ${sub} ${ses} ${task} /data /tmp
done
