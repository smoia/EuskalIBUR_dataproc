#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########


sub=$1
ses=$2
ftype=$3

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${4:-/data}
tmp=${5:-/tmp}

step=12
tr=1.5

### Main ###

cwd=$( pwd )

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

matdir=${flpr}_${ftype}_mat


cd ${wdr}/CVR || exit

if [[ ! -d "../ME_Denoising" ]]; then mkdir ../ME_Denoising; fi

case ${ftype} in
	echo-2 | *-mvar )
		func=${fdir}/01.${flpr}_task-breathhold_${ftype}_bold_native_SPC_preprocessed
		func_no_SPC=${fdir}/00.${flpr}_task-breathhold_${ftype}_bold_native_preprocessed ;;
	* ) 
		func=${fdir}/01.${flpr}_task-breathhold_optcom_bold_native_SPC_preprocessed
		func_no_SPC=${fdir}/00.${flpr}_task-breathhold_optcom_bold_native_preprocessed ;;
esac

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

case ${ftype} in
	optcom | echo-2 | *-mvar )
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
		# Reconstruct rejected, orthogonalised by the good components and the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		# Create folder for synthesize
		if [ -d tmp.${flpr}_orth ]
		then
			rm -rf tmp.${flpr}_orth
		fi
		mkdir tmp.${flpr}_orth

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
					   -expr "a*equals(b,${i})" -prefix tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf tmp.${flpr}_meica-orth
	;;
	meica-cons )
		# Reconstruct rejected, orthogonalised by the good components and the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		# Create folder for synthesize
		if [ -d tmp.${flpr}_orth ]
		then
			rm -rf tmp.${flpr}_orth
		fi
		mkdir tmp.${flpr}_orth

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
					   -expr "a*equals(b,${i})" -prefix tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf tmp.${flpr}_meica-cons
	;;
	meica-aggr-twosteps )
		matdir=${flpr}_${ftype%-twosteps}_mat
		# Reconstruct rejected and N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat.1D \
					 -select polort motdemean motderiv1 rejected \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite
	;;
	meica-orth-twosteps )
		matdir=${flpr}_${ftype%-twosteps}_mat
		# Reconstruct rejected, orthogonalised by the good components and the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		# Create folder for synthesize
		if [ -d tmp.${flpr}_orth ]
		then
			rm -rf tmp.${flpr}_orth
		fi
		mkdir tmp.${flpr}_orth

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
					   -expr "a*equals(b,${i})" -prefix tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf tmp.${flpr}_meica-orth
	;;
	meica-cons-twosteps )
		matdir=${flpr}_${ftype%-twosteps}_mat
		# Reconstruct rejected, orthogonalised by the good components and the PetCO2, and N.
		# Start with N
		3dSynthesize -cbucket ${flpr}_${ftype}_cbuck.nii.gz \
					 -matrix ${matdir}/mat_0000.1D \
					 -select polort motdemean motderiv1 \
					 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
					 -overwrite

		# Create folder for synthesize
		if [ -d tmp.${flpr}_orth ]
		then
			rm -rf tmp.${flpr}_orth
		fi
		mkdir tmp.${flpr}_orth

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
					   -expr "a*equals(b,${i})" -prefix tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz -overwrite

				3dSynthesize -cbucket tmp.${flpr}_orth/tmp.masked_cbuck_${v}.nii.gz \
							 -matrix ${matdir}/mat_${v}.1D \
							 -select rejected \
							 -prefix ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
							 -overwrite
				fslmaths ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz -add ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz \
						 ${tmp}/tmp.${flpr}_${ftype}_04cmos_remove.nii.gz
			fi
		done
		rm -rf tmp.${flpr}_meica-cons
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

fslmeants -i ${wdr}/sub-${sub}/ses-${ses}/func_preproc/${flpr}_task-breathhold_echo-2_bold_cr \
		  -m ../CVR/sub-${sub}_GM_native > sub-${sub}/avg_GM_pre_${flpr}.1D

rm -rf ${tmp}/tmp.${flpr}_${ftype}_04cmos*

cd ${cwd}