#!/usr/bin/env bash

######### Preparing folders for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2
wdr=$3
overwrite=$4

anat1=$6
anat2=$7

stdp=$8

std=$9

######################################
######### Script starts here #########
######################################

# saving the current wokdir
cwd=$(pwd)

echo "************************************"
echo "*** Preparing folders"
echo "************************************"
echo "************************************"

cd ${wdr}/sub-${sub}/ses-${ses} || exit
if [[ "${overwrite}" == "overwrite" ]]
then
	for fld in func_preproc fmap_preproc reg anat_preproc
	do
		if [[ -d "${fld}" ]]
		then
			if [[ "${fld}" == "func_preproc" ]]
			then
				# backup only the necessary files for meica
				for bck in ${fld}/*_meica
				do
					[[ -e "${bck}" && -e "${bck/meica_mix.1D}" ]] || break
					echo "Backing up sub${bck#*sub*}"
					tar -zcvf $( date +%F_%H-%M-%S )_sub${bck#*sub*}_bck.tar.gz ${bck}/comp_table* ${bck}/*mix*
				done
			fi
				
			rm -r ${fld}
		fi
		mkdir ${fld}
	done

	imcp func/*.nii.gz func_preproc/.
	imcp anat/${anat1}.nii.gz anat_preproc/.
	imcp anat/${anat2}.nii.gz anat_preproc/.
	imcp fmap/*.nii.gz fmap_preproc/.
	imcp ${stdp}/${std}.nii.gz reg/.

fi

cd ${cwd}
