#!/bin/bash
#$ -cwd
#$ -o out.txt
#$ -e err.txt
#$ -m be
#$ -M v.ferrer@bcbl.eu
#$ -N mni2func
#$ -S /bin/bash
if [[ -z "${SUBJ}" ]]; then
  if [[ ! -z "$1" ]]; then
     SUBJ=$1
  else
     echo "You need to input SUBJECT (SUBJ) as ENVIRONMENT VARIABLE or $1"
     exit
  fi
fi

FS_aparc=/data/${SUBJ}/ses-01/atlas/${SUBJ}_aparc.a2009s+aseg.nii.gz
tmp_dir=/tmp

if [[ -d $tmp_dir ]]; then
	echo ""
else
	mkdir -p $tmp_dir
fi
tmp_dir=/data/tmp_fuse/${SUBJ}
if [[ -d $tmp_dir ]]; then
	echo ""
else
	mkdir -p ${tmp_dir}
fi 

for atlastype in network vascular
do
	case ${atlastype} in
		network ) atlas=Schaefer2018_100Parcels_7Networks_order_FSLMNI152_1mm.nii.gz
				  out=${SUBJ}_schaefer-100 ;;
		vascular ) atlas=ATTbasedFlowTerritories.nii.gz
				   out=${SUBJ}_flowterritories ;;
	esac

	# transform atlases from MNI to func space
	antsApplyTransforms -d 3 -i /scripts/90.template/${atlas} \
						-r /data/${SUBJ}/ses-01/reg/${SUBJ}_sbref.nii.gz -o /data/${SUBJ}/ses-01/atlas/${out}.nii.gz \
						-n Multilabel -t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_sbref0GenericAffine.mat] \
						-t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_ses-01_acq-uni_T1w0GenericAffine.mat,1] \
						-t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_acq-uni_T1w2std0GenericAffine.mat ,1] \
						-t /data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_acq-uni_T1w2std1InverseWarp.nii.gz -v

done

# Transform aparc from anat to func space
antsApplyTransforms -d 3 -i ${FS_aparc} \
					-r /data/${SUBJ}/ses-01/reg/${SUBJ}_sbref.nii.gz -o /data/${SUBJ}/ses-01/atlas/${SUBJ}_aparc.nii.gz \
					-n Multilabel -t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_sbref0GenericAffine.mat] \
					-t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_ses-01_acq-uni_T1w0GenericAffine.mat,1] \
					-v

# transform random parcellations
for parc in $( seq 2 120 )
do
	antsApplyTransforms -d 3 -i /scripts/90.template/rand_atlas/${parc}-parc.nii.gz \
						-r /data/${SUBJ}/ses-01/reg/${SUBJ}_sbref.nii.gz -o /data/${SUBJ}/ses-01/atlas/${SUBJ}_rand-${parc}.nii.gz \
						-n Multilabel -t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_sbref0GenericAffine.mat] \
						-t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_T2w2${SUBJ}_ses-01_acq-uni_T1w0GenericAffine.mat,1] \
						-t [/data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_acq-uni_T1w2std0GenericAffine.mat ,1] \
						-t /data/${SUBJ}/ses-01/reg/${SUBJ}_ses-01_acq-uni_T1w2std1InverseWarp.nii.gz -v
done