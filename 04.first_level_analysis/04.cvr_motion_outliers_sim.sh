#!/usr/bin/env bash

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -e $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

sub=$1
ses=$2
ftype=$3

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${4:-/data}
tmp=${5:-/tmp}

step=12

### Main ###

cwd=$( pwd )

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

matdir=${flpr}_${ftype}_mat

replace_and mkdir ${tmp}/tmp.${flpr}_${ftype}

cd ${wdr}/CVR || exit

if [[ ! -d "../ME_Denoising" ]]; then mkdir ../ME_Denoising; fi

case ${ftype} in
	echo-2 )
		func=${fdir}/01.${flpr}_task-breathhold_${ftype}_bold_native_SPC_preprocessed
		func_no_SPC=${fdir}/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed ;;
	* ) 
		func=${fdir}/01.${flpr}_task-breathhold_optcom_bold_native_SPC_preprocessed
		func_no_SPC=${fdir}/00.${flpr}_task-breathhold_optcom_bold_native_preprocessed ;;
esac

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

case ${ftype} in
	optcom | echo-2 )
		# Reconstruct motparams and polorts ( = N )
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite
	;;
	meica-aggr )
		# Reconstruct rejected and N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat.1D \
					 -select polort motdemean motderiv1 rejected \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite
	;;
	meica-orth )
		# Reconstruct rejected, orthogonalised by the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		maxidx=( $( fslstats ${flpr}_${ftype}_map_cvr/${flpr}_${ftype}_cvr_idx -R ) )

		for i in $( seq -f %g 0 ${maxidx[1]} )
		do
			let v=i-1
			let v*=step
			v=$( printf %04d $v )
			if [ -e ${matdir}/mat_${v}.1D ]
			then
				# Extract only right voxels for synthesize
				3dcalc -a ${flpr}_${ftype}_cbuck.nii.gz -b ${flpr}_${ftype}_map_cvr/${flpr}_${ftype}_cvr_idx.nii.gz \
					   -expr "a*equals(b,${i})" -prefix ${tmp}/tmp.${flpr}_${ftype}/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket ${tmp}/tmp.${flpr}_${ftype}/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}/tmp.${flpr}_${ftype}_04cmos_remove_synth.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}/tmp.${flpr}_${ftype}_04cmos_remove_synth.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf ${tmp}/tmp.${flpr}_${ftype}
	;;
	meica-cons )
		# Reconstruct rejected, orthogonalised by the good components and the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		maxidx=( $( fslstats ${flpr}_${ftype}_map_cvr/${flpr}_${ftype}_cvr_idx -R ) )

		for i in $( seq -f %g 0 ${maxidx[1]} )
		do
			let v=i-1
			let v*=step
			v=$( printf %04d $v )
			if [ -e ${matdir}/mat_${v}.1D ]
			then
				# Extract only right voxels for synthesize
				3dcalc -a ${flpr}_${ftype}_cbuck.nii.gz -b ${flpr}_${ftype}_map_cvr/${flpr}_${ftype}_cvr_idx.nii.gz \
					   -expr "a*equals(b,${i})" -prefix ${tmp}/tmp.${flpr}_${ftype}/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket ${tmp}/tmp.${flpr}_${ftype}/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf ${tmp}/tmp.${flpr}_${ftype}
	;;
	* ) echo "    !!! Warning !!! Invalid ftype: ${ftype}"
esac

# # Masking the reconstructed noise just in case
# fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -mas ${flpr}_${ftype}_map_cvr/${flpr}_${ftype}_cvr_idx_mask ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
# Removing noise from original file
fslmaths ${func} -sub ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz ../ME_Denoising/${flpr}_${ftype}_residuals_SPC

cd ../ME_Denoising

fslmaths ${func_no_SPC} -Tmean ${tmp}/tmp.${flpr}_${ftype}_04cmos_avg

fslmaths ${flpr}_${ftype}_residuals_SPC -mul ${tmp}/tmp.${flpr}_${ftype}_04cmos_avg -add ${tmp}/tmp.${flpr}_${ftype}_04cmos_avg ${flpr}_${ftype}_residuals

if [[ ! -d "sub-${sub}" ]]; then mkdir sub-${sub}; fi

3dTto1D -input ${flpr}_${ftype}_residuals.nii.gz -mask ${mask}.nii.gz -method dvars -prefix sub-${sub}/dvars_${ftype}_${flpr}.1D

fslmeants -i ${flpr}_${ftype}_residuals -m ../CVR/sub-${sub}_GM_native > sub-${sub}/avg_GM_${ftype}_${flpr}.1D
fslmeants -i ${flpr}_${ftype}_residuals_SPC -m ../CVR/sub-${sub}_GM_native > sub-${sub}/avg_GM_SPC_${ftype}_${flpr}.1D

# Compute "pre" SPC if it doesn't exists
if [ ! -e "sub-${sub}/avg_GM_SPC_pre_${flpr}.1D" ]
then
	fslmaths ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
			 -Tmean ${tmp}/tmp.${flpr}_${ftype}_04cmos_pre_avg
	fslmaths ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
			 -sub ${tmp}/tmp.${flpr}_${ftype}_04cmos_pre_avg -div ${tmp}/tmp.${flpr}_${ftype}_04cmos_pre_avg \
			 ${tmp}/tmp.${flpr}_${ftype}_04cmos_pre_SPC

	fslmeants -i ${tmp}/tmp.${flpr}_${ftype}_04cmos_pre_SPC \
			  -m ../CVR/sub-${sub}_GM_native > sub-${sub}/avg_GM_SPC_pre_${flpr}.1D
	fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
			  -m ../CVR/sub-${sub}_GM_native > sub-${sub}/avg_GM_pre_${flpr}.1D
fi

rm -rf ${tmp}/tmp.${flpr}_${ftype}_04cmos*

cd ${cwd}