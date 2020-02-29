#!/usr/bin/env bash

######### FULL BREATHHOLD PREPROC for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########

####
# TODO:
# - add a "nobet flag"
# - improve flags
# - Censors!
# - visual output

sub=$1
ses=$2
wdr=${3:-/data}
overwrite=${4:-overwrite}

run_anat=${5:-true}
run_sbref=${6:-true}

flpr=sub-${sub}_ses-${ses}

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc
stdp=/scripts/90.template

vdsc=10
std=MNI152_T1_1mm_brain
mmres=2.5
#fwhm=6

TEs="10.6 28.69 46.78 64.87 82.96"
nTE=5

# -> Answer to the Ultimate Question of Life, the Universe, and Everything.
# slice order file (full path to)
siot=none
# siot=${wdr}/sliceorder.txt

# Despiking
dspk=none

first_ses_path=${wdr}/sub-${sub}/ses-02

uni_sbref=${first_ses_path}/reg/sub-${sub}_sbref
uni_adir=${first_ses_path}/anat_preproc


####################

######################################
######### Script starts here #########
######################################

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${flpr}_log" ]]; then rm ${wdr}/log/${flpr}_log; fi

echo "************************************" >> ${wdr}/log/${flpr}_log

exec 3>&1 4>&2

exec 1>${wdr}/log/${flpr}_log 2>&1

date
echo "************************************"


echo "************************************"
echo "***    Preproc ${flpr}    ***"
echo "************************************"
echo "************************************"
echo ""
echo ""

######################################
#########   Prepare folders  #########
######################################

/scripts/prepare_folder.sh ${sub} ${ses} ${wdr} ${overwrite} \
				   ${anat1} ${anat2} ${stdp} ${std}

if [[ "${overwrite}" == "overwrite" ]]
then
	# If the folders were resetted, run again the full preproc
	run_anat=true
	run_sbref=true
fi

######################################
#########    Anat preproc    #########
######################################

if [[ "${run_anat}" == "true" ]]
then
	if [ ${ses} -eq 2 ]
	then
		# If asked & it's ses 01, run anat
		/scripts/00.pipelines/anat_preproc.sh ${sub} ${ses} ${wdr} ${anat1} ${anat2} \
						  ${adir} ${std} ${mmres}
	elif [ ${ses} -gt 2 ] && [ ! -d ${uni_adir} ]
	then
		# If it isn't ses 01 but that ses wasn't run, exit.
		echo "ERROR: the universal anat_preproc folder,"
		echo "   ${uni_adir}"
		echo "doesn't exist. For the moment, this means the program quits"
		echo "Please run the first session of each subject first"
		exit
	elif [ ${ses} -gt 2 ] && [ -d ${uni_adir} ]
	then
		# If it isn't ses 01, and that ses was run, copy relevant files.
		cp -R ${uni_adir}/* ${adir}/.
		# Then be sure that the anatomical files reference is right.
		anat1=sub-${sub}_ses-02_acq-uni_T1w 
		anat2=sub-${sub}_ses-02_T2w
		cp ${uni_adir}/../reg/*${anat1}* ${adir}/../reg/.
		cp ${uni_adir}/../reg/*${anat2}* ${adir}/../reg/.
	fi
fi


######################################
#########    SBRef preproc   #########
######################################

if [[ "${run_sbref}" == "true" ]]
then
	if [ ${ses} -eq 2 ]
	then
		# If asked & it's ses 01, run sbref
		/scripts/00.pipelines/sbref_preproc.sh ${sub} ${ses} ${wdr} ${flpr} ${fdir} ${fmap} ${anat2} ${adir}
	elif [ ${ses} -gt 2 ] && [ ! -d ${uni_adir} ]
	then
		# If it isn't ses 01 but that ses wasn't run, exit.
		echo "ERROR: the universal sbref,"
		echo "   ${uni_sbref}.nii.gz"
		echo "doesn't exist. For the moment, this means the program quits"
		echo "Please run the first session of each subject first"
		exit
	elif [ ${ses} -gt 2 ] && [ -d ${uni_adir} ]
	then
		# If it isn't ses 01, and that ses was run, copy relevant files.
		imcp ${uni_sbref} ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
		imcp ${uni_sbref}_brain ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain
		imcp ${uni_sbref}_brain_mask ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_brain_mask
		imcp ${wdr}/sub-${sub}/ses-02/reg/${anat2}2sub-${sub}_sbref ${wdr}/sub-${sub}/ses-${ses}/reg/${anat2}2sub-${sub}_sbref

		mkdir ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_topup
		cp -R ${uni_sbref}_topup/* ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref_topup/.

		cp ${wdr}/sub-${sub}/ses-02/reg/${anat2}2sub-${sub}_sbref_fsl.mat \
		   ${wdr}/sub-${sub}/ses-${ses}/reg/${anat2}2sub-${sub}_sbref_fsl.mat
		cp ${wdr}/sub-${sub}/ses-02/reg/${anat2}2sub-${sub}_sbref0GenericAffine.mat \
		   ${wdr}/sub-${sub}/ses-${ses}/reg/${anat2}2sub-${sub}_sbref0GenericAffine.mat
	fi
fi


######################################
#########    Task preproc    #########
######################################

/scripts/00.pipelines/breathhold_preproc.sh ${sub} ${ses} ${wdr} ${flpr} \
						${fdir} ${vdsc} "${TEs}" \
						${nTE} ${siot} ${dspk}

date
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"