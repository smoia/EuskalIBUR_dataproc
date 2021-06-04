#!/usr/bin/env bash


sub=$1
ses=$2
wdr=${3:-/data}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "decomp" ]]
then
	cd ${cwd}
	03.data_preproc/01.sheet_preproc.sh ${sub}
	cd ${wdr}
fi

echo "Denoising sub ${sub} ses ${ses} optcom"
fdir=${wdr}/sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}
meica_fldr=${fdir}/${flpr}_task-breathhold_concat_bold_bet_meica
meica_mix=${meica_fldr}/ica_mixing.tsv

cd decomp || exit

# 01.1. Processing list of classified components
acc=$( cat ${flpr}_accepted_list.1D )
rej=$( cat ${flpr}_rejected_list.1D )
ves=$( cat ${flpr}_vessels_list.1D )
# net=$( cat ${flpr}_networks_list.1D )

# 01.2. Process rejected
1dcat "$meica_mix[$acc]" > ${flpr}_accepted.1D
# 1dcat "$meica_mix[$acc$net]" > ${flpr}_accepted.1D
1dcat "$meica_mix[$ves]" > ${flpr}_vessels.1D
1dcat "$meica_mix[$rej]" > ${flpr}_rejected.1D

# 01.9.1. Transforming kappa based idx into var based idx for each type !!! independently !!!
for type in accepted rejected vessels  # networks
do
	csvtool transpose ${flpr}_${type}_list.1D > ${tmp}/tmp.${flpr}_01rmms_${type}_transpose.1D
	touch ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D
	for i in $( cat ${tmp}/tmp.${flpr}_01rmms_${type}_transpose.1D )
	do
		grep ,${i} < ${meica_fldr}/idx_map.csv | awk -F',' '{print $1}' >> ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D
	done
	csvtool -u SPACE transpose ${tmp}/tmp.${flpr}_01rmms_${type}_var_list.1D > ${flpr}_${type}_var_list.1D
done
# 01.9.2. Add a blank line at the beginning probably due to "feature" of 3dSynthesize version Dec 5 2019
echo "   " | cat - ${meica_fldr}/ica_mixing_orig.tsv > ${tmp}/tmp.${flpr}_01rmms_orig_mix


rm ${tmp}/tmp.${flpr}_01rmms_*
