#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functionals
func_in=$1
fmat=$2
mask=$3
# folders
fdir=$4
# discard
# vdsc=$5
# Motion reference file
mref=$5
# Motion Outlier Images Output
moio=${6:-none}

## Temp folder
tmp=${7:-.}

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

nTR=$(fslval ${tmp}/${func_in} dim4)
TR=$(fslval ${tmp}/${func_in} pixdim4)
let nTR--

## 01. Motion Realignment

# 01.1. Apply McFlirt
echo "Applying McFlirt in ${func}"

if [[ ! -d "${tmp}/${func}_split" ]]; then mkdir ${tmp}/${func}_split; fi
if [[ ! -d "${tmp}/${func}_merge" ]]; then mkdir ${tmp}/${func}_merge; fi
fslsplit ${tmp}/${func_in} ${tmp}/${func}_split/vol_ -t

for i in $( seq -f %04g 0 ${nTR} )
do
	echo "Flirting volume ${i} of ${nTR} in ${func}"
	flirt -in ${tmp}/${func}_split/vol_${i} -ref ${mref} -applyxfm \
	-init ../reg/${fmat}_mcf.mat/MAT_${i} -out ${tmp}/${func}_merge/vol_${i}
done

echo "Merging ${func}"
fslmerge -tr ${tmp}/${func}_mcf ${tmp}/${func}_merge/vol_* ${TR}

# 01.2. Apply mask
echo "BETting ${func}"
fslmaths ${tmp}/${func}_mcf -mas ${mask} ${tmp}/${func}_bet

if [[ "${moio}" != "none" ]]
then
	echo "Computing DVARS and FD for ${func}"
	# 01.3. Compute various metrics
	fsl_motion_outliers -i ${tmp}/${func}_mcf -o ${tmp}/${func}_mcf_dvars_confounds -s ${func}_dvars_post.par -p ${func}_dvars_post --dvars --nomoco
	fsl_motion_outliers -i ${tmp}/${func}_cr -o ${tmp}/${func}_mcf_dvars_confounds -s ${func}_dvars_pre.par -p ${func}_dvars_pre --dvars --nomoco
	fsl_motion_outliers -i ${tmp}/${func}_cr -o ${tmp}/${func}_mcf_fd_confounds -s ${func}_fd.par -p ${func}_fd --fd
fi

cd ${cwd}