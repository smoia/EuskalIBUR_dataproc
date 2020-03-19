#!/usr/bin/env bash


sub=$1
ses=$2
TR=${3:-1.5}
wdr=${4:-/data}
tmp=${5:-/tmp}

### Main ###
cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "decomp" ]]
then
	cd ${cwd}
	03.data_preproc/01.sheet_preproc.sh ${sub}
	cd ${wdr}
fi

echo "Denoising sub ${sub} ses ${ses} optcom"
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}
meica_fldr=${fdir}/${flpr}_task-breathhold_concat_bold_bet_meica
meica_mix=${meica_fldr}/ica_mixing.tsv

sbrf=${wdr}/sub-${sub}/ses-01/func_preproc/sub-${sub}_ses-01_task-breathhold_rec-magnitude_echo-1_sbref
func=${fdir}/${flpr}_task-breathhold_optcom_bold_bet
bold=${flpr}_task-breathhold

cd decomp || exit

# 01.1. Processing list of classified components
acc=$( cat ${flpr}_accepted_list.1D )
rej=$( cat ${flpr}_rejected_list.1D )
ves=$( cat ${flpr}_vessels_list.1D )
# net=$( cat ${flpr}_networks_list.1D )

# 01.2. Process rejected
1dcat "$meica_mix[$acc]" > ${flpr}_accepted.1D
# 1dcat "$meica_mix[$acc$net]" > ${flpr}_accepted.1D
1dcat "$meica_mix[$ves]" > ${flpr}_vessels.1D
1dcat "$meica_mix[$rej]" > ${flpr}_rejected.1D

# 01.9.1. Transforming kappa based idx into var based idx for each type !!! independently !!!
for type in accepted rejected vessels  # networks
do
	csvtool transpose ${flpr}_${type}_list.1D > ${tmp}/tmp.${flpr}_01rmms_${type}_transpose.1D
	touch ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D
	for i in $( cat ${tmp}/tmp.${flpr}_01rmms_${type}_transpose.1D )
	do
		grep ,${i} < ${meica_fldr}/idx_map.csv | awk -F',' '{print $1}' >> ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D
	done
	csvtool -u SPACE transpose ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D > ${flpr}_${type}_var_list.1D
done
# 01.9.2. Add a blank line at the beginning probably due to "feature" of 3dSynthesize version Dec 5 2019
echo "   " | cat - ${meica_fldr}/ica_mixing_orig.tsv > ${tmp}/tmp.${flpr}_01rmms_orig_mix

# 02. Running different kinds of denoise: aggressive, orthogonalised, partial regression, multivariate

# 02.2. Run 4D denoise (multivariate): recreates a matrix of noise post-ICA, then substract it from original data.
for type in rejected  # vessels networks
do
	3dSynthesize -cbucket ${meica_fldr}/ica_components_orig.nii.gz \
				 -matrix ${tmp}/tmp.${flpr}_01rmms_orig_mix -TR ${TR} \
				 -select $( cat ${flpr}_${type}_var_list.1D ) \
				 -prefix ${tmp}/tmp.${flpr}_01rmms_${type}_volume.nii.gz \
				 -overwrite
done

# 02.3. Computing voxelwise std of the original volume,
#       multiplying the results of 3dSynthesize to scale them to the original data,
#	    substracting
fslmaths ${func} -Tstd ${tmp}/tmp.${flpr}_01rmms_std
fslmaths ${func} -Tmean ${tmp}/tmp.${flpr}_01rmms_mean

## O: original		A: accepted only	R: rejected only	N: networks only	V: vessels only
## PCA: O = (Y + E) * std(O) + avg(O)						E: noise
## ICA: Y = T*S = A+R+V+N 									T: time decomp		S: space decomp

# Removing rejected:			[R*std(O)-O]*(-1) = R_0
fslmaths ${tmp}/tmp.${flpr}_01rmms_rejected_volume -mul ${tmp}/tmp.${flpr}_01rmms_std -sub ${func} \
		 -mul -1 ${fdir}/${bold}_meica-mvar_bold_bet
# Removing vessels:			[(R*std(O)-R_0]*(-1) = V_0
# fslmaths ${tmp}/tmp.${flpr}_01rmms_vessels_volume -mul ${tmp}/tmp.${flpr}_01rmms_std -sub ${fdir}/${bold}_meica-mvar_bold_bet \
# 		 -mul -1 ${fdir}/${bold}_vessels-mvar_bold_bet
# # Removing networks:		[R*std(O)-V_0]*(-1)
# fslmaths ${tmp}/tmp.${flpr}_01rmms_networks_volume -mul ${tmp}/tmp.${flpr}_01rmms_std -sub ${fdir}/${bold}_vessels-mvar_bold_bet \
# 		 -mul -1 ${fdir}/${bold}_networks-mvar_bold_bet

rm ${tmp}/tmp.${flpr}_01rmms_*

cd ${cwd}

# Topup everything!
for type in meica  # vessels networks
do
	for den in mvar  # recn
	do
		${cwd}/02.func_preproc/02.func_pepolar.sh ${bold}_${type}-${den}_bold_bet ${fdir} ${sbrf}_topup
		imrm ${bold}_${type}-${den}_bold_bet.nii.gz
		${cwd}/02.func_preproc/09.func_spc.sh ${bold}_${type}-${den}_bold_tpp ${fdir}
		imrm ${bold}_${type}-${den}_bold_mean.nii.gz
		immv ${fdir}/${bold}_${type}-${den}_bold_tpp ${fdir}/00.${bold}_${type}-${den}_bold_native_preprocessed
		immv ${fdir}/${bold}_${type}-${den}_bold_SPC ${fdir}/01.${bold}_${type}-${den}_bold_native_SPC_preprocessed
	done
done
