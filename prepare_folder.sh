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

# shellcheck source=./utils.sh
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

if_missing_do mkdir ${dirname}/sub-${sub} ${dirname}/sub-${sub}/ses-${ses}


for fld in func_preproc fmap_preproc reg anat_preproc
do
	if_missing_do mkdir ${dirname}/sub-${sub}/ses-${ses}/${fld}
done

cd ${cwd}
