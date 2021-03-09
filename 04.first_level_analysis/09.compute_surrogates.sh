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

cd ${wdr}/Surr_reliability || exit

sdr=${sdr}/30.plugins/04.wavelet_resampling
vprfx=std_${sub}_${ses}

if [[ ! -d "surr" ]]; then mkdir surr; fi
if [[ ! -d "surr/${vprfx}_cvr" ]]; then mkdir surr/${vprfx}_cvr surr/${vprfx}_lag; fi
if [[ -d "${tmp}/${sub}_${ses}_mcroot" ]]; then rm -rf ${tmp}/${sub}_${ses}_mcroot; fi
mkdir ${tmp}/${sub}_${ses}_mcroot

export MCR_CACHE_ROOT=${tmp}/${sub}_${ses}_mcroot

for map in cvr #lag
do
	vol=${vprfx}_${map}
	${sdr}/run_generate_surrogates.sh /opt/mcr/v84 \
									  ${tmp}/${vol}.nii.gz \
									  ${tmp}/${sub}_${ses}/MNI_GM.nii.gz \
									  1000 \
									  surr/${vol} #\
									  #${vol}
	rm ${tmp}/${vol}.nii.gz ${tmp}/${vol}.nii
	for n in $(seq 0 999)
	do
		mv surr/${vol}/${tmp}${vol}_Surr_${n}.nii.gz surr/${vol}/${vol}_Surr_${n}.nii.gz
	done
done

cd ${cwd}