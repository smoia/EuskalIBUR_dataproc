#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date
PRJDIR=/bcbl/home/public/PJMASK_2
wdir=/bcbl/home/vferrer/EuskalIBUR_dataproc
SUBJECTS_DIR=${PRJDIR}/tmp_freesurfer
SUBJ=sub-001
cd ${wdir}

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc -B /bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc freesurfer_img.simg\
${wdir}/01_freesurfer.sh $PRJDIR $SUBJ $SUBJECTS_DIR