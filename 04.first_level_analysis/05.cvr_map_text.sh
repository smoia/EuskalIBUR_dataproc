#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

sub=$1
ses=$2
parc=$3
pval=${4:-0.00175}  # it's 0.1 corrected for 60 repetitions

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${5:-/data}
scriptdir=${6:-/scripts}
tmp=${7:-/tmp}

flpr=sub-${sub}_ses-${ses}
shiftdir=${flpr}_GM_optcom_avg_regr_shift
step=12
lag=9
freq=40
tr=1.5

# Number of voxel in atlas
anvx=${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}
# alabel=${scriptdir}/90.template/${parc}.nii.gz

### Main ###

cwd=$( pwd )

let poslag=lag*freq
let miter=poslag*2

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
func=${fdir}/00.${flpr}_task-breathhold_optcom_bold_parc-${parc}

matdir=${flpr}_${parc}_mat

cd ${wdr}/CVR || exit

if [ -d ${tmp}/tmp.${flpr}_${parc}_05cmt_res ]
then
	rm -rf ${tmp}/tmp.${flpr}_${parc}_05cmt_res
fi
# creating folder
mkdir ${tmp}/tmp.${flpr}_${parc}_05cmt_res

# creating matdir if nonexistent

if [ -d ${matdir} ]
then
	rm -rf ${matdir}
fi
mkdir ${matdir}

for i in $( seq -f %04g 0 ${step} ${miter} )
do
	if [ -e ${shiftdir}/shift_${i}.1D ] && [ -e ${func}.1D ]
	then
		# Simply add motparams and polorts ( = N )
		# Prepare matrix
		3dDeconvolve -force_TR ${tr} -input ${func}.1D\' -jobs 6 \
					 -float -num_stimts 1 \
					 -polort 4 \
					 -ortvec ${flpr}_motpar_demean.par motdemean \
					 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
					 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
					 -x1D ${matdir}/mat.1D \
					 -xjpeg ${matdir}/mat.jpg \
					 -rout -tout \
					 -bucket ${tmp}/tmp.${flpr}_${parc}_05cmt_res/stats_${i}.1D

	fi
done

# Extract degrees of freedom

mat=${matdir}/mat.1D

nreg=$( cat ${mat} | grep ni_type )
nreg=${nreg#*\"}
nreg=${nreg%\**}
ndim=$( cat ${mat} | grep ni_dimen )
ndim=${ndim#*\"}
ndim=${ndim%\"*}
let ndof=ndim-nreg-1

# Get equivalent in t value
tscore=$( cdf -p2t fitt ${pval} ${ndof} )
tscore=${tscore##* }

alabel=0
case ${parc} in
	flowterritories ) alabel=9 ;;
	aparc ) exit ;;
	schaefer-* ) alabel=${parc#*-} ;;
	rand-* ) alabel=${parc#*-}; alabel=${alabel%p*} ;;
esac

python3 ${scriptdir}/20.python_scripts/compute_cvr_text.py \
		${tmp}/tmp.${flpr}_${parc}_05cmt_res ${step} ${lag} \
		${freq} ${tscore} ${flpr}_${parc} ${wdr}/CVR/${flpr}_${parc}_map_cvr \
		${anvx} ${alabel}

rm -rf ${tmp}/tmp.${flpr}_${parc}_05cmt_*

cd ${cwd}
