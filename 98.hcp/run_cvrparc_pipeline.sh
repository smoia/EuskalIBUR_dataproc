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

size=$1
rep=$2

for n in $(seq 2 120)
do
	echo "----------------------"
	echo "$rep $n $size"
	parc=rand-${n}p-${size}s-${rep}r

	singularity exec -e --no-home \
				-B /bcbl/home/public/PJMASK_2/preproc:/data \
				-B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc:/scripts \
				-B /export/home/smoia/scratch:/tmp \
				euskalibur.sif 00.pipelines/pipeline_cvr_parcels.sh ${parc}
done