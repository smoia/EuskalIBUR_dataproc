#!/usr/bin/env bash

######### Sbref preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2

fdir=$3
fmap=$3

anat=$5
adir=$6

sdr=${7:-/scripts}
tmp=${8:-/tmp}

flpr=sub-${sub}_ses-${ses}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"

# shellcheck source=EuskalIBUR_dataproc/utils.sh
source ${sdr}/utils.sh
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
	${sdr}/02.func_preproc/01.func_correct.sh ${tmp}/${func} ${fmap}
done

mv ${tmp}/${flpr}_acq-breathhold_dir-PA_epi_cr.nii.gz ${fmap}/${flpr}_acq-breathhold_dir-PA_epi_cr.nii.gz
mv ${tmp}/${flpr}_acq-breathhold_dir-AP_epi_cr.nii.gz ${fmap}/${flpr}_acq-breathhold_dir-AP_epi_cr.nii.gz

bfor=${fmap}/${flpr}_acq-breathhold_dir-PA_epi_cr
brev=${fmap}/${flpr}_acq-breathhold_dir-AP_epi_cr

echo "************************************"
echo "*** Func correct breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

sbrf=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref
if [[ ! -e ${sbrf}_cr.nii.gz ]]
then
	${sdr}/02.func_preproc/01.func_correct.sh ${tmp}/${sbrf} ${fdir}
fi

echo "************************************"
echo "*** Func pepolar breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

${sdr}/02.func_preproc/02.func_pepolar.sh ${tmp}/${sbrf}_cr ${fdir} none \
										  ${brev} ${bfor} ${tmp} ${sdr}

echo "************************************"
echo "*** Func spacecomp breathhold SBREF echo 1"
echo "************************************"
echo "************************************"

${sdr}/02.func_preproc/11.sbref_spacecomp.sh ${tmp}/${sbrf}_tpp ${anat} ${fdir} ${adir} ${tmp}

# Copy this sbref to reg folder
if_missing_do move ${tmp}/${sbrf}_tpp.nii.gz ${fdir}/../reg/sub-${sub}_sbref.nii.gz
if_missing_do move ${tmp}/${sbrf}_brain.nii.gz ${fdir}/../reg/sub-${sub}_sbref_brain.nii.gz
if_missing_do move ${tmp}/${sbrf}_brain_mask.nii.gz ${fdir}/../reg/sub-${sub}_sbref_brain_mask.nii.gz
if_missing_do move ${tmp}/${anat}2${sbrf}.nii.gz ${fdir}/../reg/${anat}2sub-${sub}_sbref.nii.gz

if_missing_do mkdir ${fdir}/../reg/sub-${sub}_sbref_topup
cp -R ${tmp}/${sbrf}_topup/* ${fdir}/../reg/sub-${sub}_sbref_topup/.
if_missing_do move ${tmp}/${anat}2${sbrf}_fsl.mat ${fdir}/../reg/${anat}2sub-${sub}_sbref_fsl.mat
if_missing_do move ${tmp}/${anat}2${sbrf}0GenericAffine.mat ${fdir}/../reg/${anat}2sub-${sub}_sbref0GenericAffine.mat