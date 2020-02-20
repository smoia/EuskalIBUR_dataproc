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

anat=$7
adir=$8

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
	/scripts/02.func_preproc/01.func_correct.sh ${func} ${fmap}
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
	/scripts/02.func_preproc/01.func_correct.sh ${sbrf} ${fdir}
fi

echo "************************************"
echo "*** Func pepolar breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/02.func_pepolar.sh ${sbrf}_cr ${fdir} none ${brev} ${bfor}

echo "************************************"
echo "*** Func spacecomp breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/11.sbref_spacecomp.sh ${sbrf}_tpp ${anat} ${fdir} ${adir} 

# Copy this sbref to reg folder
imcp ${fdir}/${sbrf}_tpp ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
imcp ${fdir}/${sbrf}_brain ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain
imcp ${fdir}/${sbrf}_brain_mask ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain_mask
imcp ${fdir}/${anat}2${sbrf}.nii.gz ${wdr}/sub-${sub}/ses-${ses}/reg/${anat}2sub-${sub}_sbref

mkdir ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_topup
cp -R ${fdir}/${sbrf}_topup/* ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_topup/.
cp ${fdir}/${anat}2${sbrf}_fsl.mat ${wdr}/sub-${sub}/ses-${ses}/reg/${anat}2sub-${sub}_sbref_fsl.mat
cp ${fdir}/${anat}2${sbrf}0GenericAffine.mat ${wdr}/sub-${sub}/ses-${ses}/reg/${anat}2sub-${sub}_sbref0GenericAffine.mat