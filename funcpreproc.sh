#!/usr/bin/env bash

######### FULL PREPROC for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

####
# TODO:
# - better Input Output with % and #
# - delete intermediate steps
# - add a "nobet flag"
# - improve flags
# - improve MEICA namings
# - Censors!
# - OC!
# - visual output
# - check vdsc


sub=$1
ses=$2
wdr=${3:-/data}
overwrite=${4:-overwrite}

flpr=sub-${sub}_ses-${ses}

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc
stdp=/scripts

vdsc=10
std=MNI152_T1_1mm_brain
mmres=2.5
fwhm=6

# -> Answer to the Ultimate Question of Life, the Universe, and Everything.
TEs="10.6 28.69 46.78 64.87 82.96"
nTE=5

# slice order file (full path to)
siot=none
# siot=${wdr}/sliceorder.txt

# Despiking
dspk=none

moio=none

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

echo $(date)
echo "************************************"

# saving the current wokdir
cwd=$(pwd)

echo "************************************"
echo "***    Preproc ${flpr}    ***"
echo "************************************"
echo "************************************"
echo ""
echo ""
echo "************************************"
echo "*** Preparing folders"
echo "************************************"
echo "************************************"

cd ${wdr}/sub-${sub}/ses-${ses}
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

######################################
#########    Anat preproc    #########
######################################

echo "************************************"
echo "*** Anat correction ${anat1}"
echo "************************************"
echo "************************************"

./01.anat_correct.sh ${anat1} ${adir}

echo "************************************"
echo "*** Anat correction ${anat2}"
echo "************************************"
echo "************************************"

./01.anat_correct.sh ${anat2} ${adir} ${anat1}

echo "************************************"
echo "*** Anat skullstrip ${anat2}"
echo "************************************"
echo "************************************"

./02.anat_skullstrip.sh ${anat2}_bfc ${adir} none ${anat1} none

echo "************************************"
echo "*** Anat skullstrip ${anat1}"
echo "************************************"
echo "************************************"

./02.anat_skullstrip.sh ${anat1}_bfc ${adir} ${anat1}_brain_mask none ${anat2}

echo "************************************"
echo "*** Anat segment"
echo "************************************"
echo "************************************"

./03.anat_segment.sh ${anat1}_brain ${adir}

echo "************************************"
echo "*** Anat normalise"
echo "************************************"
echo "************************************"

./04.anat_normalize.sh ${anat1}_brain ${adir} ${std} ${mmres}

echo "************************************"
echo "*** Clearspace"
echo "************************************"
echo "************************************"

./funcclearspace.sh ${sub} ${ses} ${wdr} anat

######################################
#########    SBRef preproc   #########
######################################

# Assign sbref to the first breathhold's sbref
uni_sbref=${wdr}/sub-${sub}/ses-01/func_preproc/sub-${sub}_ses-01_task-breathhold_rec-magnitude_echo-1_sbref_tpp.nii.gz
# Start funcpreproc by preparing the sbref.
# But only if ses=01

if [[ ${ses} -eq 1 ]]
then
	for d in AP PA
	do
		echo "************************************"
		echo "*** Func correct breathhold PE ${d}"
		echo "************************************"
		echo "************************************"

		func=${flpr}_acq-breathhold_dir-${d}_epi
		./05.func_correct.sh ${func} ${fmap}
	done

	bfor=${fmap}/${flpr}_acq-breathhold_dir-PA_epi_cr
	brev=${fmap}/${flpr}_acq-breathhold_dir-AP_epi_cr

	echo "************************************"
	echo "*** Func correct breathhold SBREF echo 1"
	echo "************************************"
	echo "************************************"

	sbrf=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref
	if [[ ! -e ${sbrf}_cr.nii.gz ]]
	then
		./05.func_correct.sh ${sbrf} ${fdir}
	fi

	echo "************************************"
	echo "*** Func pepolar breathhold SBREF echo 1"
	echo "************************************"
	echo "************************************"

	./06.func_pepolar.sh ${sbrf}_cr ${fdir} none ${brev} ${bfor}

	# Copy this sbref to reg folder
	imcp ${fdir}/${sbrf}_tpp ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref

elif [[ ${ses} -gt 1 && ! -e ${uni_sbref} ]]
then
	echo "ERROR: the universal sbref,"
	echo "   ${uni_sbref}"
	echo "doesn't exist. For the moment, this means the program quits"
	echo "Please run the first session of each subject first"
	exit
elif [[ ${ses} -gt 1 && -e ${uni_sbref} ]]
then
	imcp ${uni_sbref} ${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
fi

# This is the absolute sbref. Don't change it.
sbrf=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
mask=${sbrf}_brain_mask

######################################
#########    Task preproc    #########
######################################

for f in breathhold  # TASK1 TASK2 TASK3
do 
	for e in  $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func correct ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_echo-${e}_bold
		./05.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot}
	done

	echo "************************************"
	echo "*** Func spacecomp ${f} echo 1"
	echo "************************************"
	echo "************************************"

	fmat=${flpr}_task-${f}_echo-1_bold

	./07.func_spacecomp.sh ${fmat}_cr ${fdir} ${vdsc} ${adir}/${anat2} ${sbrf}

	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func realign ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_echo-${e}_bold_cr
		./08.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf}
	done

	echo "************************************"
	echo "*** Func MEICA ${f} BOLD"
	echo "************************************"
	echo "************************************"

	./09.func_meica.sh ${fmat}_bet ${fdir} "${TEs}" bck

	./10.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"
	
#####
####   Applytopup here!
##




	if [[ ${f} != "breathhold" ]]
	then
		# If not breathhold, apply smoothing and compute denoising.
		for e in $( seq 1 ${nTE} )
		do
			echo "************************************"
			echo "*** Func nuiscomp ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			bold=${flpr}_task-${f}_echo-${e}_bold
			./11.func_nuiscomp.sh ${bold}_bet ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} none
			
			echo "************************************"
			echo "*** Func smooth ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			./12.func_smooth.sh ${bold}_bet ${fdir} ${fwhm} ${mask}
			
			echo "************************************"
			echo "*** Func SPC ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			./13.func_spc.sh ${bold}_sm ${fdir}

			# First two outputs
			immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
			immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

		done

		echo "************************************"
		echo "*** Func nuiscomp ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_optcom_bold
		./11.func_nuiscomp.sh ${bold}_bet ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 0
		
		echo "************************************"
		echo "*** Func smooth ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./12.func_smooth.sh ${bold}_bet ${fdir} ${fwhm} ${mask}
		
		echo "************************************"
		echo "*** Func SPC ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./13.func_spc.sh ${bold}_sm ${fdir}

		# First two outputs
		immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
		immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

	else
		# If breathhold, skip smoothing and denoising!
		for e in $( seq 1 ${nTE} )
		do
			echo "************************************"
			echo "*** Func SPC ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			bold=${flpr}_task-${f}_echo-${e}_bold
			./13.func_spc.sh ${bold}_bet ${fdir}

			# First two outputs
			immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
			immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

		done

		bold=${flpr}_task-${f}_optcom_bold

		echo "************************************"
		echo "*** Func SPC ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./13.func_spc.sh ${bold}_bet ${fdir}

		# First two outputs
		immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
		immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

	fi
done

./funcclearspace.sh ${sub} ${ses} ${wdr} task

echo $(date)
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"