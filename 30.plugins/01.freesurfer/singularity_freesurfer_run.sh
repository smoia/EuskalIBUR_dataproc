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
wdir=/bcbl/home/vferrer
SUBJECTS_DIR=${PRJDIR}/tmp_freesurfer
SUBJ=sub-001
cd ${wdir}

singularity exec -e --no-home -B /bcbl/home/public/PJMASK_2/preproc -B ${wdir} freesurfer_img.simg\
${wdir}/EuskalIBUR_dataproc/30.plugins/01.freesurfer/01_freesurfer.sh $PRJDIR $SUBJ $SUBJECTS_DIR