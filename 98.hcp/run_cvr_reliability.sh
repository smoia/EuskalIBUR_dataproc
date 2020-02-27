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

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts -B /bcbl/home/public/PJMASK_2/tmp:/tmp euskalibur.sif 05.second_level_analysis/09.cvr_reliability.sh $1
