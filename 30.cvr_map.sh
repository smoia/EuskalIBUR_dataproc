#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2
ftype=$3

# ftype is optcom, echo-2, meica, vessels, networks

wdr=${4:-/data}

step=10
lag=9
freq=40
tr=1.5
tscore=2.6

if [[ ${ftype} == 'meica' ]]
then
	tscore=2.7
fi


### Main ###

cwd=$( pwd )

let poslag=lag*freq
let miter=poslag*2

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

shiftdir=${flpr}_GM_${ftype}_avg_regr_shift

cd ${wdr}/CVR


func=${flpr}_task-breathhold_${ftype}_bold_bet
mask=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain_mask

3dTproject -polort 3 -input ${fdir}/${func}.nii.gz -mask ${fdir}/${mask}.nii.gz -prefix ${flpr}_${ftype}_pp.nii.gz -overwrite

fslmaths ${fdir}/${func} -Tmean ${flpr}_${ftype}_mean
fslmaths ${flpr}_${ftype}_pp -div ${flpr}_${ftype}_mean ${flpr}_${ftype}_SPC
imcp ${fdir}/${mask} ${flpr}_mask

if [ -d tmp.${flpr}_${ftype}_res ]
then
	rm -rf tmp.${flpr}_${ftype}_res
fi
mkdir tmp.${flpr}_${ftype}_res
# mkdir tmp.${flpr}_${ftype}_res_reml

for i in $( seq -f %04g 0 ${step} ${miter} )
do
	if [ -e ${shiftdir}/shift_${i}.1D ]
	then
		3dDetrend -prefix - -polort 3 ${shiftdir}/shift_${i}.1D\' > ${shiftdir}/shift_${i}_pp.1D

		if [[ ${ftype} == 'meica' ]]
		then
			3dDeconvolve -input ${flpr}_${ftype}_SPC.nii.gz -jobs 6 \
			-float -num_stimts 1 \
			-mask ${flpr}_mask.nii.gz \
			-stim_file 1 ${shiftdir}/shift_${i}_pp.1D \
			-x1D ${shiftdir}/mat.1D \
			-xjpeg ${shiftdir}/mat.jpg \
			-x1D_uncensored ${shiftdir}/${i}_uncensored_mat.1D \
			-rout -tout \
			-bucket tmp.${flpr}_${ftype}_res/stats_${i}.nii.gz
		else
			3dDeconvolve -input ${flpr}_${ftype}_SPC.nii.gz -jobs 6 \
			-float -num_stimts 1 \
			-mask ${flpr}_mask.nii.gz \
			-ortvec ${flpr}_demean.par motdemean \
			-ortvec ${flpr}_deriv1.par motderiv1 \
			-stim_file 1 ${shiftdir}/shift_${i}_pp.1D \
			-x1D ${shiftdir}/mat.1D \
			-xjpeg ${shiftdir}/mat.jpg \
			-x1D_uncensored ${shiftdir}/${i}_uncensored_mat.1D \
			-rout -tout \
			-bucket tmp.${flpr}_${ftype}_res/stats_${i}.nii.gz
		fi

		3dbucket -prefix tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_r2_${i}.nii.gz -abuc tmp.${flpr}_${ftype}_res/stats_${i}.nii.gz'[0]' -overwrite
		3dbucket -prefix tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_betas_${i}.nii.gz -abuc tmp.${flpr}_${ftype}_res/stats_${i}.nii.gz'[2]' -overwrite
		3dbucket -prefix tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_tstat_${i}.nii.gz -abuc tmp.${flpr}_${ftype}_res/stats_${i}.nii.gz'[3]' -overwrite

		# 3dREMLfit -matrix ${shiftdir}/${i}_uncensored_mat.1D \
		# -input ${flpr}_${ftype}_SPC.nii.gz -nobout \
		# -mask ${flpr}_mask.nii.gz \
		# -Rbuck tmp.${flpr}_${ftype}_res_reml/stats_REML_${i}.nii.gz \
		# -Rfitts tmp.${flpr}_${ftype}_res_reml/fitts_REML_${i}.nii.gz \
		# -verb -overwrite

		# -Rvar tmp.${flpr}_${ftype}_res/stats_REMLvar_${i}.nii.gz \

		# 3dbucket -prefix tmp.${flpr}_${ftype}_res_reml/${flpr}_${ftype}_${i}.nii.gz -abuc tmp.${flpr}_${ftype}_res_reml/stats_REML_${i}.nii.gz'[1]' -overwrite
	fi
done

fslmerge -tr ${flpr}_${ftype}_r2_time tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_r2_* ${tr}
fslmerge -tr ${flpr}_${ftype}_betas_time tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_betas_* ${tr}
fslmerge -tr ${flpr}_${ftype}_tstat_time tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_tstat_* ${tr}
# fslmerge -t ${flpr}_${ftype}_betas_time tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_betas_*

fslmaths ${flpr}_${ftype}_r2_time -Tmaxn ${flpr}_${ftype}_cvr_idx
fslmaths ${flpr}_${ftype}_cvr_idx -mul ${step} -sub ${poslag} -mul 0.025 ${flpr}_${ftype}_cvr_lag

# prepare empty volumes
fslmaths ${flpr}_${ftype}_cvr_idx -mul 0 ${flpr}_${ftype}_spc_over_V
fslmaths ${flpr}_${ftype}_cvr_idx -mul 0 ${flpr}_${ftype}_tmap

maxidx=( $( fslstats ${flpr}_${ftype}_cvr_idx -R ) )

for i in $( seq -f %g ${maxidx[0]} ${maxidx[1]} )
do
	let v=i*step
	v=$( printf %04d $v )
	3dcalc -a ${flpr}_${ftype}_spc_over_V.nii.gz -b tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_betas_${v}.nii.gz -c ${flpr}_${ftype}_cvr_idx.nii.gz \
	-expr "a+b*equals(c,${i})" -prefix ${flpr}_${ftype}_spc_over_V.nii.gz -overwrite
	3dcalc -a ${flpr}_${ftype}_tmap.nii.gz -b tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_tstat_${v}.nii.gz -c ${flpr}_${ftype}_cvr_idx.nii.gz \
	-expr "a+b*equals(c,${i})" -prefix ${flpr}_${ftype}_tmap.nii.gz -overwrite
done

# the factor 71.2 is to take into account the pressure in mmHg:
# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
# multiply by 100 cause it's not BOLD % yet!
fslmaths ${flpr}_${ftype}_spc_over_V.nii.gz -div 71.2 -mul 100 ${flpr}_${ftype}_cvr.nii.gz

if [ ! -d ${flpr}_${ftype}_map_cvr ]
then
	mkdir ${flpr}_${ftype}_map_cvr
fi

mv ${flpr}_${ftype}_cvr* ${flpr}_${ftype}_map_cvr/.
mv ${flpr}_${ftype}_spc* ${flpr}_${ftype}_map_cvr/.
mv ${flpr}_${ftype}_tmap* ${flpr}_${ftype}_map_cvr/.

# done

##### ------------------ #
####				    ##
###   Getting T maps   ###
##				      ####
# ------------------ #####

cd ${flpr}_${ftype}_map_cvr

fslmaths ${flpr}_${ftype}_tmap -thr ${tscore} ${flpr}_${ftype}_tmap_pos
fslmaths ${flpr}_${ftype}_tmap_pos -bin ${flpr}_${ftype}_tmap_pos_mask
fslmaths ${flpr}_${ftype}_tmap -mul -1 -thr ${tscore} ${flpr}_${ftype}_tmap_neg
fslmaths ${flpr}_${ftype}_tmap_neg -bin ${flpr}_${ftype}_tmap_neg_mask
fslmaths ${flpr}_${ftype}_tmap_neg -add ${flpr}_${ftype}_tmap_pos ${flpr}_${ftype}_tmap_abs
fslmaths ${flpr}_${ftype}_tmap_abs -bin ${flpr}_${ftype}_tmap_abs_mask

fslmaths ${flpr}_${ftype}_cvr_idx -mul ${step} -thr 5 -uthr 705 -bin ${flpr}_${ftype}_cvr_idx_physio_constrained

fslmaths ${flpr}_${ftype}_cvr_idx_physio_constrained -mas ${flpr}_${ftype}_tmap_abs_mask -bin ${flpr}_${ftype}_cvr_idx_mask
fslmaths ../${flpr}_mask -sub ${flpr}_${ftype}_cvr_idx_mask ${flpr}_${ftype}_cvr_idx_bad_vxs

fslmaths ${flpr}_${ftype}_cvr_idx -sub 36 -mas ${flpr}_${ftype}_cvr_idx_mask -add 36 -mas ../${flpr}_mask ${flpr}_${ftype}_cvr_idx_corrected
fslmaths ${flpr}_${ftype}_cvr_idx_corrected -mul ${step} -sub ${poslag} -mul 0.025 ${flpr}_${ftype}_cvr_lag_corrected

fslmaths ${flpr}_${ftype}_cvr -mas ${flpr}_${ftype}_cvr_idx_mask ${flpr}_${ftype}_cvr_masked

fslmaths ${flpr}_${ftype}_cvr_idx_bad_vxs -mul ../tmp.${flpr}_${ftype}_res/${flpr}_${ftype}_betas_0360 -div 71.2 -mul 100 -add ${flpr}_${ftype}_cvr_masked ${flpr}_${ftype}_cvr_corrected

cd ..

##### --------------- #
####				 ##
###   Doing fitts   ###
##				   ####
# --------------- #####

# for vol in MA #OC E2 DN
# do
# 	cd tmp.${flpr}_${ftype}_res
# 	3dcalc -a fitts_REML_0000.nii.gz -expr 'a*0' -prefix fittsopt.nii.gz -overwrite
# 	for i in $( seq -f %03g 0 ${step} ${miter} )
# 	do
# 		3dcalc -a fittsopt.nii.gz -b fitts_REML_0${i}.nii.gz -c ../maps/${func}_idx_vol.nii.gz \
# 		-expr 'a+b*equals(c,'${i}')' -prefix fittsopt.nii.gz -overwrite
# 	done
# 	cd ..
# done


#rm -rf tmp.*

cd ${cwd}