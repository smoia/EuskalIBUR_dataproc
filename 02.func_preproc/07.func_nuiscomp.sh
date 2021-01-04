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
anat=$3  # If "none", it won't run average tissue
aref=$4  # If "none", it won't run average tissue
mref=$5
# folders
fdir=$6
adir=$7  # If "none", it won't run average tissue
# action
dprj=${8:-yes}
# thresholds
mthr=${9:-0.3}
othr=${10:-0.05}
no_motreg=${11:-no}
no_detrend=${12:-no}

## Temp folder
tmp=${13:-.}

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

#!# Maybe this can go in a separate file
if [ -e "${adir}/${anat}_seg_eroded.nii.gz" ]
then
	if [[ ! -e "${adir}/${anat}_seg_native.nii.gz" || ! -e "${adir}/${anat}_GM_native.nii.gz" ]]
	then
		echo "Coregistering segmentations to ${func}"
		antsApplyTransforms -d 3 -i ${adir}/${anat}_seg_eroded.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${anat}_seg_native.nii.gz -n MultiLabel \
		-t ../reg/${aref}2${mref}0GenericAffine.mat \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1]
		antsApplyTransforms -d 3 -i ${adir}/${anat}_GM_dilated.nii.gz -r ${mref}.nii.gz \
		-o ${adir}/${anat}_GM_native.nii.gz -n MultiLabel \
		-t ../reg/${aref}2${mref}0GenericAffine.mat \
		-t [../reg/${aref}2${anat}0GenericAffine.mat,1]
	fi
	echo "Extracting average WM and CSF in ${func}"
	3dDetrend -polort 5 -prefix ${tmp}/${func}_dtd.nii.gz ${func_in}.nii.gz -overwrite
	fslmeants -i ${tmp}/${func}_dtd.nii.gz -o ${func}_avg_tissue.1D --label=${adir}/${anat}_seg_native.nii.gz
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
				

if [[ "${no_detrend}" != "yes" ]]
then
	run3dDeconvolve="${run3dDeconvolve} -polort 5"
fi

if [[ "${no_motreg}" != "yes" ]]
then
	run3dDeconvolve="${run3dDeconvolve} -ortvec ${fmat}_mcf_demean.par motdemean \
				 						-ortvec ${fmat}_mcf_deriv1.par motderiv1"
fi

if [ -e "${fmat}_rej_ort.1D" ]
then
	run3dDeconvolve="${run3dDeconvolve} -ortvec ${fmat}_rej_ort.1D meica"
fi
if [ -e "${func}_avg_tissue.1D" ]
then
	run3dDeconvolve="${run3dDeconvolve} -num_stimts  2 \
	-stim_file 1 ${func}_avg_tissue.1D'[0]' -stim_base 1 -stim_label 1 CSF \
	-stim_file 2 ${func}_avg_tissue.1D'[2]' -stim_base 2 -stim_label 2 WM"
	# -cenmode ZERO \
fi

${run3dDeconvolve}
## 06. Nuisance

if [[ "${dprj}" != "none" ]]
then
	echo "Actually applying nuisance"
	fslmaths ${tmp}/${func_in} -Tmean ${tmp}/${func}_avg
	3dTproject -polort 0 -input ${tmp}/${func_in}.nii.gz  -mask ${mref}_brain_mask.nii.gz \
	-ort ${func}_nuisreg_uncensored_mat.1D -prefix ${tmp}/${func}_prj.nii.gz \
	-overwrite
	fslmaths ${tmp}/${func}_prj -add ${tmp}/${func}_avg ${tmp}/${func}_den.nii.gz
fi

cd ${cwd}
