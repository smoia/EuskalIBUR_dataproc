#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2

# wdr=/media
wdr=/media

step=10
lag=9
freq=40
tr=1.5
tscore=2.6


### Main ###

cwd=$( pwd )

let poslag=lag*freq
let miter=poslag*2

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

shiftdir=${flpr}_GM_OC_avg_regr_shift

cd ${wdr}/CVR

# for vol in melodic skundu
# do
func=${flpr}_task-breathhold_echo-1_bold_RPI_bet_meica/ts_OC

3dTproject -polort 3 -input ${fdir}/${func}.nii.gz -prefix ${flpr}_pp.nii.gz -overwrite

fslmaths ${fdir}/${func} -Tmean ${flpr}_mean
fslmaths ${flpr}_pp -div ${flpr}_mean ${flpr}_SPC
fslmaths ${flpr}_SPC -Tmean -bin ${flpr}_mask
# done 

# exit
# for vol in melodic skundu
# do
if [ -d tmp.${flpr}_res ]
then
	rm -rf tmp.${flpr}_res
fi
mkdir tmp.${flpr}_res
# # mkdir tmp.${flpr}_res_reml

for i in $( seq -f %04g 0 ${step} ${miter} )
do
	if [ -e ${shiftdir}/shift_${i}.1D ]
	then
		3dDetrend -prefix - -polort 3 ${shiftdir}/shift_${i}.1D\' > ${shiftdir}/shift_${i}_pp.1D

		3dDeconvolve -input ${flpr}_SPC.nii.gz -jobs 3 \
		-float -num_stimts 1 \
		-mask ${flpr}_mask.nii.gz \
		-ortvec ${flpr}_demean.par motdemean \
		-ortvec ${flpr}_deriv1.par motderiv1 \
		-stim_file 1 ${shiftdir}/shift_${i}_pp.1D \
		-x1D ${shiftdir}/mat.1D \
		-xjpeg ${shiftdir}/mat.jpg \
		-x1D_uncensored ${shiftdir}/${i}_uncensored_mat.1D \
		-rout -tout \
		-bucket tmp.${flpr}_res/stats_${i}.nii.gz

		3dbucket -prefix tmp.${flpr}_res/${flpr}_r2_${i}.nii.gz -abuc tmp.${flpr}_res/stats_${i}.nii.gz'[0]' -overwrite
		3dbucket -prefix tmp.${flpr}_res/${flpr}_betas_${i}.nii.gz -abuc tmp.${flpr}_res/stats_${i}.nii.gz'[2]' -overwrite
		3dbucket -prefix tmp.${flpr}_res/${flpr}_tstat_${i}.nii.gz -abuc tmp.${flpr}_res/stats_${i}.nii.gz'[3]' -overwrite

		# 3dREMLfit -matrix ${shiftdir}/${i}_uncensored_mat.1D \
		# -input ${flpr}_SPC.nii.gz -nobout \
		# -mask ${flpr}_mask.nii.gz \
		# -Rbuck tmp.${flpr}_res_reml/stats_REML_${i}.nii.gz \
		# -Rfitts tmp.${flpr}_res_reml/fitts_REML_${i}.nii.gz \
		# -verb -overwrite

		# -Rvar tmp.${flpr}_res/stats_REMLvar_${i}.nii.gz \

		# 3dbucket -prefix tmp.${flpr}_res_reml/${flpr}_${i}.nii.gz -abuc tmp.${flpr}_res_reml/stats_REML_${i}.nii.gz'[1]' -overwrite
	fi
done

fslmerge -tr ${flpr}_r2_time tmp.${flpr}_res/${flpr}_r2_* ${tr}
fslmerge -tr ${flpr}_betas_time tmp.${flpr}_res/${flpr}_betas_* ${tr}
fslmerge -tr ${flpr}_tstat_time tmp.${flpr}_res/${flpr}_tstat_* ${tr}
# fslmerge -t ${flpr}_betas_time tmp.${flpr}_res/${flpr}_betas_*

fslmaths ${flpr}_r2_time -Tmaxn ${flpr}_cvr_idx
fslmaths ${flpr}_cvr_idx -mul ${step} -sub ${poslag} -mul 0.025 ${flpr}_cvr_lag

# split idx volumes in masks, add
3dcalc -a ${flpr}_cvr_idx.nii.gz -expr 'a*0' -prefix ${flpr}_spc_over_V.nii.gz -overwrite
3dcalc -a ${flpr}_cvr_idx.nii.gz -expr 'a*0' -prefix ${flpr}_tmap.nii.gz -overwrite

maxidx=( $( fslstats ${flpr}_cvr_idx -R ) )

for i in $( seq -f %g ${maxidx[0]} ${maxidx[1]} )
do
	let v=i*step
	v=$( printf %04d $v )
	3dcalc -a ${flpr}_spc_over_V.nii.gz -b tmp.${flpr}_res/${flpr}_betas_${v}.nii.gz -c ${flpr}_cvr_idx.nii.gz \
	-expr "a+b*equals(c,${i})" -prefix ${flpr}_spc_over_V.nii.gz -overwrite
	3dcalc -a ${flpr}_tmap.nii.gz -b tmp.${flpr}_res/${flpr}_tstat_${v}.nii.gz -c ${flpr}_cvr_idx.nii.gz \
	-expr "a+b*equals(c,${i})" -prefix ${flpr}_tmap.nii.gz -overwrite
done

# the factor 71.2 is to take into account the pressure in mmHg:
# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
# multiply by 100 cause it's not BOLD % yet!
fslmaths ${flpr}_spc_over_V.nii.gz -div 71.2 -mul 100 ${flpr}_cvr.nii.gz

if [ ! -d ${flpr}_map_cvr ]
then
	mkdir ${flpr}_map_cvr
fi

mv ${flpr}_cvr* ${flpr}_map_cvr/.
mv ${flpr}_spc* ${flpr}_map_cvr/.
mv ${flpr}_tmap* ${flpr}_map_cvr/.

# rm -rf tmp.*

# done

##### ------------------ #
####				    ##
###   Getting T maps   ###
##				      ####
# ------------------ #####

cd ${flpr}_map_cvr

fslmaths ${flpr}_tmap -thr ${tscore} ${flpr}_tmap_pos
fslmaths ${flpr}_tmap_pos -bin ${flpr}_tmap_pos_mask
fslmaths ${flpr}_tmap -mul -1 -thr ${tscore} ${flpr}_tmap_neg
fslmaths ${flpr}_tmap_neg -bin ${flpr}_tmap_neg_mask
fslmaths ${flpr}_tmap_neg -add ${flpr}_tmap_pos ${flpr}_tmap_abs
fslmaths ${flpr}_tmap_abs -bin ${flpr}_tmap_abs_mask

fslmaths ${flpr}_cvr_idx -thr 25 -uthr 695 -bin ${flpr}_cvr_idx_physio_constrained

fslmaths ${flpr}_cvr_idx -mas ${flpr}_tmap_abs_mask -mas ${flpr}_cvr_idx_physio_constrained ${flpr}_cvr_idx_corrected


3dcalc -a ${flpr}_cvr_idx_corrected.nii.gz -expr 'a*0' -prefix ${flpr}_spc_over_V_corrected.nii.gz -overwrite

for i in $( seq -f %g ${maxidx[0]} ${maxidx[1]} )
do
	let v=i*step
	v=$( printf %04d $v )
	3dcalc -a ${flpr}_spc_over_V_corrected.nii.gz -b ../tmp.${flpr}_res/${flpr}_betas_${v}.nii.gz -c ${flpr}_cvr_idx_corrected.nii.gz \
	-expr "a+b*equals(c,${i})" -prefix ${flpr}_spc_over_V_corrected.nii.gz -overwrite
done

fslmaths ${flpr}_spc_over_V_corrected.nii.gz -div 71.2 -mul 100 ${flpr}_cvr_corrected.nii.gz

##### --------------- #
####				 ##
###   Doing fitts   ###
##				   ####
# --------------- #####

# for vol in MA #OC E2 DN
# do
# 	cd tmp.${flpr}_res
# 	3dcalc -a fitts_REML_0000.nii.gz -expr 'a*0' -prefix fittsopt.nii.gz -overwrite
# 	for i in $( seq -f %03g 0 ${step} ${miter} )
# 	do
# 		3dcalc -a fittsopt.nii.gz -b fitts_REML_0${i}.nii.gz -c ../maps/${func}_idx_vol.nii.gz \
# 		-expr 'a+b*equals(c,'${i}')' -prefix fittsopt.nii.gz -overwrite
# 	done
# 	cd ..
# done

cd ${cwr}