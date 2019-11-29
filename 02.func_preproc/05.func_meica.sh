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
func_optcom=${func_in%_echo-*}_optcom${esffx}

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
	tedana -d ${func}.nii.gz -e ${TEs} \
	--tedpca mdl --out-dir ${func}_meica \
	--mix ${func}_meica/ica_mixing.tsv --ctab ${func}_meica/ica_decomposition.json
else
	echo "No backup file specified or found!"
	echo "Running tedana"
	tedana -d ${func}.nii.gz -e ${TEs} --tedpca mdl --out-dir ${func}_meica
fi

cd ${func}_meica

# 01.3. Moving optcom in parent folder
fslmaths ts_OC.nii.gz ${func_optcom} -odt float

# 01.4. Orthogonalising good and bad components

echo "Extracting good and bad copmonents"
python3 ${cwd}/20.python_scripts/00.process_tedana_output.py ${fdir}/${func}_meica

echo "Orthogonalising good and bad components in ${func}"
nacc=$( cat accepted.1D )
nrej=$( cat rejected.1D )

1dcat ica_mixing.tsv"[$nacc]" > accepted.1D
1dcat ica_mixing.tsv"[$nrej]" > tmp.rej.tr.1D
1dtranspose tmp.rej.tr.1D > rejected.1D

3dTproject -ort accepted.1D -polort -1 -prefix tmp.tr.1D -input rejected.1D -overwrite
1dtranspose tmp.tr.1D > ../${func}_rej_ort.1D

rm tmp.*

cd ${cwd}
