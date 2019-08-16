#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2
step=10
miter=720


for vol in melodic skundu
do
	func=${sub}_filt_${vol}

	3dTproject -polort 3 -input ${func}.nii.gz -prefix ${func}_pp.nii.gz

	fslmaths ${func} -Tmean ${func}_mean
	fslmaths ${func}_pp -div ${func}_mean ${func}_SPC
done 

# exit
for vol in melodic skundu
do
	func=${sub}_filt_${vol}
	# if [ -d ${sub}_filt_${vol}_res_deconv ]
	# then
	# 	rm -rf ${sub}_filt_${vol}_res_deconv
	# fi
	# mkdir ${sub}_filt_${vol}_res_deconv
	# mkdir ${sub}_filt_${vol}_res_reml

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
		-bucket ${sub}_filt_${vol}_res_deconv/stats_${i}.nii.gz

		# -ortvec ${fmat}_mcf_demean.par motdemean \
		# -ortvec ${fmat}_mcf_deriv1.par motderiv1 \
		
		3dbucket -prefix ${sub}_filt_${vol}_res_deconv/${sub}_filt_${vol}_${i}.nii.gz -abuc ${sub}_filt_${vol}_res_deconv/stats_${i}.nii.gz'[1]' -overwrite

		# 3dREMLfit -matrix regr/${sub}_GM_${vol}_regr_shift/${i}_uncensored_mat.1D \
		# -input ${func}_SPC.nii.gz -nobout \
		# -mask origvol/${sub}_mask.nii.gz \
		# -Rbuck ${sub}_filt_${vol}_res_reml/stats_REML_${i}.nii.gz \
		# -Rfitts ${sub}_filt_${vol}_res_reml/fitts_REML_${i}.nii.gz \
		# -verb -overwrite

		# -Rvar ${sub}_filt_${vol}_res/stats_REMLvar_${i}.nii.gz \

		# 3dbucket -prefix ${sub}_filt_${vol}_res_reml/${sub}_filt_${vol}_${i}.nii.gz -abuc ${sub}_filt_${vol}_res_reml/stats_REML_${i}.nii.gz'[1]' -overwrite
	done

	fslmerge -t ${sub}_filt_${vol}_cvr_deconv.nii.gz ${sub}_filt_${vol}_res_deconv/${sub}_filt_${vol}_*
	# the factor 71.2 is to take into account the pressure in mmHg:
	# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
	# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
	fslmaths ${sub}_filt_${vol}_cvr_deconv.nii.gz -Tmax -mul 71.2 ${sub}_filt_${vol}_cvr_max_deconv.nii.gz
	fslmaths ${sub}_filt_${vol}_cvr_deconv.nii.gz -Tmaxn -mul ${step} -sub 360 -mul 0.025 ${sub}_filt_${vol}_cvr_idx_deconv.nii.gz

	# fslmerge -t ${sub}_filt_${vol}_cvr_reml.nii.gz ${sub}_filt_${vol}_res_reml/${sub}_filt_${vol}_*
	# fslmaths ${sub}_filt_${vol}_cvr_reml.nii.gz -Tmax -mul 71.2 ${sub}_filt_${vol}_cvr_max_reml.nii.gz

	# fslmaths ${sub}_filt_${vol}_cvr_reml.nii.gz -Tmaxn -mul ${step} -sub 360 -mul 0.025 ${sub}_filt_${vol}_cvr_idx_reml.nii.gz

done


##### --------------- #
####				 ##
###   Doing fitts   ###
##				   ####
# --------------- #####

# for vol in MA #OC E2 DN
# do
# 	cd ${sub}_filt_${vol}_res
# 	3dcalc -a fitts_REML_0000.nii.gz -expr 'a*0' -prefix fittsopt.nii.gz -overwrite
# 	for i in $( seq -f %03g 0 ${step} ${miter} )
# 	do
# 		3dcalc -a fittsopt.nii.gz -b fitts_REML_0${i}.nii.gz -c ../maps/${sub}_filt_${vol}_idx_vol.nii.gz \
# 		-expr 'a+b*equals(c,'${i}')' -prefix fittsopt.nii.gz -overwrite
# 	done
# 	cd ..
# done