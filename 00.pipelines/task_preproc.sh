#!/usr/bin/env bash

######### Task preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    25.08.2020
#########


sub=$1
ses=$2
task=$3
wdr=$4

flpr=$5

fdir=$6

vdsc=$7

TEs="$8"
nTE=$9

siot=${10}

dspk=${11}

tmp=${12:-/tmp}
tmp=${tmp}/${sub}_${ses}_${task}

# This is the absolute sbref. Don't change it.
sbrf=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
mask=${sbrf}_brain_mask

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
#########    Task preproc    #########
######################################

# Start making the tmp folder
mkdir ${tmp}

for e in  $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func correct ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-${task}_echo-${e}_bold
	/scripts/02.func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot} ${tmp}
done

echo "************************************"
echo "*** Func spacecomp ${task} echo 1"
echo "************************************"
echo "************************************"

fmat=${flpr}_task-${task}_echo-1_bold

/scripts/02.func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} none ${sbrf} none none ${tmp}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-${task}_echo-${e}_bold_cr
	/scripts/02.func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf} none ${tmp}
done

echo "************************************"
echo "*** Func MEICA ${task} BOLD"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}" ${tmp}

# As it's ${task}, don't skip smoothing and denoising!
for e in $( seq 1 ${nTE} )
do
	bold=${flpr}_task-${task}_echo-${e}_bold
	
	echo "************************************"
	echo "*** Func Nuiscomp ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/07.func_nuiscomp.sh ${bold}_bet ${fmat} none none ${sbrf} ${fdir} none no 0.3 0.05 no no ${tmp}
	
	echo "************************************"
	echo "*** Func Pepolar ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_den ${fdir} ${sbrf}_topup none none ${tmp}

	echo "************************************"
	echo "*** Func smoothing ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/08.func_smooth.sh ${bold}_tpp ${fdir} 5 ${mask} ${tmp}
	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

	echo "************************************"
	echo "*** Func SPC ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir} ${tmp}

	# Rename output
	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

done

# Repeat part of it for optcom
bold=${flpr}_task-${task}_optcom_bold

echo "************************************"
echo "*** Func Nuiscomp ${task} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/07.func_nuiscomp.sh ${bold}_bet ${fmat} none none ${sbrf} ${fdir} none yes 0.3 0.05 yes

echo "************************************"
echo "*** Func Pepolar ${task} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_den ${fdir} ${sbrf}_topup

echo "************************************"
echo "*** Func smoothing ${task} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/08.func_smooth.sh ${bold}_tpp ${fdir} 3 ${mask}

echo "************************************"
echo "*** Func SPC ${task} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

# Rename output
immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed


/scripts/00.pipelines/clearspace.sh ${sub} ${ses} ${wdr} task
