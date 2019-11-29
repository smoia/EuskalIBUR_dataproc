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

# Removing component by orthogonalisation
acc=$( cat ${flpr}_accepted_list.1D )
rej=$( cat ${flpr}_rejected_list.1D )
ves=$( cat ${flpr}_vessels_list.1D )
net=$( cat ${flpr}_networks_list.1D )

# Process rejected
1dcat "$meica_mix[$acc$net$ves]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej]" > ${flpr}_rejected.1D

# Orthogonalise them
1dtranspose ${flpr}_rejected.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_rejected_ort.1D

# Process rejected and vessels
1dcat "$meica_mix[$acc$net]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej$ves]" > ${flpr}_vessels.1D

# Orthogonalise them
1dtranspose ${flpr}_vessels.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_vessels_ort.1D

# Process rejected, vessels, and networks
1dcat "$meica_mix[$acc]" > tmp.${flpr}_meica_good.1D
1dcat "$meica_mix[$rej$ves$net]" > ${flpr}_networks.1D

# Orthogonalise them
1dtranspose ${flpr}_networks.1D > tmp.${flpr}_meica_rej.1D
3dTproject -ort tmp.${flpr}_meica_good.1D -polort -1 -prefix tmp.${flpr}_tr.1D -input tmp.${flpr}_meica_rej.1D -overwrite
1dtranspose tmp.${flpr}_tr.1D > ${flpr}_networks_ort.1D

rm tmp.${flpr}*

cd ..

# Running different kinds of denoise: aggressive, orthogonalised, partial regression, multivariate

# Running aggressive
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_rejected.1D \
-polort -1 -prefix ${fdir}/${bold}-aggr_bold_bet.nii.gz
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_vessels.1D \
-polort -1 -prefix ${fdir}/${bves}-aggr_bold_bet.nii.gz
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_networks.1D \
-polort -1 -prefix ${fdir}/${bnet}-aggr_bold_bet.nii.gz

# Running orthogonalised
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_rejected_ort.1D \
-polort -1 -prefix ${fdir}/${bold}-orth_bold_bet.nii.gz
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_vessels_ort.1D \
-polort -1 -prefix ${fdir}/${bves}-orth_bold_bet.nii.gz
3dTproject -input ${func}.nii.gz \
-ort decomp/${flpr}_networks_ort.1D \
-polort -1 -prefix ${fdir}/${bnet}-orth_bold_bet.nii.gz

# Running partial regression
# start with dropping the first line of the tsv output.
csvtool -t TAB -u TAB drop 1 ${meica_mix} > tmp.mmix

# add 1 to the indexes to use with fsl_regfilt - which means:
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

# Finally run fsl_regfilt
fsl_regfilt -i ${func} \
-d tmp.mmix \
-f "$( cat tmp.rej.fsl.1D )" \
-o ${fdir}/${bold}-preg_bold_bet
fsl_regfilt -i ${func} \
-d tmp.mmix \
-f "$( cat tmp.ves.fsl.1D )" \
-o ${fdir}/${bves}-preg_bold_bet
fsl_regfilt -i ${func} \
-d tmp.mmix \
-f "$( cat tmp.net.fsl.1D )" \
-o ${fdir}/${bnet}-preg_bold_bet

rm tmp.*

# Run 4D denoise - implement later.


# Topup everything!

for den in aggr orth preg # mvar
do
	${cwd}/02.func_preproc/02.func_pepolar.sh ${bold}-${den}_bold_bet ${fdir} ${sbrf}_topup
	${cwd}/02.func_preproc/02.func_pepolar.sh ${bves}-${den}_bold_bet ${fdir} ${sbrf}_topup
	${cwd}/02.func_preproc/02.func_pepolar.sh ${bnet}-${den}_bold_bet ${fdir} ${sbrf}_topup
	${cwd}/02.func_preproc/09.func_spc.sh ${bold}-${den}_bold_tpp ${fdir}
	${cwd}/02.func_preproc/09.func_spc.sh ${bves}-${den}_bold_tpp ${fdir}
	${cwd}/02.func_preproc/09.func_spc.sh ${bnet}-${den}_bold_tpp ${fdir}
	immv ${fdir}/${bold}-${den}_bold_tpp ${fdir}/00.${bold}-${den}_bold_native_preprocessed
	immv ${fdir}/${bold}-${den}_bold_SPC ${fdir}/01.${bold}-${den}_bold_native_SPC_preprocessed
	immv ${fdir}/${bves}-${den}_bold_tpp ${fdir}/00.${bves}-${den}_bold_native_preprocessed
	immv ${fdir}/${bves}-${den}_bold_SPC ${fdir}/01.${bves}-${den}_bold_native_SPC_preprocessed
	immv ${fdir}/${bnet}-${den}_bold_tpp ${fdir}/00.${bnet}-${den}_bold_native_preprocessed
	immv ${fdir}/${bnet}-${den}_bold_SPC ${fdir}/01.${bnet}-${den}_bold_native_SPC_preprocessed
done


cd ${cwd}
