#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func=$1
# folders
fdir=$2
# echo times
TEs="$3"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir}

## 01. MEICA
# 01.1. concat in space

eprfx=${func%_echo-*}_echo-
esffx=${func#*_echo-?}

echo "Merging ${func} for MEICA"
fslmerge -z ${func}_concat $( ls ${eprfx}* | grep ${esffx}.nii.gz )

mkdir ${func}_meica

echo "Running tedana"
tedana -d ${func}_concat.nii.gz -e ${TEs} --tedpca kundu-stabilize --png --out-dir ${func}_meica

cd ${func}_meica
gzip *.nii

#tedana -d ${func}_concat.nii.gz -e ${TEs} --verbose --tedort --png --out-dir ${func}_meica
# Old tedana
# ${cwd}/meica.libs/tedana.py -d ${func}_concat.nii.gz -e ${TEs} --fout --denoiseTEs --label=${func}_meica

# 01.2. Ortogonalising good and bad components

echo "Ortogonalising good and bad components in ${func}"

cat comp_table_ica.txt | grep accepted | awk '{print $1}' | csvtool transpose - > accepted.txt
cat comp_table_ica.txt | grep rejected | awk '{print $1}' | csvtool transpose - > rejected.txt

nacc=$( cat accepted.txt )
nrej=$( cat rejected.txt )

1dcat meica_mix.1D"[$nacc]" > meica_good.1D
1dcat meica_mix.1D"[$nrej]" > tmp.rej.tr.1D
1dtranspose tmp.rej.tr.1D > meica_rej.1D

3dTproject -ort meica_good.1D -polort -1 -prefix tmp.tr.1D -input meica_rej.1D -overwrite
1dtranspose tmp.tr.1D > ../${func}_rej_ort.1D

rm tmp.*

cd ${cwd}