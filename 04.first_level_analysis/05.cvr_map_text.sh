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

ftype=optcom
shiftdir=${flpr}_GM_optcom_avg_regr_shift
step=12
lag=9
freq=40
tr=1.5

### Main ###

cwd=$( pwd )

let poslag=lag*freq
let miter=poslag*2

func=${fdir}/01.${flpr}_task-breathhold_optcom_bold_parc-${parc}
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}

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
		3dDeconvolve -input ${func}.1D\' -jobs 6 \
					 -float -num_stimts 1 \
					 -polort 4 \
					 -ortvec ${flpr}_motpar_demean.par motdemean \
					 -ortvec ${flpr}_motpar_deriv1.par motderiv1 \
					 -stim_file 1 ${shiftdir}/shift_${i}.1D -stim_label 1 PetCO2 \
					 -x1D ${matdir}/mat.1D \
					 -xjpeg ${matdir}/mat.jpg \
					 -rout -tout -force_TR ${tr} \
					 -bucket ${tmp}/tmp.${flpr}_${parc}_05cmt_res/stats_${i}.1D

	fi
done

fslmerge -tr ${flpr}_${parc}_r2_time ${tmp}/tmp.${flpr}_${parc}_05cmt_res/${flpr}_${parc}_r2_* ${tr}

fslmaths ${flpr}_${parc}_r2_time -Tmaxn ${flpr}_${parc}_cvr_idx
fslmaths ${flpr}_${parc}_cvr_idx -mul ${step} -sub ${poslag} -mul 0.025 -mas ${mask} ${flpr}_${parc}_cvr_lag

# prepare empty volumes
fslmaths ${flpr}_${parc}_cvr_idx -mul 0 ${tmp}/${flpr}_${parc}_statsbuck
fslmaths ${flpr}_${parc}_cvr_idx -mul 0 ${tmp}/${flpr}_${parc}_cbuck

maxidx=( $( fslstats ${flpr}_${parc}_cvr_idx -R ) )

for i in $( seq -f %g 0 ${maxidx[1]} )
do
	let v=i*step
	v=$( printf %04d $v )
	3dcalc -a ${tmp}/${flpr}_${parc}_statsbuck.1D -b ${tmp}/tmp.${flpr}_${parc}_05cmt_res/stats_${v}.1D -c ${flpr}_${parc}_cvr_idx.1D \
		   -expr "a+b*equals(c,${i})" -prefix ${tmp}/${flpr}_${parc}_statsbuck.1D -overwrite
	3dcalc -a ${tmp}/${flpr}_${parc}_cbuck.1D -b ${tmp}/tmp.${flpr}_${parc}_05cmt_res/c_stats_${v}.1D -c ${flpr}_${parc}_cvr_idx.1D \
		   -expr "a+b*equals(c,${i})" -prefix ${tmp}/${flpr}_${parc}_cbuck.1D -overwrite
done

3dbucket -prefix ${tmp}/${flpr}_${parc}_spc_over_V.1D -abuc ${tmp}/${flpr}_${parc}_statsbuck.1D'[17]' -overwrite
3dbucket -prefix ${tmp}/${flpr}_${parc}_tmap.1D -abuc ${tmp}/${flpr}_${parc}_statsbuck.1D'[18]' -overwrite

mv ${tmp}/${flpr}_${parc}_spc_over_V.1D .
mv ${tmp}/${flpr}_${parc}_tmap.1D .
mv ${tmp}/${flpr}_${parc}_cbuck.1D .
mv ${tmp}/${flpr}_${parc}_statsbuck.1D .

# Obtain first CVR maps
# the factor 71.2 is to take into account the pressure in mmHg:
# CO2[mmHg] = ([pressure in Donosti]*[Lab altitude] - [Air expiration at body temperature])[mmHg]*(channel_trace[V]*10[V^(-1)]/100)
# CO2[mmHg] = (768*0.988-47)[mmHg]*(channel_trace*10/100) ~ 71.2 mmHg
# multiply by 100 cause it's not BOLD % yet!
fslmaths ${flpr}_${parc}_spc_over_V.1D -div 71.2 -mul 100 ${flpr}_${parc}_cvr.1D
# Obtain "simple" t-stats and CVR 
medianvol=$( printf %04d ${poslag} )
3dcalc -a ${tmp}/tmp.${flpr}_${parc}_05cmt_res/stats_${medianvol}.1D'[17]' -expr 'a / 71.2 * 100' \
	   -prefix ${flpr}_${parc}_cvr_simple.1D -overwrite
3dcalc -a ${tmp}/tmp.${flpr}_${parc}_05cmt_res/stats_${medianvol}.1D'[18]' -expr 'a' \
	   -prefix ${flpr}_${parc}_tmap_simple.1D

if [ ! -d ${flpr}_${parc}_map_cvr ]
then
	mkdir ${flpr}_${parc}_map_cvr
fi

mv ${flpr}_${parc}_cvr* ${flpr}_${parc}_map_cvr/.
mv ${flpr}_${parc}_spc* ${flpr}_${parc}_map_cvr/.
mv ${flpr}_${parc}_tmap* ${flpr}_${parc}_map_cvr/.

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

cd ../${flpr}_${parc}_map_cvr
# Applying threshold on positive and inverted negative t scores, then adding them together to have absolute tscores.
fslmaths ${flpr}_${parc}_tmap -thr ${tscore} ${flpr}_${parc}_tmap_pos
fslmaths ${flpr}_${parc}_tmap -mul -1 -thr ${tscore} ${flpr}_${parc}_tmap_neg
fslmaths ${flpr}_${parc}_tmap_neg -add ${flpr}_${parc}_tmap_pos ${flpr}_${parc}_tmap_abs
# Binarising all the above to obtain masks.
fslmaths ${flpr}_${parc}_tmap_pos -bin ${flpr}_${parc}_tmap_pos_mask
fslmaths ${flpr}_${parc}_tmap_neg -bin ${flpr}_${parc}_tmap_neg_mask
fslmaths ${flpr}_${parc}_tmap_abs -bin ${flpr}_${parc}_tmap_abs_mask

# Apply constriction by physiology (if a voxel didn't peak in range, might never peak)
fslmaths ${flpr}_${parc}_cvr_idx -mul ${step} -thr 5 -uthr 705 -bin ${flpr}_${parc}_cvr_idx_physio_constrained

# Obtaining the mask of good and the mask of bad voxels.
fslmaths ${flpr}_${parc}_cvr_idx_physio_constrained -mas ${flpr}_${parc}_tmap_abs_mask -bin ${flpr}_${parc}_cvr_idx_mask
fslmaths ${mask} -sub ${flpr}_${parc}_cvr_idx_mask ${flpr}_${parc}_cvr_idx_bad_vxs

# Obtaining lag map (but check next line)
fslmaths ${flpr}_${parc}_cvr_idx -sub 36 -mas ${flpr}_${parc}_cvr_idx_mask -add 36 -mas ${mask} ${flpr}_${parc}_cvr_idx_corrected
fslmaths ${flpr}_${parc}_cvr_idx_corrected -mul ${step} -sub ${poslag} -mul 0.025 -mas ${mask} ${flpr}_${parc}_cvr_lag_corrected

echo "Getting masked maps"
# Mask Good CVR map, lags and tstats
for map in cvr cvr_lag tmap
do
	fslmaths ${flpr}_${parc}_${map} -mas ${flpr}_${parc}_cvr_idx_mask ${flpr}_${parc}_${map}_masked
done

# # Momentarily retrieving tmap #30
# fslroi ../${flpr}_${parc}_tstat_time ${flpr}_${parc}_tmap_simple 30 1

echo "Getting corrected maps"
# Assign the value of the "simple" CVR and tmap map to the bad voxels to have a complete brain.
fslmaths ${flpr}_${parc}_cvr_idx_bad_vxs -mul ${flpr}_${parc}_cvr_simple -add ${flpr}_${parc}_cvr_masked ${flpr}_${parc}_cvr_corrected
fslmaths ${flpr}_${parc}_cvr_idx_bad_vxs -mul ${flpr}_${parc}_tmap_simple -add ${flpr}_${parc}_tmap_masked ${flpr}_${parc}_tmap_corrected

rm -rf ${tmp}/tmp.${flpr}_${parc}_05cmt_*

cd ${cwd}
