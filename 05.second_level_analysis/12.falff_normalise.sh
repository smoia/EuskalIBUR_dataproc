#!/usr/bin/env bash

if_missing_do() {
if [ $1 == 'mkdir' ]
then
	if [ ! -d $2 ]
	then
		mkdir "${@:2}"
	fi
elif [ ! -e $3 ]
then
	printf "%s is missing, " "$3"
	case $1 in
		copy ) echo "copying $2"; cp $2 $3 ;;
		mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
		* ) echo "and you shouldn't see this"; exit ;;
	esac
fi
}

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

extract_and_average() {
k=1
for n in $(seq ${1} 2 ${2})
do
	3dbucket -prefix ${3}_${k}.nii.gz -abuc ${4}[${n}] -overwrite
	let k++
done
fslmerge -t ${3} ${3}_?.nii.gz
fslmaths ${3} -Tmean ${3}
}


sub=$1
ses=$2
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr} || exit

if_missing_do mkdir Dataset_QC

cd Dataset_QC

tmp=${tmp}/tmp.${sub}_${ses}_12fn
replace_and mkdir ${tmp}

if_missing_do mkdir norm reg
if_missing_do copy ${sdr}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz reg/MNI_T1_brain.nii.gz
if_missing_do mask reg/MNI_T1_brain.nii.gz reg/MNI_T1_brain_mask.nii.gz

# Prepare to break GLM bricks
echo "%%% Working on subject ${sub} %%%"

echo "Preparing transformation"
if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
			  reg/${sub}_T1w2std1Warp.nii.gz
if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
			  reg/${sub}_T1w2std0GenericAffine.mat
if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
			  reg/${sub}_T2w2sbref0GenericAffine.mat
if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
			  reg/${sub}_T2w2T1w0GenericAffine.mat

for n in $(seq 1 4)
do
	rbuck=${wdr}/Mennes_replication/fALFF/sub-${sub}_ses-${ses}_task-rest_run-0${n}_fALFF
	# Break bricks
	antsApplyTransforms -d 3 -i ${rbuck}.nii.gz -r ./reg/MNI_T1_brain.nii.gz \
						-o ./norm/${sub}_${ses}_fALFF_run-0${n}.nii.gz -n NearestNeighbor \
						-t ./reg/${sub}_T1w2std1Warp.nii.gz \
						-t ./reg/${sub}_T1w2std0GenericAffine.mat \
						-t ./reg/${sub}_T2w2T1w0GenericAffine.mat \
						-t [./reg/${sub}_T2w2sbref0GenericAffine.mat,1]
done

rm -rf ${tmp}

cd ${cwd}