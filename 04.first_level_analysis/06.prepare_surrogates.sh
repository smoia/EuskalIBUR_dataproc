#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2019
#########

if_missing_do() {
if [ ! -e $3 ]
then
	printf "%s is missing, " "$3"
	case $1 in
		copy ) echo "copying $2"; cp $2 $3 ;;
		mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
		* ) "and you shouldn't see this"; exit ;;
	esac
fi
}

sub=$1
ses=$2
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-/tmp}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)


cd ${wdr} || exit

if [[ ! -d "Surr_reliability" ]]; then mkdir Surr_reliability Surr_reliability/norm Surr_reliability/surr; fi
if [[ ! -d "CVR" ]]; then echo "Missing CVR computations"; exit; fi
if [[ -d "${tmp}/${sub}_${ses}" ]]; then rm -rf ${tmp}/${sub}_${ses}; fi
mkdir ${tmp}/${sub}_${ses}

cd Surr_reliability

if_missing_do mask ${sdr}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm_mcorr.nii.gz ./MNI_GM.nii.gz
if_missing_do copy ./MNI_GM.nii.gz ${tmp}/${sub}_${ses}/MNI_GM.nii.gz

echo "Preparing transformation of subject ${sub}"
T12stdwarp=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz
T12stdlreg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat
T22T1lreg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat
T22fnclreg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat

cvrmap=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr.nii.gz
# lagmap=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr_lag.nii.gz
# statmask=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr_idx_mask.nii.gz
# physmask=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_cvr_idx_physio_constrained.nii.gz

vprfx=std_${sub}_${ses}

for vol in ${cvrmap}  # ${lagmap}  # ${statmask} ${physmask}
do
	case ${vol#*optcom_cvr} in
		.nii.gz ) outvol=${vprfx}_cvr ;;
		_lag.nii.gz ) outvol=${vprfx}_lag ;;
		_idx_mask.nii.gz ) outvol=${vprfx}_statmask ;;
		_idx_physio_constrained.nii.gz ) outvol=${vprfx}_physmask ;;
	esac

	echo "Transforming ${outvol} to MNI"
	antsApplyTransforms -d 3 -i ${vol} -r ${sdr}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz \
						-o ./norm/${outvol}.nii.gz -n NearestNeighbor \
						-t ${T12stdwarp} \
						-t ${T12stdlreg} \
						-t ${T22T1lreg} \
						-t [${T22fnclreg},1]
	echo "Copying norm in tmp for surrogate computation"
	if_missing_do copy ./norm/${outvol}.nii.gz ${tmp}/${outvol}.nii.gz
done

echo "Threshold CVR outliers"
fslmaths ${tmp}/${vprfx}_cvr -thr 2.000001 -bin -mul 2 ${tmp}/${vprfx}_maxed_cvr
fslmaths ${tmp}/${vprfx}_cvr -uthr -1.999999 -bin -mul -2 -add ${tmp}/${vprfx}_maxed_cvr ${tmp}/${vprfx}_maxed_cvr
fslmaths ${tmp}/${vprfx}_cvr -uthr 2 -thr -2 -add ${tmp}/${vprfx}_maxed_cvr ${tmp}/${vprfx}_cvr

# for map in cvr lag
# do
# 	fslmaths ./norm/${vprfx}_${map} -mas ./norm/${vprfx}_statmask ./norm/${vprfx}_${map}_masked
# 	if_missing_do copy ./norm/${vprfx}_${map}_masked.nii.gz ${tmp}/${vprfx}_${map}_masked.nii.gz
# done

cd ${cwd}