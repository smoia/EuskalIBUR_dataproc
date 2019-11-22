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

anat2=$5

adir=$6
fdir=$7

vdsc=$8

TEs=$9
nTE=${10}

siot=${11}

dspk=${12}

# This is the absolute sbref. Don't change it.
sbrf=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
mask=${sbrf}_brain_mask

######################################
#########    Task preproc    #########
######################################

for e in  $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func correct ${f} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-${f}_echo-${e}_bold
	func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot}
done

echo "************************************"
echo "*** Func spacecomp ${f} echo 1"
echo "************************************"
echo "************************************"

fmat=${flpr}_task-${f}_echo-1_bold

func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} ${vdsc} ${adir}/${anat2} ${sbrf}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign ${f} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-${f}_echo-${e}_bold_cr
	func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf}
done

echo "************************************"
echo "*** Func MEICA ${f} BOLD"
echo "************************************"
echo "************************************"

func_preproc/05.func_meica.sh ${fmat}_bet ${fdir} "${TEs}" bck

func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}"
	
#####
####   Applytopup here!
##

# As it's breathhold, skip smoothing and denoising!
for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func SPC ${f} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	bold=${flpr}_task-${f}_echo-${e}_bold
	func_preproc/09.func_spc.sh ${bold}_bet ${fdir}

	# First two outputs
	immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
	immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

done

bold=${flpr}_task-${f}_optcom_bold

echo "************************************"
echo "*** Func SPC ${f} BOLD optcom"
echo "************************************"
echo "************************************"

func_preproc/09.func_spc.sh ${bold}_bet ${fdir}

# First two outputs
immv ${fdir}/${bold}_sm ${fdir}/00.${bold}_native_preprocessed
immv ${fdir}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed


./clearspace.sh ${sub} ${ses} ${wdr} task

echo $(date)
echo "************************************"
echo "************************************"
echo "***      Preproc COMPLETE!       ***"
echo "************************************"
echo "************************************"