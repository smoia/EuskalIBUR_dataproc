#!/bin/bash
#$ -cwd
#$ -o out.txt
#$ -e err.txt
#$ -m be
#$ -M v.ferrer@bcbl.eu
#$ -N reconall
#$ -S /bin/bash
if [[ -z "${PRJDIR}" ]]; then
  if [[ ! -z "$1" ]]; then
     PRJDIR=$1
  else
     echo "You need to input PROJECT DIRECTORY (PRJDIR) as ENVIRONMENT VARIABLE or $1"
     exit
  fi
fi
if [[ -z "${SUBJ}" ]]; then
  if [[ ! -z "$2" ]]; then
     SUBJ=$2
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $2"
     exit
  fi
fi

BIDS_DIR=$PRJDIR/preproc # Bids database directory 
SUBJECTS_DIR=${BIDS_DIR}/tmp_FREESURFER # Output directory for FREESURFER

echo "Script that runs Freesurfer anatomical preprocessing"
echo "Command: recon-all"
echo "execution started: `date`"

if [[ -d $SUBJECTS_DIR ]]; then
	if [[ -d $SUBJECTS_DIR/$SUBJ ]]; then
		echo -e "\033[0;31m++ WARNING: $SUBJECTS_DIR/$SUBJ already exist. Freesurfer does not execute if the subject has been processed previously. If you want to run a clean reconall please delete this directory  \e[39m"
		exit
	fi	
else
	mkdir -p $SUBJECTS_DIR
fi

if [[ -d $SUBJECTS_DIR ]]; then
	echo ""
else
	mkdir -p $SUBJECTS_DIR
fi 

echo  -e "\e[34m +++ =======================================================================\e[39m"
echo  -e "\e[34m +++ ---------------> FREESURFER ANATOMICAL PREPROCESSING <-----------------\e[39m"
echo  -e "\e[34m +++ =======================================================================\e[39m"
T1=$BIDS_DIR/${SUBJ}/ses-01/anat_preproc/${SUBJ}_ses-01_acq-uni_T1w_brain.nii.gz # find T1 sub-001_ses-01_acq-uni_T1w_brain.nii.gz
T2=$BIDS_DIR/${SUBJ}/ses-01/anat/${SUBJ}_ses-01_T2w.nii.gz # sub-001_ses-01_T2w2sub-001_ses-01_acq-uni_T1w_fsl
option="T2"


echo  -e "\e[32m ++ INFO: RECON-ALL EXECUTED WITH ALIGNED $option ...\e[39m"
orders=" -autorecon1 -noskullstrip -s $SUBJ -i $T1 -$option $T2 -sd $SUBJECTS_DIR"
recon-all $orders
cp $SUBJECTS_DIR/$SUBJ/mri/T1.mgz $SUBJECTS_DIR/$SUBJ/mri/brainmask.auto.mgz
cp $SUBJECTS_DIR/$SUBJ/mri/brainmask.auto.mgz $SUBJECTS_DIR/$SUBJ/mri/brainmask.mgz
recon-all -autorecon2 -autorecon3 -T2pial -sd $SUBJECTS_DIR -s $SUBJ -hippocampal-subfields-T1 -brainstem-structures
echo  -e "\e[34m +++ =======================================================================\e[39m"
echo  -e "\e[34m +++ ------------> CONVERTING FREESURFER OUTPUT TO NII and GII <------------\e[39m"
echo  -e "\e[34m +++ =======================================================================\e[39m"

mri_convert -i ${SUBJECTS_DIR}/sub-001/mri/aparc.a2009s+aseg.mgz -o ${BIDS_DIR}/${SUBJ}/ses-01/anat_preproc/${SUBJ}_aparc.a2009s+aseg.nii.gz
echo  -e "\e[34m +++ ====================================================================================\e[39m"
echo  -e "\e[34m +++ ------------> END OF SCRIPT: FREESURFER PREPROCESSING FINISHED   <------------------\e[39m"
echo  -e "\e[34m +++ ====================================================================================\e[39m"