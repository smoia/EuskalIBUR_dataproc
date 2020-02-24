#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.5.2

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date

wdir=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${wdir}

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts -B /bcbl/home/public/PJMASK_2/tmp:/tmp euskalibur.sif ./tmp.batch_dvars.sh $1 $2


singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts -B /bcbl/home/public/PJMASK_2/tmp:/tmp euskalibur.sif 04.first_level_analysis/03.compute_motion_outliers.sh $1 $2