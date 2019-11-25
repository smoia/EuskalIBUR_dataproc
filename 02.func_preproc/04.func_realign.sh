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

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
func=${func_in%_*}

nTR=$(fslval ${func_in} dim4)
TR=$(fslval ${func_in} pixdim4)
let nTR--

## 01. Motion Realignment

# 01.1. Apply McFlirt
echo "Applying McFlirt in ${func}"

if [[ ! -d "${func}_split" ]]; then mkdir ${func}_split; fi
if [[ ! -d "${func}_merge" ]]; then mkdir ${func}_merge; fi
fslsplit ${func_in} ${func}_split/vol_ -t

for i in $( seq -f %04g 0 ${nTR} )
do
	echo "Flirting volume ${i} of ${nTR} in ${func}"
	flirt -in ${func}_split/vol_${i} -ref ${mref} -applyxfm \
	-init ../reg/${fmat}_mcf.mat/MAT_${i} -out ${func}_merge/vol_${i}
done

rm -r ${func}_split

echo "Merging ${func}"
fslmerge -tr ${func}_mcf ${func}_merge/vol_* ${TR}

# 01.2. Apply mask
echo "BETting ${func}"
fslmaths ${func}_mcf -mas ${mask} ${func}_bet

rm -r ${func}_merge

if [[ "${moio}" != "none" ]]
then
	echo "Computing DVARS and FD for ${func}"
	# 01.3. Compute various metrics
	fsl_motion_outliers -i ${func}_mcf -o ${func}_mcf_dvars_confounds -s ${func}_dvars_post.par -p ${func}_dvars_post --dvars --nomoco
	fsl_motion_outliers -i ${func}_cr -o ${func}_mcf_dvars_confounds -s ${func}_dvars_pre.par -p ${func}_dvars_pre --dvars --nomoco
	fsl_motion_outliers -i ${func}_cr -o ${func}_mcf_fd_confounds -s ${func}_fd.par -p ${func}_fd --fd
fi

cd ${cwd}