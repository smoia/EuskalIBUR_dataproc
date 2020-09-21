#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M v.ferrer@bcbl.eu
#$ -q long.q

if [[ -z "${PRJDIR}" ]]; then
  if [[ ! -z "$1" ]]; then
     PRJDIR=$1
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $1"
     exit
  fi
fi

if [[ -z "${wdir}" ]]; then
  if [[ ! -z "$2" ]]; then
     wdir=$2
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $2"
     exit
  fi
fi

if [[ -z "${SUBJ}" ]]; then
  if [[ ! -z "$3" ]]; then
     SUBJ=$3
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $3"
     exit
  fi
fi
module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date
# SUBJ=sub-001
cd ${wdir}

singularity exec -e --no-home -B $PRJDIR/preproc:/Data -B ${wdir}/EuskalIBUR_dataproc:/scripts ${PRJDIR}/EuskalIBUR_dataproc/euskalibur.sif\
 ${wdir}/EuskalIBUR_dataproc/30.plugins/02.atlas_fusion/mni_2_func.sh $SUBJ