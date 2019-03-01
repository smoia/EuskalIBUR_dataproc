#!/usr/bin/env bash

######### FULL PREPROC for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

# sub=$1
# ses=$2
sub=001
ses=01

flpr=sub-${sub}_ses-${ses}

# wdr=$3
wdr=/home/nemo/Nextcloud/PJMASKTEST

anat1=${flpr}_acq-uni_T1w 
anat2=${flpr}_T2w

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
fmap=${wdr}/sub-${sub}/ses-${ses}/fmap_preproc

vdsc=10
std=MNI152_2009_template
mmres=2.5
fwhm=6

TEs='[10.6,28.69,46.78,64.87,82.96]'
nTE=5

dspk=0
jstr=0
moio=0

####################

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/sub-${sub}/ses-${ses}

echo "************************************"
echo "*** Preparing folders"
echo "************************************"
echo "************************************"

for fld in anat_preproc func_preproc fmap_preproc reg
do
	if [[ -d "${fld}" ]]; then rm -r ${fld}; fi
	mkdir ${fld}
done

ln -s func/* func_preproc/.
imcp anat/${anat1} anat_preproc/.
imcp anat/${anat2} anat_preproc/.
imcp fmap/* fmap_preproc/.

cd ${cwd}

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

./02.anat_skullstrip.sh ${anat2} ${adir} none ${anat1}

echo "************************************"
echo "*** Anat skullstrip ${anat1}"
echo "************************************"
echo "************************************"

./02.anat_skullstrip.sh ${anat1} ${adir} ${anat1}_brain_mask

echo "************************************"
echo "*** Anat segment"
echo "************************************"
echo "************************************"

./03.anat_segment.sh ${anat1} ${adir}

# ./04.anat_normalize.sh ${anat1} ${adir} ${std} ${mmres}

for f in breathhold rest_run-01 rest_run-02
do 
	for d in AP PA
	do

		echo "************************************"
		echo "*** Func correct ${f} PE ${d}"
		echo "************************************"
		echo "************************************"

		func=${flpr}_dir-${d}_task-${f}_epi
		./05.func_correct.sh ${func} ${fmap} 0 0 none none none
	done

	bfor=${fmap}/${flpr}_dir-AP_task-${f}_epi
	brev=${fmap}/${flpr}_dir-PA_task-${f}_epi

	for e in $( seq 1 ${nTE} )
	do

		echo "************************************"
		echo "*** Func correct ${f} SBREF echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-breathhold_echo-${e}_sbref
		./05.func_correct.sh ${sbrf} ${fdir} 0 0 none ${brev} ${bfor}

		echo "************************************"
		echo "*** Func correct ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_echo-${e}_bold
		pepl=${flpr}_task-${f}_echo-${e}_pepolar
		./05.func_correct.sh ${bold} ${fdir} ${vdsc} 0 ${pepl} ${brev} ${bfor}
	done
 	# Maybe echo 3? BUT echo 1 for anat realign

	echo "************************************"
	echo "*** Func spacecomp ${f} echo 1"
	echo "************************************"
	echo "************************************"

	./06.func_spacecomp.sh ${flpr}_task-${f}_echo-1_bold ${fdir} ${vdsc} ${anat2} ${flpr}_task-breathhold_echo-1_sbref 0

	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func realign ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		sbrf=${flpr}_task-breathhold_echo-${e}_sbref
		bold=${flpr}_task-${f}_echo-${e}_bold
		./07.func_realign.sh ${bold} ${fdir} ${vdsc} ${sbrf} ${moio}
	done

	echo "************************************"
	echo "*** Func MEICA ${f} BOLD"
	echo "************************************"
	echo "************************************"

	./08.func_meica.sh ${flpr}_task-${f}_echo-1_bold ${fdir} ${TEs}

	sbrf=${flpr}_task-breathhold_echo-1_sbref
	
	for e in $( seq 1 ${nTE} )
	do
		echo "************************************"
		echo "*** Func nuiscomp ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		bold=${flpr}_task-${f}_echo-${e}_bold
		if [[ "${f}" == *task-rest* ]]
		then
			./09.func_nuiscomp.sh ${bold} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 1
		else
			./09.func_nuiscomp.sh ${bold} ${anat1} ${anat2} ${sbrf} ${fdir} ${adir} 0
		fi
		
		echo "************************************"
		echo "*** Func smooth ${f} BOLD echo ${e}"
		echo "************************************"
		echo "************************************"

		./10.func_smooth.sh ${bold} ${fdir} ${fwhm}

		# SPC

		# ./11.func_normalize.sh ${bold} ${anat} ${sbrf} ${std} ${fdir} ${mmres} ${anat2}

		# SPC

	done

done

