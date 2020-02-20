#!/usr/bin/env bash

######### FULL PREPROC for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########


sub=$1
ses=$2
wdr=${3:-/data}
part=${4:-all}
# part can be anat, rest, task, all

flpr=sub-${sub}_ses-${ses}

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
pdir=${wdr}/sub-${sub}/ses-${ses}/func_phys
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc

nTE=5

####################

######################################
######### Script starts here #########
######################################

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${flpr}_log_clear" ]]; then rm ${wdr}/log/${flpr}_log_clear; fi

echo "************************************" >> ${wdr}/log/${flpr}_log_clear

exec 3>&1 4>&2

exec 1>${wdr}/log/${flpr}_log_clear 2>&1

date
echo "************************************"

# saving the current wokdir
cwd=$(pwd)

echo "************************************"
echo "***    Cleaning ${flpr}   ***"
echo "************************************"
echo "************************************"
echo ""
echo "Selected to clean: ${part}"
echo ""

if [[ ${part} == "anat" || ${part} == "all" ]]
then

	echo "************************************"
	echo "*** Anat clean ${anat1}"
	echo "************************************"
	echo "************************************"

	/scripts/99.cleaning/04.anat_delete.sh ${adir} ${anat1}
	/scripts/99.cleaning/04.anat_delete.sh ${adir} ${anat2}
fi

if [[ ${part} == "phys" || ${part} == "all" ]]
then

	echo "************************************"
	echo "*** Physio clean"
	echo "************************************"
	echo "************************************"

	/scripts/99.cleaning/01.physio_delete.sh ${pdir}
fi

if [[ ${part} == "task" || ${part} == "all" ]]
then

	for f in breathhold TASK1 TASK2 TASK3
	do 
		for d in AP PA
		do

			echo "************************************"
			echo "*** Fmap clean ${f} PE ${d}"
			echo "************************************"
			echo "************************************"

			func=${flpr}_acq-${f}_dir-${d}_epi
			/scripts/99.cleaning/05.fmap_delete.sh ${fmap} ${func}
		done

		for e in $( seq 1 ${nTE} )
		do

			echo "************************************"
			echo "*** Func clean ${f} echo ${e}"
			echo "************************************"
			echo "************************************"

			sbrf=${flpr}_task-${f}_rec-magnitude_echo-${e}_sbref
			bold=${flpr}_task-${f}_echo-${e}_bold
			/scripts/99.cleaning/03.func_delete.sh ${fdir} ${sbrf}
			/scripts/99.cleaning/03.func_delete.sh ${fdir} ${bold}

		done

		echo "************************************"
		echo "*** Func clean ${f} optcom"
		echo "************************************"
		echo "************************************"

		/scripts/99.cleaning/03.func_delete.sh ${fdir} ${flpr}_task-${f}_optcom_bold

		echo "************************************"
		echo "*** MEICA clean ${f}"
		echo "************************************"
		echo "************************************"

		/scripts/99.cleaning/02.meica_delete.sh ${fdir} ${flpr}_task-${f}_echo-1_bold_RPI_bet

	done

fi

# Rest

if [[ ${part} == "rest" || ${part} == "all" ]]
then

	for r in $( seq -f %02g 1 4 )
	do 
		for d in AP PA
		do

			echo "************************************"
			echo "*** Fmap clean rest run ${r} PE ${d}"
			echo "************************************"
			echo "************************************"

			func=${flpr}_acq-rest_dir-${d}_run-${r}_epi
			/scripts/99.cleaning/05.fmap_delete.sh ${fmap} ${func}
		done

		for e in $( seq 1 ${nTE} )
		do

			echo "************************************"
			echo "*** Func clean rest run ${r} echo ${e}"
			echo "************************************"
			echo "************************************"

			sbrf=${flpr}_task-rest_rec-magnitude_run-${r}_echo-${e}_sbref
			bold=${flpr}_task-rest_run-${r}_echo-${e}_bold
			/scripts/99.cleaning/03.func_delete.sh ${fdir} ${sbrf}
			/scripts/99.cleaning/03.func_delete.sh ${fdir} ${bold}

		done

		echo "************************************"
		echo "*** MEICA clean rest run ${r}"
		echo "************************************"
		echo "************************************"

		/scripts/99.cleaning/02.meica_delete.sh ${fdir} ${flpr}_task-rest_run-${r}_echo-1_bold_RPI_bet

	done

fi

cd ${cwd}