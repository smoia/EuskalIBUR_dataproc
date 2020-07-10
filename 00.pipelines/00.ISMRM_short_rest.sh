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

flpr=sub-${sub}_ses-${ses}
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
stdp=/scripts/90.template

vdsc=10
std=MNI152_T1_1mm_brain
#fwhm=6

TEs="10.6 28.69 46.78 64.87 82.96"
nTE=5

# -> Answer to the Ultimate Question of Life, the Universe, and Everything.
# slice order file (full path to)
siot=none
# siot=${wdr}/sliceorder.txt

# Despiking
dspk=none

####################


######################################
######### Script starts here #########
######################################

cwd=$(pwd)

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

######################################
#########   Prepare folders  #########
######################################

cd ${wdr}/sub-${sub}/ses-${ses} || exit

imcp func/*rest*.nii.gz func_preproc/.
imcp fmap/*rest*.nii.gz fmap_preproc/.
imcp ${stdp}/${std}.nii.gz reg/.

cd /scripts

/scripts/00.pipelines/rest_short_preproc.sh ${sub} ${ses} 01 ${wdr} ${flpr} \
						${fdir} ${vdsc} "${TEs}" \
						${nTE} ${siot} ${dspk}

date
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"
