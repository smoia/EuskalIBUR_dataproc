#!/usr/bin/env bash

######### BreathHold preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
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
	echo "*** Func correct breathhold BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-breathhold_echo-${e}_bold
	/scripts/02.func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot}
done

echo "************************************"
echo "*** Func spacecomp breathhold echo 1"
echo "************************************"
echo "************************************"

fmat=${flpr}_task-breathhold_echo-1_bold

/scripts/02.func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} none ${sbrf}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign breathhold BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-breathhold_echo-${e}_bold_cr
	/scripts/02.func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf}
done

echo "************************************"
echo "*** Func MEICA breathhold BOLD"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/05.func_meica.sh ${fmat}_bet ${fdir} "${TEs}" bck

/scripts/02.func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"
	

# As it's breathhold, skip smoothing and denoising!
for e in $( seq 1 ${nTE}; echo "optcom" )
do
	if [ ${e} != "optcom" ]
	then
		e=echo-${e}
	fi
	bold=${flpr}_task-breathhold_${e}_bold
	
	echo "************************************"
	echo "*** Func Pepolar breathhold BOLD ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_bet ${fdir} ${sbrf}_topup

	echo "************************************"
	echo "*** Func SPC breathhold BOLD ${e}"
	echo "************************************"
	echo "************************************"

	/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

	# First two outputs
	immv ${fdir}/${bold}_tpp ${fdir}/00.${bold}_native_preprocessed
	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

done

/scripts/00.pipelines/clearspace.sh ${sub} ${ses} ${wdr} task
