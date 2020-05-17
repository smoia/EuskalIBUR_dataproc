#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

matrix_mod() {
mat=$1
newmat=${mat%.1D}_mod.1D
# Get data from original matrix
ni_type=$( cat ${mat} | grep ni_type )
ni_dimen=$( cat ${mat} | grep ni_dimen )
ColumnLabels=$( cat ${mat} | grep ColumnLabels )
RowTR=$( cat ${mat} | grep RowTR )
GoodList=$( cat ${mat} | grep GoodList )
NRowFull=$( cat ${mat} | grep NRowFull )
RunStart=$( cat ${mat} | grep RunStart )

# Get updated data based on original matrix
Nstim=${ni_type#*\"}
Nstim=${Nstim%\**}
StimLabels=\"${ColumnLabels#*\"}
let StimBotsTops=Nstim-1
# let Nstim=Nstim-5

# Print matrix to file
echo "\# <matrix" > ${newmat}
echo "${ni_type}" >> ${newmat}
echo "${ni_dimen}" >> ${newmat}
echo "${ColumnLabels}" >> ${newmat}
echo "${RowTR}" >> ${newmat}
echo "${GoodList}" >> ${newmat}
echo "${NRowFull}" >> ${newmat}
echo "${RunStart}" >> ${newmat}
echo "\#  Nstim = \"${Nstim}\"" >> ${newmat}
# All the columns will contain SIGNAL, except for the baseline.
echo "\#  StimBots = \"0..${StimBotsTops}\"" >> ${newmat} 
echo "\#  StimTops = \"0..${StimBotsTops}\"" >> ${newmat}
echo "\#  StimLabels = ${StimLabels}" >> ${newmat}
echo "\# >" >> ${newmat}

# Print data to file
csvtool drop 15 ${mat} >> ${newmat}
}


sub=$1
ses=$2
ftype=$3
pval=${4:-0.00175}  # it's 0.1 corrected for 60 repetitions

# ftype is optcom, echo-2, or any denoising of meica, vessels, and networks

wdr=${5:-/data}
tmp=${6:-/tmp}

step=12
lag=9
freq=40
tr=1.5

case ${ftype} in
	meica* | vessels* | networks* | optcom | echo-2 | all-orth ) echo "Good ftype ${ftype}" ;;
	* ) echo "Wrong ftype: ${ftype}"; exit ;;
esac


### Main ###

cwd=$( pwd )

let poslag=lag*freq
let miter=poslag*2

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

decompdir=${wdr}/decomp

case ${ftype} in
	echo-2 | *-mvar )
		func=${fdir}/01.${flpr}_task-breathhold_${ftype}_bold_native_SPC_preprocessed
		shiftdir=${flpr}_GM_${ftype}_avg_regr_shift
		;;
	* ) func=${fdir}/01.${flpr}_task-breathhold_optcom_bold_native_SPC_preprocessed
		shiftdir=${flpr}_GM_optcom_avg_regr_shift
		;;
esac

mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask
matdir=${flpr}_${ftype}_mat

cd ${wdr}/CVR || exit

if [ -d ${tmp}/tmp.${flpr}_${ftype}_02cms_res ]
then
	rm -rf ${tmp}/tmp.${flpr}_${ftype}_02cms_res
fi
# creating folder
mkdir ${tmp}/tmp.${flpr}_${ftype}_02cms_res

# creating 

if [ -d ${matdir} ]
then
	rm -rf ${matdir}
fi
mkdir ${matdir}

# Demean rejected ICAs
case ${ftype} in
	meica-aggr | meica-cons | meica-orth | all-orth )
		1d_tool.py -infile ${decompdir}/${flpr}_rejected.1D -demean \
				   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_rejected.1D -overwrite
		1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_rejected.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_rej.1D
	;;
esac

if [ ${ftype} == "all-orth" ]
then
	# Prepare polynomials and motion parameters
	3dDeconvolve -input ${func}.nii.gz -polort 4 \
				 -x1D_stop -x1D ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D -overwrite
	1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials_tr.1D

	1dtranspose ${flpr}_motpar_demean.par > ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_demean.1D
	1dtranspose ${flpr}_motpar_deriv1.par > ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_deriv1.1D
fi

for i in $( seq -f %04g 0 ${step} ${miter} )
do
	if [ -e ${shiftdir}/shift_${i}.1D ]
	then
		case ${ftype} in
			optcom | echo-2 )
				# Simply add motparams and polorts ( = N )
				# Prepare matrix
				3dDeconvolve -input ${func}.nii.gz -jobs 6 \
							 -float -num_stimts 1 \
							 -mask ${mask}.nii.gz \
							 -polort 4 \
							 -ortvec ${flpr}_motpar_demean.par motdemean \
							 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
							 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
							 -x1D ${matdir}/mat.1D \
							 -xjpeg ${matdir}/mat.jpg \
							 -x1D_stop

				# Modify matrix and call 3dREMLfit
				matrix_mod ${matdir}/mat.1D
				3dREMLfit -input ${func}.nii.gz -matrix ${matdir}/mat_mod.1D \
						  -mask ${mask}.nii.gz \
						  -rout -tout \
						  -Obuck ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz \
						  -Obeta ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${i}.nii.gz
			;;
			meica-aggr )
				# Simply add rejected and N
				3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_rej.1D \
						   -ort ${shiftdir}/shift_${i}.1D \
						   -ort ${flpr}_motpar_demean.par \
						   -ort ${flpr}_motpar_deriv1.par \
						   -polort 4 -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D -overwrite

				1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D
				1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -overwrite

				3dDeconvolve -input ${func}.nii.gz -jobs 6 \
							 -float -num_stimts 1 \
							 -mask ${mask}.nii.gz \
							 -polort 4 \
							 -ortvec ${flpr}_motpar_demean.par motdemean \
							 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_rejected.1D rejected \
							 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
							 -x1D ${matdir}/mat.1D \
							 -xjpeg ${matdir}/mat.jpg \
							 -x1D_stop

				# Modify matrix and call 3dREMLfit
				matrix_mod ${matdir}/mat.1D
				3dREMLfit -input ${func}.nii.gz -matrix ${matdir}/mat_mod.1D \
						  -mask ${mask}.nii.gz \
						  -rout -tout \
						  -Obuck ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz \
						  -Obeta ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${i}.nii.gz
			;;
			meica-cons )
				# Add rejected, orthogonalised by the (all the) good components and the PetCO2, and N.
				1d_tool.py -infile ${decompdir}/${flpr}_vessels.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_vessels.1D -overwrite
				1d_tool.py -infile ${decompdir}/${flpr}_accepted.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_accepted.1D -overwrite

				3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_rej.1D \
						   -ort ${shiftdir}/shift_${i}.1D \
						   -ort ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_accepted.1D \
						   -ort ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_vessels.1D \
						   -ort ${flpr}_motpar_demean.par \
						   -ort ${flpr}_motpar_deriv1.par \
						   -polort 4 -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D -overwrite

				1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D
				1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -overwrite

				3dDeconvolve -input ${func}.nii.gz -jobs 6 \
							 -float -num_stimts 1 \
							 -mask ${mask}.nii.gz \
							 -polort 4 \
							 -ortvec ${flpr}_motpar_demean.par motdemean \
							 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D rejected \
							 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
							 -x1D ${matdir}/mat_${i}.1D \
							 -xjpeg ${matdir}/mat.jpg \
							 -x1D_stop

				# Modify matrix and call 3dREMLfit
				matrix_mod ${matdir}/mat_${i}.1D
				3dREMLfit -input ${func}.nii.gz -matrix ${matdir}/mat_${i}_mod.1D \
						  -mask ${mask}.nii.gz \
						  -rout -tout \
						  -Obuck ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz \
						  -Obeta ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${i}.nii.gz
			;;
			meica-orth )
				# Add rejected, orthogonalised by the PetCO2, and N.
				3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_rej.1D \
						   -ort ${shiftdir}/shift_${i}.1D \
						   -ort ${flpr}_motpar_demean.par \
						   -ort ${flpr}_motpar_deriv1.par \
						   -polort 4 -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D -overwrite

				1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D
				1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -overwrite

				3dDeconvolve -input ${func}.nii.gz -jobs 6 \
							 -float -num_stimts 1 \
							 -mask ${mask}.nii.gz \
							 -polort 4 \
							 -ortvec ${flpr}_motpar_demean.par motdemean \
							 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D rejected \
							 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
							 -x1D ${matdir}/mat_${i}.1D \
							 -xjpeg ${matdir}/mat.jpg \
							 -x1D_stop

				# Modify matrix and call 3dREMLfit
				matrix_mod ${matdir}/mat_${i}.1D
				3dREMLfit -input ${func}.nii.gz -matrix ${matdir}/mat_${i}_mod.1D \
						  -mask ${mask}.nii.gz \
						  -rout -tout \
						  -Obuck ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz \
						  -Obeta ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${i}.nii.gz
			;;
			all-orth )
				# Orthogonalise everything to the PetCO2.
				# Orthogonalise polynomials to PetCO2
				3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials_tr.1D -ort ${shiftdir}/shift_${i}.1D \
						   -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials_ort.1D -overwrite
				1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials_ort.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D
				1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D -overwrite

				# Orthogonalise motion parameters to PetCO2
				for mottype in demean deriv1
				do
					3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_${mottype}.1D \
							   -ort ${shiftdir}/shift_${i}.1D \
							   -polort -1 -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D -overwrite
					1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_${mottype}_ort.1D
					1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_${mottype}_ort.1D -demean \
							   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_${mottype}_ort.1D -overwrite
				done

				# Orthogonalise rejected components to PetCO2
				3dTproject -input ${tmp}/tmp.${flpr}_${ftype}_02cms_rej.1D \
						   -ort ${shiftdir}/shift_${i}.1D \
						   -polort -1 -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D -overwrite

				1dtranspose ${tmp}/tmp.${flpr}_${ftype}_02cms_tr.1D > ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D
				1d_tool.py -infile ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -demean \
						   -write ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D -overwrite

				3dDeconvolve -input ${func}.nii.gz -jobs 6 \
							 -float -num_stimts 1 \
							 -mask ${mask}.nii.gz \
							 -polort 0 \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_polynomials.1D'[1..$]' poly \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_demean_ort.1D motpar \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_motpar_deriv1_ort.1D motderiv \
							 -ortvec ${tmp}/tmp.${flpr}_${ftype}_02cms_rejected_ort.1D rejected \
							 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
							 -x1D ${matdir}/mat_${i}.1D \
							 -xjpeg ${matdir}/mat.jpg \
							 -x1D_stop

				# Modify matrix and call 3dREMLfit
				matrix_mod ${matdir}/mat_${i}.1D
				3dREMLfit -input ${func}.nii.gz -matrix ${matdir}/mat_${i}_mod.1D \
						  -mask ${mask}.nii.gz \
						  -rout -tout \
						  -Obuck ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz \
						  -Obeta ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${i}.nii.gz
			;;
			* ) echo "    !!! Warning !!! Invalid ftype: ${ftype}"; exit ;;
		esac

		3dbucket -prefix ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_${ftype}_r2_${i}.nii.gz -abuc ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${i}.nii.gz'[0]' -overwrite
	fi
done

fslmerge -tr ${flpr}_${ftype}_r2_time ${tmp}/tmp.${flpr}_${ftype}_02cms_res/${flpr}_${ftype}_r2_* ${tr}

fslmaths ${flpr}_${ftype}_r2_time -Tmaxn ${flpr}_${ftype}_cvr_idx
fslmaths ${flpr}_${ftype}_cvr_idx -mul ${step} -sub ${poslag} -mul 0.025 -mas ${mask} ${flpr}_${ftype}_cvr_lag

# prepare empty volumes
fslmaths ${flpr}_${ftype}_cvr_idx -mul 0 ${tmp}/${flpr}_${ftype}_statsbuck
fslmaths ${flpr}_${ftype}_cvr_idx -mul 0 ${tmp}/${flpr}_${ftype}_cbuck

maxidx=( $( fslstats ${flpr}_${ftype}_cvr_idx -R ) )

for i in $( seq -f %g 0 ${maxidx[1]} )
do
	let v=i*step
	v=$( printf %04d $v )
	3dcalc -a ${tmp}/${flpr}_${ftype}_statsbuck.nii.gz -b ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${v}.nii.gz -c ${flpr}_${ftype}_cvr_idx.nii.gz \
		   -expr "a+b*equals(c,${i})" -prefix ${tmp}/${flpr}_${ftype}_statsbuck.nii.gz -overwrite
	3dcalc -a ${tmp}/${flpr}_${ftype}_cbuck.nii.gz -b ${tmp}/tmp.${flpr}_${ftype}_02cms_res/c_stats_${v}.nii.gz -c ${flpr}_${ftype}_cvr_idx.nii.gz \
		   -expr "a+b*equals(c,${i})" -prefix ${tmp}/${flpr}_${ftype}_cbuck.nii.gz -overwrite
done

3dbucket -prefix ${tmp}/${flpr}_${ftype}_spc_over_V.nii.gz -abuc ${tmp}/${flpr}_${ftype}_statsbuck.nii.gz'[17]' -overwrite
3dbucket -prefix ${tmp}/${flpr}_${ftype}_tmap.nii.gz -abuc ${tmp}/${flpr}_${ftype}_statsbuck.nii.gz'[18]' -overwrite

mv ${tmp}/${flpr}_${ftype}_spc_over_V.nii.gz .
mv ${tmp}/${flpr}_${ftype}_tmap.nii.gz .
mv ${tmp}/${flpr}_${ftype}_cbuck.nii.gz .
mv ${tmp}/${flpr}_${ftype}_statsbuck.nii.gz .

# Obtain first CVR maps
# the factor 71.2 is to take into account the pressure in mmHg:
# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
# multiply by 100 cause it's not BOLD % yet!
fslmaths ${flpr}_${ftype}_spc_over_V.nii.gz -div 71.2 -mul 100 ${flpr}_${ftype}_cvr.nii.gz
# Obtain "simple" t-stats and CVR 
medianvol=$( printf %04d ${poslag} )
3dcalc -a ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${medianvol}.nii.gz'[17]' -expr 'a / 71.2 * 100' \
	   -prefix ${flpr}_${ftype}_cvr_simple.nii.gz -overwrite
3dcalc -a ${tmp}/tmp.${flpr}_${ftype}_02cms_res/stats_${medianvol}.nii.gz'[18]' -expr 'a' \
	   -prefix ${flpr}_${ftype}_tmap_simple.nii.gz

if [ ! -d ${flpr}_${ftype}_map_cvr ]
then
	mkdir ${flpr}_${ftype}_map_cvr
fi

mv ${flpr}_${ftype}_cvr* ${flpr}_${ftype}_map_cvr/.
mv ${flpr}_${ftype}_spc* ${flpr}_${ftype}_map_cvr/.
mv ${flpr}_${ftype}_tmap* ${flpr}_${ftype}_map_cvr/.

##### -------------------------- #
####                            ##
###   Getting T and CVR maps   ###
##                            ####
# -------------------------- #####

cd ${matdir}
# Get T score to threshold

# Read and process any mat there is in the "mat" folder
if [ -e "mat_0000.1D" ]
then
	mat=mat_0000.1D
elif [ -e "mat.1D" ]
then
	mat=mat.1D
else
	echo "Can't find any matrix. Abort."; exit
fi

# Extract degrees of freedom
n=$( head -n 2 ${mat} | tail -n 1 - )
n=${n#*\"}
n=${n%\**}
m=$( head -n 2 ${mat} | tail -n 1 - )
m=${m#*\"}
m=${m%\"*}
let ndof=m-n-1

# Get equivalent in t value
tscore=$( cdf -p2t fitt ${pval} ${ndof} )
tscore=${tscore##* }

cd ../${flpr}_${ftype}_map_cvr
# Applying threshold on positive and inverted negative t scores, then adding them together to have absolute tscores.
fslmaths ${flpr}_${ftype}_tmap -thr ${tscore} ${flpr}_${ftype}_tmap_pos
fslmaths ${flpr}_${ftype}_tmap -mul -1 -thr ${tscore} ${flpr}_${ftype}_tmap_neg
fslmaths ${flpr}_${ftype}_tmap_neg -add ${flpr}_${ftype}_tmap_pos ${flpr}_${ftype}_tmap_abs
# Binarising all the above to obtain masks.
fslmaths ${flpr}_${ftype}_tmap_pos -bin ${flpr}_${ftype}_tmap_pos_mask
fslmaths ${flpr}_${ftype}_tmap_neg -bin ${flpr}_${ftype}_tmap_neg_mask
fslmaths ${flpr}_${ftype}_tmap_abs -bin ${flpr}_${ftype}_tmap_abs_mask

# Apply constriction by physiology (if a voxel didn't peak in range, might never peak)
fslmaths ${flpr}_${ftype}_cvr_idx -mul ${step} -thr 5 -uthr 705 -bin ${flpr}_${ftype}_cvr_idx_physio_constrained

# Obtaining the mask of good and the mask of bad voxels.
fslmaths ${flpr}_${ftype}_cvr_idx_physio_constrained -mas ${flpr}_${ftype}_tmap_abs_mask -bin ${flpr}_${ftype}_cvr_idx_mask
fslmaths ${mask} -sub ${flpr}_${ftype}_cvr_idx_mask ${flpr}_${ftype}_cvr_idx_bad_vxs

# Obtaining lag map (but check next line)
fslmaths ${flpr}_${ftype}_cvr_idx -sub 36 -mas ${flpr}_${ftype}_cvr_idx_mask -add 36 -mas ${mask} ${flpr}_${ftype}_cvr_idx_corrected
fslmaths ${flpr}_${ftype}_cvr_idx_corrected -mul ${step} -sub ${poslag} -mul 0.025 -mas ${mask} ${flpr}_${ftype}_cvr_lag_corrected

echo "Getting masked maps"
# Mask Good CVR map, lags and tstats
for map in cvr cvr_lag tmap
do
	fslmaths ${flpr}_${ftype}_${map} -mas ${flpr}_${ftype}_cvr_idx_mask ${flpr}_${ftype}_${map}_masked
done

# # Momentarily retrieving tmap #30
# fslroi ../${flpr}_${ftype}_tstat_time ${flpr}_${ftype}_tmap_simple 30 1

echo "Getting corrected maps"
# Assign the value of the "simple" CVR and tmap map to the bad voxels to have a complete brain.
fslmaths ${flpr}_${ftype}_cvr_idx_bad_vxs -mul ${flpr}_${ftype}_cvr_simple -add ${flpr}_${ftype}_cvr_masked ${flpr}_${ftype}_cvr_corrected
fslmaths ${flpr}_${ftype}_cvr_idx_bad_vxs -mul ${flpr}_${ftype}_tmap_simple -add ${flpr}_${ftype}_tmap_masked ${flpr}_${ftype}_tmap_corrected

rm -rf ${tmp}/tmp.${flpr}_${ftype}_02cms_*

cd ${cwd}
