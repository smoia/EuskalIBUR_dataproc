#!/usr/bin/env bash

######### Anat preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########

anat1=$1
anat2=$2

adir=$3

std=$4
mmres=$5

sdr=${6:-/scripts}
tmp=${7:-/tmp}

### print input
printline=$( basename -- $0 )
echo "${printline}" "$@"
######################################
#########    Anat preproc    #########
######################################

echo "************************************"
echo "*** Anat correction ${anat1}"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/01.anat_correct.sh ${tmp}/${anat1} ${adir} none ${tmp}

echo "************************************"
echo "*** Anat correction ${anat2}"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/01.anat_correct.sh ${tmp}/${anat2} ${adir} ${tmp}/${anat1} ${tmp}

echo "************************************"
echo "*** Anat skullstrip ${anat2}"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/02.anat_skullstrip.sh ${tmp}/${anat2}_bfc ${adir} none ${anat1} none

echo "************************************"
echo "*** Anat skullstrip ${anat1}"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/02.anat_skullstrip.sh ${tmp}/${anat1}_bfc ${adir} ${anat1}_brain_mask ${tmp}/${anat2}

echo "************************************"
echo "*** Anat segment"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/03.anat_segment.sh ${anat1}_brain ${adir} ${tmp}

echo "************************************"
echo "*** Anat normalise"
echo "************************************"
echo "************************************"

${sdr}/01.anat_preproc/04.anat_normalize.sh ${anat1}_brain ${adir} ${std} ${mmres}
