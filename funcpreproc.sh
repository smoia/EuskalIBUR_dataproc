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

TEs="10.6 28.69 46.78 64.87 82.96"
nTE=5

# slice order file (full path to)
siot=none
# siot=${wdr}/sliceorder.txt

dspk=0
jstr=0
moio=0

####################

######################################
######### Script starts here #########
######################################

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${flpr}_log" ]]; then rm ${wdr}/log/${flpr}_log; fi

echo "************************************" >> ${wdr}/log/${flpr}_log

# exec 3>&1 4>&2

# exec 1>${wdr}/log/${flpr}_log 2>&1

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
	for fld in func_preproc fmap_preproc reg  # anat_preproc
	do
		if [[ -d "${fld}" ]]
		then
			if [[ "${fld}" == "func_preproc" ]]
			then
				# backup only the necessary files for meica
				for bck in ${fld}/*_meica
				do
					[[ -e "${bck}" ]] || break
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

./02.anat_skullstrip.sh ${anat2} ${adir} none ${anat1} none

echo "************************************"
echo "*** Anat skullstrip ${anat1}"
echo "************************************"
echo "************************************"

./02.anat_skullstrip.sh ${anat1} ${adir} ${anat1}_brain_mask none ${anat2}

echo "************************************"
echo "*** Anat segment"
echo "************************************"
echo "************************************"

./03.anat_segment.sh ${anat1} ${adir}

./04.anat_normalize.sh ${anat1} ${adir} ${std} ${mmres}

./funcclearspace.sh ${sub} ${ses} ${wdr} anat

######################################
#########    Task preproc    #########
######################################

for f in breathhold  # TASK1 TASK2 TASK3
do 
	for d in AP PA
	do

		echo "************************************"
		echo "*** Func correct ${f} PE ${d}"
		echo "************************************"
		echo "************************************"

		func=${flpr}_acq-${f}_dir-${d}_epi
		./05.func_correct.sh ${func} ${fmap} 0 0 none none none ${siot}
	done

	bfor=${fmap}/${flpr}_acq-${f}_dir-PA_epi
	brev=${fmap}/${flpr}_acq-${f}_dir-AP_epi

	for e in $( seq 1 ${nTE} )
	do

		echo "************************************"
		echo "*** Func correct ${f} SBREF echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-${f}_rec-magnitude_echo-${e}_sbref
		if [[ ! -e ${sbrf}_cr.nii.gz ]]
		then
			./05.func_correct.sh ${sbrf} ${fdir} 0 0 none ${brev} ${bfor} ${siot}
		fi

		echo "************************************"
		echo "*** Func correct ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_echo-${e}_bold
		pepl=${flpr}_task-${f}_rec-magnitude_echo-${e}_sbref_topup
		./05.func_correct.sh ${bold} ${fdir} ${vdsc} 0 ${pepl} ${brev} ${bfor} ${siot}
	done

	echo "************************************"
	echo "*** Func spacecomp ${f} echo 1"
	echo "************************************"
	echo "************************************"

	fmat=${flpr}_task-${f}_echo-1_bold

	./06.func_spacecomp.sh ${fmat} ${fdir} ${vdsc} ${adir}/${anat2} ${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr 0
	
	mask=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain_mask

	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func realign ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-breathhold_rec-magnitude_echo-${e}_sbref_cr
		bold=${flpr}_task-${f}_echo-${e}_bold
		./07.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${vdsc} ${sbrf} ${moio}
	done

	echo "************************************"
	echo "*** Func MEICA ${f} BOLD"
	echo "************************************"
	echo "************************************"

	for e in $( seq 1 ${nTE} )
	do
		bold=${flpr}_task-${f}_echo-${e}_bold_RPI
		./07.func_realign.sh ${bold} ${fmat} 0 ${fdir} 0 0 0 1
	done

	./08.func_meica.sh ${fmat}_RPI_bet ${fdir} "${TEs}" bck
	# ./08.func_meica_melodic.sh ${fmat}_RPI_bet ${fdir} "${TEs}"

	./08.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"

	sbrf=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr
	
	if [[ ${f} != "breathhold" ]]
	then
		# If not breathhold, apply smoothing and denoising.
		for e in $( seq 1 ${nTE} )
		do
			echo "************************************"
			echo "*** Func nuiscomp ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			bold=${flpr}_task-${f}_echo-${e}_bold
			./09.func_nuiscomp.sh ${bold} ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 0
			
			echo "************************************"
			echo "*** Func smooth ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			./10.func_smooth.sh ${bold} ${fdir} ${fwhm} ${mask}
			
			echo "************************************"
			echo "*** Func SPC ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			./11.func_spc.sh ${bold}_sm ${fdir}

			# echo "************************************"
			# echo "*** Func normalise ${f} BOLD echo ${e}"
			# echo "************************************"
			# echo "************************************"

			# ./12.func_normalize.sh ${bold}_sm ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

			# ./11.func_spc.sh ${bold}_sm_norm ${fdir}

			immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
			immv ${fdir}/${bold}_sm_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
			# immv ${fdir}/${bold}_sm_norm ${fdir}/02.${bold}_std_preprocessed
			# immv ${fdir}/${bold}_sm_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

		done

		echo "************************************"
		echo "*** Func nuiscomp ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_optcom_bold
		./09.func_nuiscomp.sh ${bold} ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 0
		
		echo "************************************"
		echo "*** Func smooth ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./10.func_smooth.sh ${bold} ${fdir} ${fwhm} ${mask}
		
		echo "************************************"
		echo "*** Func SPC ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./11.func_spc.sh ${bold}_sm ${fdir}

		# echo "************************************"
		# echo "*** Func normalise ${f} BOLD optcom"
		# echo "************************************"
		# echo "************************************"

		# ./12.func_normalize.sh ${bold}_sm ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

		# ./11.func_spc.sh ${bold}_norm ${fdir}

		immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
		immv ${fdir}/${bold}_sm_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
		# immv ${fdir}/${bold}_sm_norm ${fdir}/02.${bold}_std_preprocessed
		# immv ${fdir}/${bold}_sm_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

	else
		# If breathhold, skip smoothing and denoising!
		for e in $( seq 1 ${nTE} )
		do
			echo "************************************"
			echo "*** Func SPC ${f} BOLD echo ${e}"
			echo "************************************"
			echo "************************************"

			bold=${flpr}_task-${f}_echo-${e}_bold
			./11.func_spc.sh ${bold}_bet ${fdir}

			# echo "************************************"
			# echo "*** Func normalise ${f} BOLD echo ${e}"
			# echo "************************************"
			# echo "************************************"

			# ./12.func_normalize.sh ${bold}_bet ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

			# ./11.func_spc.sh ${bold}_bet_norm ${fdir}

			immv ${fdir}/${bold}_bet ${fdir}/00.${bold}_native_preprocessed
			immv ${fdir}/${bold}_bet_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
			# immv ${fdir}/${bold}_bet_norm ${fdir}/02.${bold}_std_preprocessed
			# immv ${fdir}/${bold}_bet_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

		done

		bold=${flpr}_task-${f}_optcom_bold

		echo "************************************"
		echo "*** Func SPC ${f} BOLD optcom"
		echo "************************************"
		echo "************************************"

		./11.func_spc.sh ${bold}_bet ${fdir}

		# echo "************************************"
		# echo "*** Func normalise ${f} BOLD optcom"
		# echo "************************************"
		# echo "************************************"

		# ./12.func_normalize.sh ${bold}_bet ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

		# ./11.func_spc.sh ${bold}_bet_norm ${fdir}

		immv ${fdir}/${bold}_bet ${fdir}/00.${bold}_native_preprocessed
		immv ${fdir}/${bold}_bet_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
		# immv ${fdir}/${bold}_bet_norm ${fdir}/02.${bold}_std_preprocessed
		# immv ${fdir}/${bold}_bet_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

	fi

./funcclearspace.sh ${sub} ${ses} ${wdr} task

done


######################################
#########    Rest preproc    #########
######################################

for r in 01 # $( seq -f %02g 1 4 )
do 
	for d in AP PA
	do

		echo "************************************"
		echo "*** Func correct rest PE ${d}"
		echo "************************************"
		echo "************************************"

		func=${flpr}_acq-rest_dir-${d}_run-${r}_epi
		./05.func_correct.sh ${func} ${fmap} 0 0 none none none ${siot}
	done

	bfor=${fmap}/${flpr}_acq-rest_dir-PA_run-${r}_epi
	brev=${fmap}/${flpr}_acq-rest_dir-AP_run-${r}_epi

	for e in $( seq 1 ${nTE} )
	do

		echo "************************************"
		echo "*** Func correct rest SBREF echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-rest_rec-magnitude_run-${r}_echo-${e}_sbref
		if [[ ! -e ${sbrf}_cr.nii.gz ]]
		then
			./05.func_correct.sh ${sbrf} ${fdir} 0 0 none ${brev} ${bfor} ${siot}
		fi

		echo "************************************"
		echo "*** Func correct rest BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-rest_run-${r}_echo-${e}_bold
		pepl=${flpr}_task-rest_rec-magnitude_run-${r}_echo-${e}_sbref_topup
		./05.func_correct.sh ${bold} ${fdir} ${vdsc} 0 ${pepl} ${brev} ${bfor} ${siot}
	done

	echo "************************************"
	echo "*** Func spacecomp rest echo 1"
	echo "************************************"
	echo "************************************"

	fmat=${flpr}_task-rest_run-${r}_echo-1_bold

	./06.func_spacecomp.sh ${fmat} ${fdir} ${vdsc} ${adir}/${anat2} ${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr 0
	
	mask=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr_brain_mask

	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func realign rest BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-breathhold_rec-magnitude_echo-${e}_sbref_cr
		bold=${flpr}_task-rest_run-${r}_echo-${e}_bold
		./07.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${vdsc} ${sbrf} ${moio}
	done

	echo "************************************"
	echo "*** Func MEICA rest BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	for e in $( seq 1 ${nTE} )
	do
		bold=${flpr}_task-rest_run-${r}_echo-${e}_bold_RPI
		./07.func_realign.sh ${bold} ${fmat} 0 ${fdir} 0 0 0 1
	done

	./08.func_meica.sh ${fmat}_RPI_bet ${fdir} "${TEs}" bck

	./08.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"

	sbrf=${flpr}_task-breathhold_rec-magnitude_echo-1_sbref_cr
	
	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func nuiscomp rest BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-rest_run-${r}_echo-${e}_bold
		./09.func_nuiscomp.sh ${bold} ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 1
		
		echo "************************************"
		echo "*** Func smooth rest BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		./10.func_smooth.sh ${bold} ${fdir} ${fwhm} ${mask}
		
		echo "************************************"
		echo "*** Func SPC rest BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		./11.func_spc.sh ${bold}_sm ${fdir}

		# echo "************************************"
		# echo "*** Func normalise rest BOLD echo ${e}"
		# echo "************************************"
		# echo "************************************"

		# ./12.func_normalize.sh ${bold}_sm ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

		# ./11.func_spc.sh ${bold}_sm_norm ${fdir}

		immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
		immv ${fdir}/${bold}_sm_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
		# immv ${fdir}/${bold}_sm_norm ${fdir}/02.${bold}_std_preprocessed
		# immv ${fdir}/${bold}_sm_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

	done

	echo "************************************"
	echo "*** Func nuiscomp rest BOLD optcom"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-rest_run-${r}_optcom_bold
	# #!# !!! Skipping Denoising in optcom for Liu P et al 2017 Neuroimage replication!
	./09.func_nuiscomp.sh ${bold} ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 0
	# ./09.func_nuiscomp.sh ${bold} ${fmat} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 1
	
	echo "************************************"
	echo "*** Func smooth rest BOLD optcom"
	echo "************************************"
	echo "************************************"

	./10.func_smooth.sh ${bold} ${fdir} ${fwhm} ${mask}
	
	echo "************************************"
	echo "*** Func SPC rest BOLD optcom"
	echo "************************************"
	echo "************************************"

	./11.func_spc.sh ${bold}_sm ${fdir}

	# echo "************************************"
	# echo "*** Func normalise rest BOLD optcom"
	# echo "************************************"
	# echo "************************************"

	# ./12.func_normalize.sh ${bold}_sm ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

	# ./11.func_spc.sh ${bold}_sm_norm ${fdir}

	immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
	immv ${fdir}/${bold}_sm_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
	# immv ${fdir}/${bold}_sm_norm ${fdir}/02.${bold}_std_preprocessed
	# immv ${fdir}/${bold}_sm_norm_SPC ${fdir}/03.${bold}_std_SPC_preprocessed

./funcclearspace.sh ${sub} ${ses} ${wdr} rest

done

echo $(date)
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"