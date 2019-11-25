#!/usr/bin/env bash


sub=$1
ses=$2
wdr=${3:-/data}

nTE=${4:-5}

### Main ###
cwd=$( pwd )

cd ${wdr} || exit

if [[ ! -d "decomp" ]]
then
	cd ${cwd}
	./20.sheet_preproc.sh
	cd ${wdr}
fi

echo "Denoising sub ${sub} ses ${ses} optcom"
fdir=sub-${sub}/ses-${ses}/func_preproc
prfx=sub-${sub}_ses-${ses}
meica_mix=${wdr}/${fdir}/${prfx}_task-breathhold_echo-1_bold_RPI_bet_meica/meica_mix.1D
func=${fdir}/00.${prfx}_task-breathhold_optcom_bold_native_preprocessed
bold=${prfx}_task-breathhold_meica_bold
bves=${prfx}_task-breathhold_vessels_bold
# bnet=sub-${sub}_ses-${ses}_task-breathhold_networks_bold

cd decomp

# Removing component by ortogonalisation
acc=$( cat ${prfx}_accepted.1D )
rej=$( cat ${prfx}_rejected.1D )
ves=$( cat ${prfx}_vessels.1D )
net=$( cat ${prfx}_networks.1D )

1dcat "$meica_mix[$acc$net$ves]" > tmp.${prfx}_meica_good.1D
1dcat "$meica_mix[$rej]" > tmp.${prfx}_rej.tr.1D
1dtranspose tmp.${prfx}_rej.tr.1D > tmp.${prfx}_meica_rej.1D

3dTproject -ort tmp.${prfx}_meica_good.1D -polort -1 -prefix tmp.${prfx}_tr.1D -input tmp.${prfx}_meica_rej.1D -overwrite
1dtranspose tmp.${prfx}_tr.1D > ${prfx}_rejected_ort.1D

1dcat "$meica_mix[$acc$net]" > tmp.${prfx}_meica_good.1D
1dcat "$meica_mix[$rej$ves]" > tmp.${prfx}_rej.tr.1D
1dtranspose tmp.${prfx}_rej.tr.1D > tmp.${prfx}_meica_rej.1D

3dTproject -ort tmp.${prfx}_meica_good.1D -polort -1 -prefix tmp.${prfx}_tr.1D -input tmp.${prfx}_meica_rej.1D -overwrite
1dtranspose tmp.${prfx}_tr.1D > ${prfx}_vessels_ort.1D

rm tmp.${prfx}*

cd ..

3dTproject -input ${func}.nii.gz \
-ort decomp/${prfx}_rejected_ort.1D \
-polort -1 -prefix ${fdir}/${bold}_bet.nii.gz
3dTproject -input ${func}.nii.gz \
-ort decomp/${prfx}_vessels_ort.1D \
-polort -1 -prefix ${fdir}/${bves}_bet.nii.gz

# Uncomment here for regfilt
# fsl_regfilt -i ${func} \
# -d ${meica_mix} \
# -f "$( cat decomp/sub-${sub}_ses-${ses}_rejected.1D )" \
# -o ${fdir}/${bold}_bet
# fsl_regfilt -i ${func} \
# -d ${meica_mix} \
# -f "$( cat decomp/sub-${sub}_ses-${ses}_vessels.1D )" \
# -o ${fdir}/${bves}_bet
# fsl_regfilt -i ${func} \
# -d ${meica_mix} \
# -f "$( cat decomp/sub-${sub}_ses-${ses}_networks.1D )" \
# -o ${fdir}/${bnet}_bet

${cwd}/11.func_spc.sh ${bold}_bet ${fdir}
${cwd}/11.func_spc.sh ${bves}_bet ${fdir}
# ${cwd}/11.func_spc.sh ${bnet}_bet ${fdir}

immv ${fdir}/${bold}_bet ${fdir}/00.${bold}_native_preprocessed
immv ${fdir}/${bold}_bet_SPC ${fdir}/01.${bold}_native_SPC_preprocessed
immv ${fdir}/${bves}_bet ${fdir}/00.${bves}_native_preprocessed
immv ${fdir}/${bves}_bet_SPC ${fdir}/01.${bves}_native_SPC_preprocessed
# immv ${fdir}/${bnet}_bet ${fdir}/00.${bnet}_native_preprocessed
# immv ${fdir}/${bnet}_bet_SPC ${fdir}/01.${bnet}_native_SPC_preprocessed


# for e in 2  # $( seq 1 ${nTE} )
# do
# 	echo "Denoising sub ${sub} ses ${ses} echo ${e}"
# 	func=${fdir}/00.sub-${sub}_ses-${ses}_task-breathhold_echo-${e}_bold_native_preprocessed
# 	bold=sub-${sub}_ses-${ses}_task-breathhold_meica_echo-${e}_bold

# 	3dTproject -input ${func}.nii.gz \
# 	-ort decomp/${prfx}_rejected_ort.1D \
# 	-polort -1 -prefix ${fdir}/${bold}_bet.nii.gz

# 	# Uncomment here for regfilt
# 	# fsl_regfilt -i ${func} \
# 	# -d ${meica_mix} \
# 	# -f "$( cat decomp/sub-${sub}_ses-${ses}_rejected.1D )" \
# 	# -o ${fdir}/${bold}_bet
# 	# fsl_regfilt -i ${func} \
# 	# -d ${meica_mix} \
# 	# -f "$( cat decomp/sub-${sub}_ses-${ses}_vascular.1D )" \
# 	# -o ${fdir}/${bold}_bet
# 	# fsl_regfilt -i ${func} \
# 	# -d ${meica_mix} \
# 	# -f "$( cat decomp/sub-${sub}_ses-${ses}_networks.1D )" \
# 	# -o ${fdir}/${bold}_bet

# 	${cwd}/11.func_spc.sh ${bold}_bet ${fdir}

# 	immv ${fdir}/${bold}_bet ${fdir}/04.${bold}_native_preprocessed
# 	immv ${fdir}/${bold}_bet_SPC ${fdir}/05.${bold}_native_SPC_preprocessed
# done

cd ${cwd}
