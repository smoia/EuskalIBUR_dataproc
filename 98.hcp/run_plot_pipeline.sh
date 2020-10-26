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

# singularity exec -e --no-home \
# 			-B /bcbl/home/public/PJMASK_2/preproc:/data \
# 			-B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts \
# 			-B /export/home/smoia/scratch:/tmp euskalibur.sif \
# 			00.pipelines/pipeline_plot.sh

# Run subject cvr value plots
singularity exec -e --no-home \
			-B /bcbl/home/public/PJMASK_2/preproc:/data \
			-B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts \
			-B /export/home/smoia/scratch:/tmp euskalibur.sif \
			10.visualisation/04.plot_cvr_vals.sh $1

