#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M v.ferrer@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date
PRJDIR=/bcbl/home/home_n-z/public/PJMASK_2
wdir=/bcbl/home/home_n-z/vferrer
SUBJECTS_DIR=${PRJDIR}/tmp_freesurfer
SUBJ=sub-001
cd ${wdir}

singularity exec -e --no-home -B /bcbl/home/home_n-z/public/PJMASK_2/preproc -B ${wdir} ${wdir}/euskalibur_freesurfer_container/freesurfer_img.simg\
 ${wdir}/EuskalIBUR_dataproc/30.plugins/01.freesurfer/01_freesurfer.sh $PRJDIR $SUBJ $SUBJECTS_DIR