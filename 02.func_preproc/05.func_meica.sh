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

## Temp folder
tmp=${5:-.}

scriptdir=${6:-/scripts}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
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
fslmerge -z ${tmp}/${func} $( ls ${tmp}/${eprfx}* | grep ${esffx}.nii.gz )

mkdir ${tmp}/${func}_meica

# Check if there's one or more backups
bcklist=( $( ls ../*${func}_meica_bck.tar.gz ) )
# 01.2. Run tedana only if there's no previous backup
if [[ "${bck}" != "none" ]] && [[ ${bcklist[-1]} ]]
then
	# If there's a backup, unpack the earnest!
	echo "Unpacking backup"
	tar -xzvf ${bcklist[-1]} -C ${tmp}
	echo "Running tedana to revert to backed up state"
	tedana -d ${tmp}/${func}.nii.gz -e ${TEs} \
	--tedpca mdl --out-dir ${tmp}/${func}_meica \
	--mix ${tmp}/${func}_meica/ica_mixing.tsv --ctab ${tmp}/${func}_meica/ica_decomposition.json
else
	echo "No backup file specified or found!"
	echo "Running tedana"
	tedana -d ${tmp}/${func}.nii.gz -e ${TEs} --tedpca mdl --out-dir ${tmp}/${func}_meica
	echo "Creating backup"
	tar -cvf ../$(date +%Y%m%d-%H%M%S)${func}_meica_bck.tar.gz ${tmp}/${func}_meica/ica_mixing.tsv ${tmp}/${func}_meica/ica_decomposition.json
fi

cd ${tmp}/${func}_meica

# 01.4. Orthogonalising good and bad components

echo "Extracting good and bad copmonents"
python3 ${scriptdir}/20.python_scripts/00.process_tedana_output.py ${tmp}/${func}_meica

echo "Orthogonalising good and bad components in ${func}"
nacc=$( cat accepted_list.1D )
nrej=$( cat rejected_list.1D )

# Store some files for data check or later use
if [[ -d "${fdir}/${func}_meica" ]]; then rm -rf ${fdir}/${func}_meica; fi
mkdir ${fdir}/${func}_meica ${fdir}/${func}_meica/figures

cp accepted_list.1D rejected_list.1D accepted_list_by_variance.1D rejected_list_by_variance.1D ${fdir}/${func}_meica/.
cp adaptive_mask.nii.gz ica_decomposition.json ica_mixing_orig.tsv ica_mixing.tsv ${fdir}/${func}_meica/.
cp -r figures ${fdir}/${func}_meica/figures/.

1dcat ica_mixing.tsv"[$nacc]" > accepted.1D
1dcat ica_mixing.tsv"[$nrej]" > rej.tr.1D
1dtranspose rej.tr.1D > rejected.1D

3dTproject -ort accepted.1D -polort -1 -prefix ${tmp}/tr.1D -input rejected.1D -overwrite
1dtranspose ${tmp}/tr.1D > ${fdir}/${func_in%_*}_rej_ort.1D

cd ${cwd}