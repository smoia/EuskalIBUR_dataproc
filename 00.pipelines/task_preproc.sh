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

anat=${5:-none}
aseg=${6:-none}

fdir=$7

vdsc=$8

TEs="$9"
nTE=${10}

siot=${11}

dspk=${12}

scriptdir=${13:-/scripts}

tmp=${14:-/tmp}
tmp=${tmp}/${sub}_${ses}_${task}

# This is the absolute sbref. Don't change it.
sbrf=${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
mask=${sbrf}_brain_mask
flpr=sub-${sub}_ses-${ses}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
#########    Task preproc    #########
######################################

# Start making the tmp folder
mkdir ${tmp}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Copy ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	echo "bold=${flpr}_task-${task}_echo-${e}_bold"
	bold=${flpr}_task-${task}_echo-${e}_bold

	echo "imcp ${wdr}/sub-${sub}/ses-${ses}/func/${bold} ${tmp}/${bold}"
	imcp ${wdr}/sub-${sub}/ses-${ses}/func/${bold} ${tmp}/${bold}

	if [ ! -e ${tmp}/${bold}.nii.gz ]
	then
		echo "Something went wrong with the copy"
		exit
	else
		echo "File copied, start preprocessing"
	fi

	echo "************************************"
	echo "*** Func correct ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	${scriptdir}/02.func_preproc/01.func_correct.sh ${bold} ${fdir} ${vdsc} ${dspk} ${siot} ${tmp}
done

echo "************************************"
echo "*** Func spacecomp ${task} echo 1"
echo "************************************"
echo "************************************"

echo "fmat=${flpr}_task-${task}_echo-1_bold"
fmat=${flpr}_task-${task}_echo-1_bold

${scriptdir}/02.func_preproc/03.func_spacecomp.sh ${fmat}_cr ${fdir} ${anat} ${sbrf} none ${aseg} ${tmp}

for e in $( seq 1 ${nTE} )
do
	echo "************************************"
	echo "*** Func realign ${task} BOLD echo ${e}"
	echo "************************************"
	echo "************************************"

	echo "bold=${flpr}_task-${task}_echo-${e}_bold_cr"
	bold=${flpr}_task-${task}_echo-${e}_bold_cr
	${scriptdir}/02.func_preproc/04.func_realign.sh ${bold} ${fmat} ${mask} ${fdir} ${sbrf} none ${tmp}

	echo "************************************"
	echo "*** Func greyplot ${task} BOLD echo ${e} (pre)"
	echo "************************************"
	echo "************************************"
	echo "bold=${flpr}_task-${task}_echo-${e}_bold_bet"
	bold=${flpr}_task-${task}_echo-${e}_bold_bet
	${scriptdir}/02.func_preproc/12.func_grayplot.sh ${bold} ${fdir} ${anat} ${sbrf} ${aseg} 4 ${tmp}
done

echo "************************************"
echo "*** Func MEICA ${task} BOLD"
echo "************************************"
echo "************************************"

${scriptdir}/02.func_preproc/05.func_meica.sh ${fmat}_bet ${fdir} "${TEs}" none ${tmp} ${scriptdir}

echo "************************************"
echo "*** Func T2smap ${task} BOLD"
echo "************************************"
echo "************************************"
# Since t2smap gives different results from tedana, prefer the former for optcom
${scriptdir}/02.func_preproc/06.func_optcom.sh ${fmat}_bet ${fdir} "${TEs}" ${tmp}

# As it's ${task}, only skip denoising (but create matrix nonetheless)!
for e in $( seq 1 ${nTE}; echo "optcom" )
do
	if [ ${e} != "optcom" ]
	then
		e=echo-${e}
	fi
	echo "bold=${flpr}_task-${task}_${e}_bold"
	bold=${flpr}_task-${task}_${e}_bold
	
	echo "************************************"
	echo "*** Func Nuiscomp ${task} BOLD ${e}"
	echo "************************************"
	echo "************************************"

	${scriptdir}/02.func_preproc/07.func_nuiscomp.sh ${bold}_bet ${fmat} ${anat} ${aseg} ${sbrf} ${fdir} none no 0.3 0.05 4 yes yes yes yes ${tmp}
	
	echo "************************************"
	echo "*** Func Pepolar ${task} BOLD ${e}"
	echo "************************************"
	echo "************************************"

	${scriptdir}/02.func_preproc/02.func_pepolar.sh ${bold}_bet ${fdir} ${sbrf}_topup none none ${tmp}

	echo "************************************"
	echo "*** Func smoothing ${task} BOLD ${e}"
	echo "************************************"
	echo "************************************"

	${scriptdir}/02.func_preproc/08.func_smooth.sh ${bold}_tpp ${fdir} 5 ${mask} ${tmp}
	echo "3dcalc -a ${tmp}/${bold}_sm.nii.gz -b ${mask}.nii.gz -expr 'a*b' -prefix ${fdir}/00.${bold}_native_preprocessed.nii.gz -short -gscale"
	3dcalc -a ${tmp}/${bold}_sm.nii.gz -b ${mask}.nii.gz -expr 'a*b' -prefix ${fdir}/00.${bold}_native_preprocessed.nii.gz -short -gscale

	echo "************************************"
	echo "*** Func greyplot rest run ${run} BOLD ${e} (post)"
	echo "************************************"
	echo "************************************"
	${scriptdir}/02.func_preproc/12.func_grayplot.sh ${bold}_sm ${fdir} ${anat} ${sbrf} ${aseg} 4 ${tmp}
	echo "mv ${fdir}/${bold}_sm_gp_PVO.png ${fdir}/00.${bold}_native_preprocessed_gp_PVO.png"
	mv ${fdir}/${bold}_sm_gp_PVO.png ${fdir}/00.${bold}_native_preprocessed_gp_PVO.png
	echo "mv ${fdir}/${bold}_sm_gp_IJK.png ${fdir}/00.${bold}_native_preprocessed_gp_IJK.png"
	mv ${fdir}/${bold}_sm_gp_IJK.png ${fdir}/00.${bold}_native_preprocessed_gp_IJK.png
	echo "mv ${fdir}/${bold}_sm_gp_peel.png ${fdir}/00.${bold}_native_preprocessed_gp_peel.png"
	mv ${fdir}/${bold}_sm_gp_peel.png ${fdir}/00.${bold}_native_preprocessed_gp_peel.png

	# echo "************************************"
	# echo "*** Func SPC ${task} BOLD ${e}"
	# echo "************************************"
	# echo "************************************"

	# ${scriptdir}/02.func_preproc/09.func_spc.sh ${bold}_sm ${fdir} ${tmp}

	# # Rename output
	# echo "immv ${tmp}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed"
	# immv ${tmp}/${bold}_SPC ${fdir}/01.${bold}_native_SPC_preprocessed

done

echo "rm -rf ${tmp}"
rm -rf ${tmp}