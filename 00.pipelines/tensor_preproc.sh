#!/usr/bin/env bash

######### Motor preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    25.08.2020
#########


sub=$1
ses=$2
wdr=$3

flpr=$4

fdir=$5

vdsc=$6

TEs="$7"
nTE=$8

siot=$9

dspk=${10}

# This is the absolute sbref. Don't change it.
sbrf=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
mask=${sbrf}_brain_mask

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
#########    Task preproc    #########
######################################

for e in  $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func correct motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-motor_echo-${e}_bold
	/scripts/02.func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot}
done

echo "************************************"
echo "*** Func spacecomp motor echo 1"
echo "************************************"
echo "************************************"

fmat=${flpr}_task-motor_echo-1_bold

/scripts/02.func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} none ${sbrf}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-motor_echo-${e}_bold_cr
	/scripts/02.func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf}
done

echo "************************************"
echo "*** Func MEICA motor BOLD"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"

# As it's motor, don't skip smoothing and denoising!
for e in $( seq 1 ${nTE} )
do
	bold=${flpr}_task-motor_echo-${e}_bold
	
	echo "************************************"
	echo "*** Func Nuiscomp motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/07.func_nuiscomp.sh ${bold}_bet ${fmat} none none ${sbrf} ${fdir} none
	
	echo "************************************"
	echo "*** Func Pepolar motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_den ${fdir} ${sbrf}_topup

	echo "************************************"
	echo "*** Func smoothing motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/08.func_smooth.sh ${bold}_tpp ${fdir} 3 ${mask}

	echo "************************************"
	echo "*** Func SPC motor BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

	# Rename output
	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

done

# Repeat part of it for optcom
bold=${flpr}_task-motor_optcom_bold

echo "************************************"
echo "*** Func Nuiscomp motor BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/07.func_nuiscomp.sh ${bold}_bet ${fmat} none none ${sbrf} ${fdir} none yes 0.3 0.05 yes

echo "************************************"
echo "*** Func Pepolar motor BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_den ${fdir} ${sbrf}_topup

echo "************************************"
echo "*** Func smoothing motor BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/08.func_smooth.sh ${bold}_tpp ${fdir} 3 ${mask}

echo "************************************"
echo "*** Func SPC motor BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

# Rename output
immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed


/scripts/00.pipelines/clearspace.sh ${sub} ${ses} ${wdr} task
