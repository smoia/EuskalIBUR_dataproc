#!/usr/bin/env bash

######### FUNCTIONAL 03 for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    31.06.2019
#########

## Variables
# functional
func_in=$1
# folders
fdir=$2
# echo times
TEs="$3"
# backup?
bck=${4:-none}
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${fdir} || exit

#Read and process input
eprfx=${func_in%_echo-*}_echo-
esffx=${func_in#*_echo-?}
func=${func_in%_echo-*}_concat${esffx}

## 01. MEICA
# 01.1. concat in space

echo "Merging ${func} for MEICA"
fslmerge -z ${func} $( ls ${eprfx}* | grep ${esffx}.nii.gz )

mkdir ${func}_meica

# Check if there's one or more backups
bcklist=( $( ls ../*${func}_meica_bck.tar.gz ) )
# 01.2. Run tedana only if there's no previous backup
if [[ "${bck}" != "none" ]] && [[ ${bcklist[-1]} ]]
then
	# If there's a backup, unpack the earnest!
	echo "Unpacking backup"
	tar -xzvf ${bcklist[-1]} -C ..
	echo "Running tedana to revert to backed up state"
	tedana -d ${func}.nii.gz -e $"{TEs}" \
	--tedpca mdl --out-dir ${func}_meica \
	--mix ${func}_meica/meica_mix.1D --ctab ${func}_meica/comp_table_ica.txt
else
	echo "No backup file specified or found!"
	echo "Running tedana"
	tedana -d ${func}.nii.gz -e ${TEs} --tedpca mdl --out-dir ${func}_meica
fi

cd ${func}_meica
# This shouldn't be necessary, but it doesn't harm having it just in case.
gzip ./*.nii

#tedana -d ${func}_concat.nii.gz -e ${TEs} --verbose --tedort --png --out-dir ${func}_meica
# Old tedana
# ${cwd}/meica.libs/tedana.py -d ${func}_concat.nii.gz -e ${TEs} --fout --denoiseTEs --label=${func}_meica

# 01.3. Orthogonalising good and bad components

echo "Orthogonalising good and bad components in ${func}"

grep accepted < comp_table_ica.txt | awk '{print $1}' | csvtool transpose - > accepted.txt
grep rejected < comp_table_ica.txt | awk '{print $1}' | csvtool transpose - > rejected.txt

nacc=$( cat accepted.txt )
nrej=$( cat rejected.txt )

1dcat meica_mix.1D"[$nacc]" > meica_good.1D
1dcat meica_mix.1D"[$nrej]" > tmp.rej.tr.1D
1dtranspose tmp.rej.tr.1D > meica_rej.1D

3dTproject -ort meica_good.1D -polort -1 -prefix tmp.tr.1D -input meica_rej.1D -overwrite
1dtranspose tmp.tr.1D > ../${func}_rej_ort.1D

rm tmp.*

cd ${cwd}
