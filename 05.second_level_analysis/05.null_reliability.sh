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

map=$1
wdr=${2:-/data}
sdr=${3:-/scripts}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Surr_reliability || exit

# Copy files for transformation & create mask
if_missing_do mask ${sdr}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm_mcorr.nii.gz ./MNI_GM.nii.gz

# Create folder ICC

if_missing_do mkdir ICC ICC/lag ICC/cvr

# Run ICC once for original data
rm ICC/${map}/1000_orig.nii.gz

run3dICC="3dICC -prefix ICC/${map}/1000_orig.nii.gz -jobs 10"
run3dICC="${run3dICC} -mask ./MNI_GM.nii.gz"
run3dICC="${run3dICC} -model '1+(1|session)+(1|Subj)' "
run3dICC="${run3dICC} -dataTable "
run3dICC="${run3dICC}     Subj  session   InputFile                       "
for sub in 001 002 003 004 007 008 009
do
	for ses in $(seq -f %02g 1 10)
	do
		run3dICC="${run3dICC}     ${sub}  ${ses}  norm/std_${sub}_${ses}_${map}.nii.gz"
	done
done
eval ${run3dICC}

# Repeat for surrogates
for n in $(seq -f %03g 0 1000)
do
	rm ICC/${map}/${n}.nii.gz
	run3dICC="3dICC -prefix ICC/${map}/${n}.nii.gz -jobs 10"
	run3dICC="${run3dICC} -mask ./MNI_GM.nii.gz"
	run3dICC="${run3dICC} -model '1+(1|session)+(1|Subj)'"
	run3dICC="${run3dICC} -dataTable"
	run3dICC="${run3dICC}     Subj  session   InputFile                      "
	for sub in 001 002 003 004 007 008 009
	do
		for ses in $(seq -f %02g 1 10)
		do
			run3dICC="${run3dICC}     ${sub}  ${ses}  surr/std_${sub}_${ses}_${map}/std_${sub}_${ses}_${map}_Surr_${n}.nii.gz"
		done
	done
	eval ${run3dICC}
done

echo "Merge all ICCs together"
# fslmerge -t ICC/ICC_${map}.nii.gz ICC/${map}/* 

echo "End of script!"

cd ${cwd}
