#!/usr/bin/env bash

######### Preparing folders for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2
dirname=${3:-preprocessed}
overwrite=${4:-overwrite}

flpr=sub-${sub}_ses-${ses}

anat1=${5:-${flpr}_acq-uni_T1w}
anat2=${6:-${flpr}_T2w}

std=${7:-MNI152_T1_1mm_brain_resamp_2.5mm}

wdr=${8:-/data}
sdr=${9:-/scripts}
tmp=${10:-/tmp}

# shellcheck source=EuskalIBUR_dataproc/utils.sh
source ${sdr}/utils.sh
######################################
######### Script starts here #########
######################################

# saving the current wokdir
cwd=$(pwd)

echo "************************************"
echo "*** Preparing folders"
echo "************************************"
echo "************************************"

cd ${wdr} || exit

if [[ "${overwrite}" == "overwrite" ]]
then
	replace_and mkdir ${dirname}
else
	if_missing_do mkdir ${dirname}
fi

if_missing_do mkdir ${dirname}/sub-${sub}
if_missing_do mkdir ${dirname}/sub-${sub}/ses-${ses}
if_missing_do mkdir ${tmp}/${dirname}_${flpr}


for fld in func_preproc fmap_preproc reg anat_preproc
do
	if_missing_do mkdir ${dirname}/sub-${sub}/ses-${ses}/${fld}
done

imcp sub-${sub}/ses-${ses}/func/*.nii.gz ${tmp}/${dirname}_${flpr}/.
if_missing_do copy sub-${sub}/ses-${ses}/anat/${anat1}.nii.gz ${tmp}/${dirname}_${flpr}/${anat1}.nii.gz
if_missing_do copy sub-${sub}/ses-${ses}/anat/${anat2}.nii.gz ${tmp}/${dirname}_${flpr}/${anat2}.nii.gz
imcp sub-${sub}/ses-${ses}/fmap/*.nii.gz ${tmp}/${dirname}_${flpr}/.
if_missing_do copy ${sdr}/90.template/${std}.nii.gz ${dirname}/sub-${sub}/ses-${ses}/reg/${std}.nii.gz

cd ${cwd}
