#!/usr/bin/env bash

######### FULL PREPROC for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########


sub=$1
ses=$2


flpr=sub-${sub}_ses-${ses}

wdr=/scratch/smoia

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc
stdp=${wdr}/pjmask_preproc

nTE=5

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
echo "***    Cleaning ${flpr}   ***"
echo "************************************"
echo "************************************"
echo ""

echo "************************************"
echo "*** Anat clean ${anat1}"
echo "************************************"
echo "************************************"

./98.anat_delete.sh ${adir} ${anat1}
./98.anat_delete.sh ${adir} ${anat2}

for f in breathhold #TASK1 TASK2 TASK3
do 
	for d in AP PA
	do

		echo "************************************"
		echo "*** Fmap clean ${f} PE ${d}"
		echo "************************************"
		echo "************************************"

		func=${flpr}_acq-${f}_dir-${d}_epi
		./99.fmap_delete.sh ${fmap} ${func}
	done

	for e in $( seq 1 ${nTE} )
	do

		echo "************************************"
		echo "*** Func clean ${f} echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-${f}_rec-magnitude_echo-${e}_sbref
		bold=${flpr}_task-${f}_echo-${e}_bold
		./97.func_delete.sh ${fdir} ${sbrf}
		./97.func_delete.sh ${fdir} ${bold}

	done

	echo "************************************"
	echo "*** MEICA clean ${f}"
	echo "************************************"
	echo "************************************"

	./96.meica_delete.sh ${fdir} ${flpr}_task-${f}_echo-1_bold_RPI_bet

done
