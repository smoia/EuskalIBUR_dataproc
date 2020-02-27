#!/usr/bin/env bash

######### Anat preproc for EuskalIBUR
# Author:  Stefano Moia
# Version: 1.0
# Date:    22.11.2019
#########


sub=$1
ses=$2
wdr=$3

anat1=$4
anat2=$5

adir=$6

std=$7
mmres=$8

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

/scripts/01.anat_preproc/01.anat_correct.sh ${anat1} ${adir}

echo "************************************"
echo "*** Anat correction ${anat2}"
echo "************************************"
echo "************************************"

/scripts/01.anat_preproc/01.anat_correct.sh ${anat2} ${adir} ${anat1}

echo "************************************"
echo "*** Anat skullstrip ${anat2}"
echo "************************************"
echo "************************************"

/scripts/01.anat_preproc/02.anat_skullstrip.sh ${anat2}_bfc ${adir} none ${anat1} none

echo "************************************"
echo "*** Anat skullstrip ${anat1}"
echo "************************************"
echo "************************************"

/scripts/01.anat_preproc/02.anat_skullstrip.sh ${anat1}_bfc ${adir} ${anat1}_brain_mask none ${anat2}

echo "************************************"
echo "*** Anat segment"
echo "************************************"
echo "************************************"

/scripts/01.anat_preproc/03.anat_segment.sh ${anat1}_brain ${adir}

echo "************************************"
echo "*** Anat normalise"
echo "************************************"
echo "************************************"

/scripts/01.anat_preproc/04.anat_normalize.sh ${anat1}_brain ${adir} ${std} ${mmres}

echo "************************************"
echo "*** Clearspace"
echo "************************************"
echo "************************************"

/scripts/00.pipelines/clearspace.sh ${sub} ${ses} ${wdr} anat
