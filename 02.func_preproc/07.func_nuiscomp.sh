#!/usr/bin/env bash

######### FUNCTIONAL 04 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# files
func_in=$1
fmat=$2
aseg=$3  # If "none", it won't run average tissue
anat=$4  # If "none", it won't run average tissue
mref=$5
# folders
fdir=$6
adir=$7  # If "none", it won't run average tissue
# action
dprj=${8:-yes}
# thresholds
mthr=${9:-0.3}
othr=${10:-0.05}
polort=${11:-4}
den_motreg=${12:-yes}
den_detrend=${13:-yes}
den_meica=${14:-yes}
den_tissues=${15:-yes}

## Temp folder
tmp=${16:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

#!# Maybe this can go in a separate file
if [[ -e "${adir}/${aseg}_seg_eroded.nii.gz" ]] && [[ "${den_tissues}" == "yes" ]]
then
	if [[ ! -e "${adir}/${aseg}_seg2mref.nii.gz" || ! -e "${adir}/${aseg}_GM_native.nii.gz" ]]
	then
		echo "Coregistering segmentations to ${func}"
		antsApplyTransforms -d 3 -i ${adir}/${aseg}_seg_eroded.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${aseg}_seg2mref.nii.gz -n MultiLabel \
		-t ../reg/${anat}2${mref##*/}0GenericAffine.mat \
		-t [../reg/${anat}2${aseg}0GenericAffine.mat,1]
		antsApplyTransforms -d 3 -i ${adir}/${aseg}_GM_dilated.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${aseg}_GM_native.nii.gz -n MultiLabel \
		-t ../reg/${anat}2${mref##*/}0GenericAffine.mat \
		-t [../reg/${anat}2${aseg}0GenericAffine.mat,1]
	fi
	echo "Extracting average WM and CSF in ${func}"
	3dDetrend -polort ${polort} -prefix ${tmp}/${func}_dtd.nii.gz ${tmp}/${func_in}.nii.gz -overwrite
	fslmeants -i ${tmp}/${func}_dtd.nii.gz -o ${func}_avg_tissue.1D --label=${adir}/${aseg}_seg2mref.nii.gz
fi

## 04. Nuisance computation
# 04.1. Preparing censoring of fd > b & c > d in AFNI format
echo "Preparing censoring"
1deval -a ${fmat}_fd.par -b=${mthr} -c ${func}_outcount.1D -d=${othr} -expr 'isnegative(a-b)*isnegative(c-d)' > ${func}_censors.1D

# 04.2. Create matrix
echo "Preparing nuisance matrix"

run3dDeconvolve="3dDeconvolve -input ${tmp}/${func_in}.nii.gz -float \
-censor ${func}_censors.1D \
-x1D ${func}_nuisreg_censored_mat.1D -xjpeg ${func}_nuisreg_mat.jpg \
-x1D_uncensored ${func}_nuisreg_uncensored_mat.1D \
-x1D_stop"


if [[ "${den_detrend}" == "yes" ]]
then
	echo "Consider trends"
	run3dDeconvolve="${run3dDeconvolve} -polort ${polort}"
else
	echo "Skip trends"
fi

if [[ "${den_motreg}" == "yes" ]]
then
	echo "Consider motion parameters"
	run3dDeconvolve="${run3dDeconvolve} -ortvec ${fmat}_mcf_demean.par motdemean \
 -ortvec ${fmat}_mcf_deriv1.par motderiv1"
else
	echo "Skip motion parameters"
fi

if [ -e "${fmat}_rej_ort.1D" ] && [[ "${den_meica}" == "yes" ]]
then
	echo "Consider meica"
	run3dDeconvolve="${run3dDeconvolve} -ortvec ${fmat}_rej_ort.1D meica"
else
	echo "Skip meica"
fi

if [ -e "${func}_avg_tissue.1D" ] && [[ "${den_tissues}" == "yes" ]]
then
	echo "Consider average tissues"
	run3dDeconvolve="${run3dDeconvolve} -num_stimts  2 \
 -stim_file 1 ${func}_avg_tissue.1D'[0]' -stim_base 1 -stim_label 1 CSF \
 -stim_file 2 ${func}_avg_tissue.1D'[2]' -stim_base 2 -stim_label 2 WM"
	# -cenmode ZERO \
else
	echo "Skip detrend"
fi

# Report the 3dDeconvolve call

echo "######################################################"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "# Running 3d Deconvolve with the following parameters:"
echo "   + Denoise motion regressors:         ${den_motreg}"
echo "   + Denoise legendre polynomials:      ${den_detrend}"
echo "   + Denoise meica rejected components: ${den_meica}"
echo "   + Denoise average tissues signal:    ${den_tissues}"
echo ""
echo "# Generating the command:"
echo ""
echo "${run3dDeconvolve}"
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "######################################################"

${run3dDeconvolve}
## 06. Nuisance

if [[ "${dprj}" == "yes" ]]
then
	echo "Actually applying nuisance"
	fslmaths ${tmp}/${func_in} -Tmean ${tmp}/${func}_avg
	3dTproject -polort 0 -input ${tmp}/${func_in}.nii.gz  -mask ${mref}_brain_mask.nii.gz \
	-ort ${func}_nuisreg_uncensored_mat.1D -prefix ${tmp}/${func}_prj.nii.gz \
	-overwrite
	fslmaths ${tmp}/${func}_prj -add ${tmp}/${func}_avg ${tmp}/${func}_den.nii.gz
fi

cd ${cwd}
