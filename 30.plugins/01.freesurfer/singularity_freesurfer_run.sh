#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M v.ferrer@bcbl.eu

if [[ -z "${SUBJ}" ]]; then
  if [[ ! -z "$1" ]]; then
     SUBJ=$1
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $1"
     exit
  fi
fi
module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date
PRJDIR=/bcbl/home/public/PJMASK_2
wdir=/bcbl/home/home_n-z/vferrer
SUBJECTS_DIR=${PRJDIR}/tmp_freesurfer
# SUBJ=sub-001
cd ${wdir}

singularity exec -e --no-home -B ${PRJDIR} -B ${wdir} ${wdir}/euskalibur_freesurfer_container/freesurfer_img.simg\
 ${wdir}/EuskalIBUR_dataproc/30.plugins/01.freesurfer/01_freesurfer.sh $PRJDIR $SUBJ $SUBJECTS_DIR