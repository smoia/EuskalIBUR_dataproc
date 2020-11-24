#!/usr/bin/env bash

######### FULL BREATHHOLD PREPROC for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########

####
# TODO:
# - add a "nobet flag"
# - improve flags
# - Censors!
# - visual output

sub=$1
ses=$2
wdr=${3:-/data}
overwrite=${4:-overwrite}

run_anat=${5:-true}
run_sbref=${6:-true}

flpr=sub-${sub}_ses-${ses}

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc
stdp=/scripts/90.template

vdsc=10
std=MNI152_T1_1mm_brain
mmres=2.5
#fwhm=6

TEs="10.6 28.69 46.78 64.87 82.96"
nTE=5

# -> Answer to the Ultimate Question of Life, the Universe, and Everything.
# slice order file (full path to)
siot=none
# siot=${wdr}/sliceorder.txt

# Despiking
dspk=none

first_ses_path=${wdr}/sub-${sub}/ses-01

uni_sbref=${first_ses_path}/reg/sub-${sub}_sbref
uni_adir=${first_ses_path}/anat_preproc


####################

######################################
######### Script starts here #########
######################################

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${flpr}_log" ]]; then rm ${wdr}/log/${flpr}_log; fi

echo "************************************" >> ${wdr}/log/${flpr}_log

exec 3>&1 4>&2

exec 1>${wdr}/log/${flpr}_log 2>&1

date
echo "************************************"


echo "************************************"
echo "***    Preproc ${flpr}    ***"
echo "************************************"
echo "************************************"
echo ""
echo ""

cd ${wdr}/sub-${sub}/ses-${ses} || exit

imcp func/*motor*.nii.gz func_preproc/.
imcp fmap/*motor*.nii.gz fmap_preproc/.
imcp ${stdp}/${std}.nii.gz reg/.

cd /scripts

######################################
#########    Task preproc    #########
######################################

/scripts/00.pipelines/tensor_preproc.sh ${sub} ${ses} ${wdr} ${flpr} \
						${fdir} ${vdsc} "${TEs}" \
						${nTE} ${siot} ${dspk}

date
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"