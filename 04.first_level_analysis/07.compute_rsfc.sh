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
		* ) "and you shouldn't see this"; exit ;;
	esac
fi
}

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

sub=$1
ses=$2

wdr=${3:-/data}
tmp=${4:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}
mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask

tmp=${tmp}/tmp.${flpr}_07cr
replace_and mkdir ${tmp}

cd ${wdr} || exit

if_missing_do mkdir Mennes_replication
if_missing_do mkdir Mennes_replication/fALFF Mennes_replication/RSFA

cd Mennes_replication

for run in $( seq -f %02g 1 4 )
do
	input=00.${flpr}_task-rest_run-${run}_optcom_bold_native_processed
	3dRSFC -input ${fdir}/${input}.nii.gz -band 0.01 0.1 \
		   -mask ${mask}.nii.gz -no_rs_out -nodetrend \
		   -prefix ${tmp}/${input}

	3dresample -input ${tmp}/${input}_fALFF+orig -prefix fALFF/${flpr}_task-rest_run-${run}_fALFF.nii.gz
	3dresample -input ${tmp}/${input}_RSFA+orig -prefix RSFA/${flpr}_task-rest_run-${run}_RSFA.nii.gz
done

rm -rf ${tmp}

cd ${cwd}