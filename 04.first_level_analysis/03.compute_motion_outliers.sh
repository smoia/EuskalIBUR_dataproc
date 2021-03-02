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

sub=$1
ses=$2
wdr=${3:-/data}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

if_missing_do mkdir ME_Denoising

cd ME_Denoising

if_missing_do mkdir sub-${sub}

flpr=sub-${sub}_ses-${ses}
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

echo "Computing DVARS Pre-motcor and collecting FD"
3dTto1D -input ${fdir}/${flpr}_task-breathhold_echo-2_bold_cr.nii.gz -mask ${mask}.nii.gz -method dvars -prefix sub-${sub}/dvars_pre_${flpr}.1D

cp ${fdir}/${flpr}_task-breathhold_echo-1_bold_fd.par sub-${sub}/fd_${flpr}.1D

cd ${cwd}