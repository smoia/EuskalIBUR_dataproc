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

run=${1}
lastses=${2}
wdr=${3:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr}/Dataset_QC || exit

echo "Creating folders"
if_missing_do mkdir icc

cd norm

# Compute ICC
for map in fALFF ALFF RSFA
do
	rm ../icc/ICC2_${map}_run-${run}.nii.gz

	run3dICC="3dICC -prefix ../icc/ICC2_${map}_run-${run}.nii.gz -jobs 10"
	run3dICC="${run3dICC} -mask ../reg/MNI_T1_brain_mask.nii.gz"
	run3dICC="${run3dICC} -model  '1+(1|session)+(1|Subj)'"
	run3dICC="${run3dICC} -dataTable"
	run3dICC="${run3dICC}      Subj session                         InputFile            "
	for sub in 001 002 003 004 007 008 009
	do
		for ses in $( seq -f %02g 1 ${lastses} )
		do
			run3dICC="${run3dICC}      ${sub}  ${ses}  ${sub}_${ses}_${map}_run-${run}.nii.gz"
		done
	done
	echo ""
	echo "${run3dICC}"
	echo ""
	eval ${run3dICC}
done

echo "End of script!"

cd ${cwd}