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

map=$1
wdr=${2:-/data}
tmp=${3:-/tmp}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Surr_reliability || exit

if_missing_do mkdir surrogate_sets

tmp=${tmp}/tmp.${map}_10sa
replace_and mkdir ${tmp}

# Copy files for transformation & create mask
if_missing_do mask ${sdr}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm_mcorr.nii.gz ./MNI_GM.nii.gz

# Create folder ICC
for n in $(seq -f %03g 0 999)
do
	runfslmerge="fslmerge -t surrogate_sets/${map}_${n}_all"
	for sub in 001 002 003 004 007 008 009
	do
		for ses in $(seq -f %02g 1 10)
		do
			runfslmerge="${runfslmerge} surr/std_${sub}_${ses}_${map}/std_${sub}_${ses}_${map}_Surr_${n}.nii.gz "
		done
	done
	eval ${runfslmerge}
	fslmaths surrogate_sets/${map}_${n}_all -Tmean ${tmp}/${map}_average_${n}
done

echo "Merge all averages together"
fslmerge -t surr/${map}_all_surr_avg.nii.gz ${tmp}/${map}_average_* 

echo "End of script!"

cd ${cwd}
