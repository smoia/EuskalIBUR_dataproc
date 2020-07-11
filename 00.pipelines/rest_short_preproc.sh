#!/usr/bin/env bash

######### rest_run-${run} preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2
run=$3
wdr=$4

flpr=$5

fdir=$6

vdsc=$7

TEs="$8"
nTE=$9

siot=${10}

dspk=${11}

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
	echo "*** Func correct rest_run-${run} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-rest_run-${run}_echo-${e}_bold
	/scripts/02.func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot}
done

echo "************************************"
echo "*** Func spacecomp rest_run-${run} echo 1"
echo "************************************"
echo "************************************"

fmat=${flpr}_task-rest_run-${run}_echo-1_bold

/scripts/02.func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} none ${sbrf}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign rest_run-${run} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-rest_run-${run}_echo-${e}_bold_cr
	/scripts/02.func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf}
done

echo "************************************"
echo "*** Func MEICA rest_run-${run} BOLD"
echo "************************************"
echo "************************************"

# /scripts/02.func_preproc/05.func_meica.sh ${fmat}_bet ${fdir} "${TEs}" bck

/scripts/02.func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"
	

# # As it's rest_run-${run}, skip smoothing and denoising!
# for e in $( seq 1 ${nTE} )
# do
# 	bold=${flpr}_task-rest_run-${run}_echo-${e}_bold
	
# 	echo "************************************"
# 	echo "*** Func Pepolar rest_run-${run} BOLD echo ${e}"
# 	echo "************************************"
# 	echo "************************************"

# 	/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_bet ${fdir} ${sbrf}_topup

# 	echo "************************************"
# 	echo "*** Func SPC rest_run-${run} BOLD echo ${e}"
# 	echo "************************************"
# 	echo "************************************"

# 	/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

# 	# First two outputs
# 	immv ${fdir}/${bold}_tpp ${fdir}/00.${bold}_native_preprocessed
# 	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

# done

bold=${flpr}_task-rest_run-${run}_optcom_bold

echo "************************************"
echo "*** Func Pepolar rest_run-${run} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/02.func_pepolar.sh ${bold}_bet ${fdir} ${sbrf}_topup

echo "************************************"
echo "*** Func SPC rest_run-${run} BOLD optcom"
echo "************************************"
echo "************************************"

/scripts/02.func_preproc/09.func_spc.sh ${bold}_tpp ${fdir}

# First two outputs
immv ${fdir}/${bold}_tpp ${fdir}/00.${bold}_native_preprocessed
immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed


/scripts/00.pipelines/clearspace.sh ${sub} ${ses} ${wdr} rest
