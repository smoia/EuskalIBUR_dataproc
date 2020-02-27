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

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc:/data -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts -B /bcbl/home/public/PJMASK_2/tmp:/tmp euskalibur.sif 00.pipelines/pipeline_sim_cvr_motdenoise.sh $1 $2
