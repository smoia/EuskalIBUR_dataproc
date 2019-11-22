#!/usr/bin/env bash

######### Sbref preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2
wdr=$3

flpr=$4

fdir=$5
fmap=$6

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
#########    SBRef preproc   #########
######################################

# Start funcpreproc by preparing the sbref.
for d in AP PA
do
	echo "************************************"
	echo "*** Func correct breathhold PE ${d}"
	echo "************************************"
	echo "************************************"

	func=${flpr}_acq-breathhold_dir-${d}_epi
	./02.func_preproc/01.func_correct.sh ${func} ${fmap}
done

bfor=${fmap}/${flpr}_acq-breathhold_dir-PA_epi_cr
brev=${fmap}/${flpr}_acq-breathhold_dir-AP_epi_cr

echo "************************************"
echo "*** Func correct breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

sbrf=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref
if [[ ! -e ${sbrf}_cr.nii.gz ]]
then
	./02.func_preproc/01.func_correct.sh ${sbrf} ${fdir}
fi

echo "************************************"
echo "*** Func pepolar breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

./02.func_preproc/02.func_pepolar.sh ${sbrf}_cr ${fdir} none ${brev} ${bfor}

# Copy this sbref to reg folder
imcp ${fdir}/${sbrf}_tpp ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
