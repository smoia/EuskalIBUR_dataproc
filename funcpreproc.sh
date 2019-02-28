#!/usr/bin/env bash

######### FULL PREPROC for PJMASK
# Author:  Stefano Moia
# Version: 0.1
# Date:    06.02.2019
#########

sub=$1
ses=$2

wdr=$3

func=
mref=

adir=${wdr}/sub-${sub}/ses-${ses}/anat_preproc
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc

vdsc=10
std=MNI152_2009_template
mmres=2.5
fwhm=6

TEs='[43234]'
pepl=
brev=
bfor=

dspk=0
jstr=0
moio=1


####################

dprj=
mask=

######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/sub-${sub}/ses-${ses}

mkdir anat_preproc func_preproc reg

cd ${cwd}

anat1=sub-${sub}_ses-${ses}_T1 
anat2=sub-${sub}_ses-${ses}_T2

01.anat_correct.sh ${anat1} ${adir}
01.anat_correct.sh ${anat2} ${adir} ${anat1}

02.anat_skullstrip.sh ${anat2} ${adir} none ${anat1}
02.anat_skullstrip.sh ${anat1} ${adir} ${anat1}_brain_mask

03.anat_segment.sh ${anat1} ${adir}

# 04.anat_normalize.sh ${anat1} ${adir} ${std} ${mmres}


for f in 
do
	brev
	bfor
	sbref

	05.func_correct.sh
	05.func_correct.sh 
	05.func_correct.sh 
done

06.func_spacecomp.sh $$$echo2 ${fdir} ${vdsc} ${anat2} $$$sbref 0

for e in 
do
	07.func_realign.sh 
done

08.func_meica.sh $$$echo1 ${fdir} ${TEs}

for f in
do
	if [[ "${f}" == *"task-rest"* ]]
	then
		09.func_nuiscomp.sh ${f} ${anat1} ${anat2} $$$sbref ${fdir} ${adir} 1
	else
		09.func_nuiscomp.sh ${f} ${anat1} ${anat2} $$$sbref ${fdir} ${adir} 0
	fi
	
	10.func_smooth.sh ${f} ${fdir} ${fwhm}

	# 11.func_normalize.sh ${f} ${anat} $$$sbref ${std} ${fdir} ${mmres} ${anat2}
done


