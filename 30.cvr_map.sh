#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2
step=10
lag=9
freq=40

let poslag=lag*freq
let miter=poslag*2


for vol in melodic skundu
do
	func=${sub}_filt_${vol}

	3dTproject -polort 3 -input ${func}.nii.gz -prefix ${func}_pp.nii.gz -overwrite

	fslmaths ${func} -Tmean ${func}_mean
	fslmaths ${func}_pp -div ${func}_mean ${func}_SPC
done 

# exit
for vol in melodic skundu
do
	func=${sub}_filt_${vol}
	if [ -d tmp.${func}_res ]
	then
		rm -rf tmp.${func}_res
	fi
	mkdir tmp.${func}_res
	# mkdir tmp.${func}_res_reml

	for i in $( seq -f %04g 0 ${step} ${miter} )
	do
		3dDetrend -prefix - -polort 3 regr/${sub}_GM_${vol}_regr_shift/shift_${i}.1D\' > regr/${sub}_GM_${vol}_regr_shift/shift_${i}_pp.1D

		3dDeconvolve -input ${func}_SPC.nii.gz -jobs 3 \
		-float -num_stimts 1 \
		-mask origvol/${sub}_mask.nii.gz \
		-stim_file 1 regr/${sub}_GM_${vol}_regr_shift/shift_${i}_pp.1D \
		-x1D regr/${sub}_GM_${vol}_regr_shift/mat.1D \
		-xjpeg regr/${sub}_GM_${vol}_regr_shift/mat.jpg \
		-x1D_uncensored regr/${sub}_GM_${vol}_regr_shift/${i}_uncensored_mat.1D \
		-rout \
		-bucket tmp.${func}_res/stats_${i}.nii.gz

		# -ortvec ${fmat}_mcf_demean.par motdemean \
		# -ortvec ${fmat}_mcf_deriv1.par motderiv1 \
		
		3dbucket -prefix tmp.${func}_res/${func}_r2_${i}.nii.gz -abuc tmp.${func}_res/stats_${i}.nii.gz'[0]' -overwrite
		3dbucket -prefix tmp.${func}_res/${func}_betas_${i}.nii.gz -abuc tmp.${func}_res/stats_${i}.nii.gz'[2]' -overwrite

		# 3dREMLfit -matrix regr/${sub}_GM_${vol}_regr_shift/${i}_uncensored_mat.1D \
		# -input ${func}_SPC.nii.gz -nobout \
		# -mask origvol/${sub}_mask.nii.gz \
		# -Rbuck tmp.${func}_res_reml/stats_REML_${i}.nii.gz \
		# -Rfitts tmp.${func}_res_reml/fitts_REML_${i}.nii.gz \
		# -verb -overwrite

		# -Rvar tmp.${func}_res/stats_REMLvar_${i}.nii.gz \

		# 3dbucket -prefix tmp.${func}_res_reml/${func}_${i}.nii.gz -abuc tmp.${func}_res_reml/stats_REML_${i}.nii.gz'[1]' -overwrite
	done

	fslmerge -t ${func}_r2_time tmp.${func}_res/${func}_r2_*
	# fslmerge -t ${func}_betas_time tmp.${func}_res/${func}_betas_*

	fslmaths ${func}_r2_time -Tmaxn ${func}_cvr_idx
	fslmaths ${func}_cvr_idx -mul ${step} -sub ${poslag} -mul 0.025 ${func}_cvr_lag

	# split idx volumes in masks, add
	3dcalc -a ${func}_cvr_idx.nii.gz -expr 'a*0' -prefix ${func}_cvr.nii.gz -overwrite

	maxidx=( $( fslstats ${func}_cvr_idx -R ) )

	for i in $( seq maxidx[0] maxidx[1] )
	do
		let v=i*step
		v=$( printf %04d $v )
		3dcalc -a ${func}_cvr.nii.gz -b tmp.${func}_res/${func}_betas_${v}.nii.gz -c ${func}_cvr_idx.nii.gz \
		-expr "a+b*equals(c,${i})" -prefix fittsopt.nii.gz -overwrite
	done

	# the factor 71.2 is to take into account the pressure in mmHg:
	# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
	# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
	fslmaths ${func}_cvr.nii.gz -Tmax -mul 71.2 ${func}_cvr_max.nii.gz

	rm -rf tmp.*

done


##### --------------- #
####				 ##
###   Doing fitts   ###
##				   ####
# --------------- #####

# for vol in MA #OC E2 DN
# do
# 	cd tmp.${func}_res
# 	3dcalc -a fitts_REML_0000.nii.gz -expr 'a*0' -prefix fittsopt.nii.gz -overwrite
# 	for i in $( seq -f %03g 0 ${step} ${miter} )
# 	do
# 		3dcalc -a fittsopt.nii.gz -b fitts_REML_0${i}.nii.gz -c ../maps/${func}_idx_vol.nii.gz \
# 		-expr 'a+b*equals(c,'${i}')' -prefix fittsopt.nii.gz -overwrite
# 	done
# 	cd ..
# done