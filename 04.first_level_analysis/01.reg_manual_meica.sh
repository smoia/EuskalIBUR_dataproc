#!/usr/bin/env bash


sub=$1
ses=$2
wdr=${3:-/data}

# Can't parralelise this one!

### Main ###
cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "decomp" ]]
then
	cd ${cwd}
	03.data_preproc/01.sheet_preproc.sh
	cd ${wdr}
fi

echo "Denoising sub ${sub} ses ${ses} optcom"
fdir=sub-${sub}/ses-${ses}/func_preproc
flpr=sub-${sub}_ses-${ses}
meica_mix=${wdr}/${fdir}/${flpr}_task-breathhold_concat_bold_bet_meica/ica_mixing.tsv

sbrf=sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref
func=${fdir}/${flpr}_task-breathhold_optcom_bold_bet
bold=${flpr}_task-breathhold_meica
bves=${flpr}_task-breathhold_vessels
bnet=${flpr}_task-breathhold_networks

cd decomp

# 01.1. Removing component by orthogonalisation
acc=$( cat ${flpr}_accepted_list.1D )
rej=$( cat ${flpr}_rejected_list.1D )
ves=$( cat ${flpr}_vessels_list.1D )
net=$( cat ${flpr}_networks_list.1D )

# 01.2. Process rejected
1dcat "$meica_mix[$acc$net$ves]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej]" > ${flpr}_rejected.1D

# 01.3. Orthogonalise them
1dtranspose ${flpr}_rejected.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_rejected_ort.1D

# 01.4. Process rejected and vessels
1dcat "$meica_mix[$acc$net]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej$ves]" > ${flpr}_vessels.1D

# 01.5. Orthogonalise them
1dtranspose ${flpr}_vessels.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_vessels_ort.1D

# 01.6. Process rejected, vessels, and networks
1dcat "$meica_mix[$acc]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej$ves$net]" > ${flpr}_networks.1D

# 01.7. Orthogonalise them
1dtranspose ${flpr}_networks.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_networks_ort.1D

rm tmp.${flpr}*

cd ..

# 02. Running different kinds of denoise: aggressive, orthogonalised, partial regression, multivariate

# 02.1. Running aggressive
for icaset in ${bold} ${bves} ${bnet}
do
	3dTproject -input ${func}.nii.gz \
	-ort decomp/${flpr}_rejected.1D \
	-polort -1 -prefix ${fdir}/${icaset}-aggr_bold_bet.nii.gz
done

# 02.2. Running orthogonalised
for icaset in ${bold} ${bves} ${bnet}
do
	3dTproject -input ${func}.nii.gz \
	-ort decomp/${flpr}_rejected_ort.1D \
	-polort -1 -prefix ${fdir}/${icaset}-orth_bold_bet.nii.gz
done

# 02.3. Running partial regression
# 02.3.1. Start with dropping the first line of the tsv output.
csvtool -t TAB -u TAB drop 1 ${meica_mix} > tmp.mmix

# 02.3.2. Add 1 to the indexes to use with fsl_regfilt - which means:
# transpose, add one, transpose, paste different solutions together.
csvtool transpose ${flpr}_rejected_list.1D > tmp.rej.1D
csvtool transpose ${flpr}_vessels_list.1D > tmp.ves.1D
csvtool transpose ${flpr}_networks_list.1D > tmp.net.1D

for type in rej ves net
do
	1deval -a tmp.${type}.1D -expr 'a+1' > tmp.${type}.fsl.1D
	csvtool transpose tmp.${type}.fsl.1D > tmp.${type}.1D
done

cat tmp.rej.1D > tmp.rej.fsl.1D
paste tmp.rej.fsl.1D tmp.ves.1D -d , > tmp.ves.fsl.1D
paste tmp.ves.fsl.1D tmp.net.1D -d , > tmp.net.fsl.1D

# 02.3.3. Finally run fsl_regfilt
for icaset in ${bold} ${bves} ${bnet}
do
	fsl_regfilt -i ${func} \
	-d tmp.mmix \
	-f "$( cat tmp.rej.fsl.1D )" \
	-o ${fdir}/${icaset}-preg_bold_bet
done

rm tmp.*

# Run 4D denoise - implement later.


#ica_components_orig.nii.gz
#ica_mixing_orig.tsv

# Topup everything!
for icaset in ${bold} ${bves} ${bnet}
do
	for den in aggr orth preg # mvar
	do
		${cwd}/02.func_preproc/02.func_pepolar.sh ${icaset}-${den}_bold_bet ${fdir} ${sbrf}_topup
		${cwd}/02.func_preproc/09.func_spc.sh ${icaset}-${den}_bold_tpp ${fdir}
		immv ${fdir}/${icaset}-${den}_bold_tpp ${fdir}/00.${icaset}-${den}_bold_native_preprocessed
		immv ${fdir}/${icaset}-${den}_bold_SPC ${fdir}/01.${icaset}-${den}_bold_native_SPC_preprocessed
	done
done


cd ${cwd}
