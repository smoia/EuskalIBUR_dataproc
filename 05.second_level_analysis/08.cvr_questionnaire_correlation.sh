#!/usr/bin/env bash

if_missing_do() {
if [ $1 == 'mkdir' ]
then
	if [ ! -d $2 ]
	then
		mkdir "${@:2}"
	fi
elif [ ! -e $3 ]
then
	printf "%s is missing, " "$3"
	case $1 in
		copy ) echo "copying $2"; cp $2 $3 ;;
		mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
		* ) echo "and you shouldn't see this"; exit ;;
	esac
fi
}

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -e $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

lastses=${1:-10}
wdr=${2:-/data}
scriptdir=${2:-/scripts}
tmp=${4:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if_missing_do mkdir CVR_correlation

cd CVR_correlation

if_missing_do mkdir reg
if_missing_do mkdir norm

# Copy files for transformation & create mask
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz reg/MNI_T1_brain.nii.gz
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm.nii.gz reg/MNI_T1_GM.nii.gz
if_missing_do copy ${scriptdir}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm_dil.nii.gz reg/MNI_T1_GM_dil.nii.gz

if_missing_do mask reg/MNI_T1_brain.nii.gz reg/MNI_T1_brain_mask.nii.gz

# Copy & normalising
for sub in $( seq -f %03g 1 10 )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

	echo "%%% Working on subject ${sub} %%%"

	echo "Preparing transformation"
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std1Warp.nii.gz \
				  reg/${sub}_T1w2std1Warp.nii.gz
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_acq-uni_T1w2std0GenericAffine.mat \
				  reg/${sub}_T1w2std0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref0GenericAffine.mat \
				  reg/${sub}_T2w2sbref0GenericAffine.mat
	if_missing_do copy ${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_ses-01_acq-uni_T1w0GenericAffine.mat \
				  reg/${sub}_T2w2T1w0GenericAffine.mat

	for ses in $( seq -f %02g 1 ${lastses} )
	do
		echo "Check if normalisation is needed for session ${ses} masked"

		for inmap in cvr lag
		do
			if [ ${inmap} == "lag" ]; then origmap=cvr_lag; else origmap=${inmap}; fi
			inmap=${inmap}_masked
			infile=${wdr}/CVR/sub-${sub}_ses-${ses}_optcom_map_cvr/sub-${sub}_ses-${ses}_optcom_${origmap}_masked.nii.gz
			if [ ! -e norm/std_optcom_${inmap}_${sub}_${ses}.nii.gz ]
			then
				echo "Transforming ${inmap##*/} maps of session ${ses} to MNI"
				antsApplyTransforms -d 3 -i ${infile} -r reg/MNI_T1_brain.nii.gz \
									-o norm/std_optcom_${inmap}_${sub}_${ses}.nii.gz -n NearestNeighbor \
									-t reg/${sub}_T1w2std1Warp.nii.gz \
									-t reg/${sub}_T1w2std0GenericAffine.mat \
									-t reg/${sub}_T2w2T1w0GenericAffine.mat \
									-t [reg/${sub}_T2w2sbref0GenericAffine.mat,1]
				imrm ${sub}_${ses}_optcom_${inmap}.nii.gz
			fi
			if [ ! -e norm/std_optcom_${inmap}_${sub}_${ses}_smooth.nii.gz ]
			then
				3dBlurInMask -input norm/std_optcom_${inmap}_${sub}_${ses}.nii.gz -mask reg/MNI_T1_GM_dil.nii.gz \
							 -prefix norm/std_optcom_${inmap}_${sub}_${ses}_smooth.nii.gz -FWHM 5
			fi
		done
	done
done



# Copy questionnaire and read it into arrays
sub=( $(csvtool -t TAB namedcol subject ${wdr}/phenotype/questionnaire.tsv ) )
ses=( $(csvtool -t TAB namedcol session ${wdr}/phenotype/questionnaire.tsv ) )
sex=( $(csvtool -t TAB namedcol sex ${wdr}/phenotype/questionnaire.tsv ) )
meanarterial=( $(csvtool -t TAB namedcol mean_arterial_pressure ${wdr}/phenotype/questionnaire.tsv ) )
pulsepressure=( $(csvtool -t TAB namedcol pulse_pressure ${wdr}/phenotype/questionnaire.tsv ) )
pulse=( $(csvtool -t TAB namedcol pulse_avg ${wdr}/phenotype/questionnaire.tsv ) )

let nrep=${#sub[@]}-1
# Compute only tension model
for inmap in cvr lag
do
	# Compute ICC
	inmap=${inmap}_masked
	rm LMEr_${inmap}_onlytension.nii.gz

	run3dLMEr="3dLMEr -prefix LMEr_${inmap}_onlytension.nii.gz -jobs 10"
	run3dLMEr="${run3dLMEr} -mask reg/MNI_T1_brain_mask.nii.gz"
	run3dLMEr="${run3dLMEr} -model 'sex*(meanarterial+pulsepressure+pulse)+(1|session)+((meanarterial+pulsepressure+pulse)|Subj)'"
	run3dLMEr="${run3dLMEr} -gltCode meanarterial 'meanarterial :'"
	run3dLMEr="${run3dLMEr} -gltCode pulsepressure 'pulsepressure :'"
	run3dLMEr="${run3dLMEr} -gltCode pulse 'pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode sex 'sex : 1*m -1*f'"
	run3dLMEr="${run3dLMEr} -gltCode meanarterial_sex 'sex : 1*m -1*f meanarterial :'"
	run3dLMEr="${run3dLMEr} -gltCode pulsepressure_sex 'sex : 1*m -1*f pulsepressure :'"
	run3dLMEr="${run3dLMEr} -gltCode pulse_sex 'sex : 1*m -1*f pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode meanarterial_male 'sex : 1*m meanarterial :'"
	run3dLMEr="${run3dLMEr} -gltCode pulsepressure_male 'sex : 1*m pulsepressure :'"
	run3dLMEr="${run3dLMEr} -gltCode pulse_male 'sex : 1*m pulse :'"
	run3dLMEr="${run3dLMEr} -gltCode meanarterial_female 'sex : 1*f meanarterial :'"
	run3dLMEr="${run3dLMEr} -gltCode pulsepressure_female 'sex : 1*f pulsepressure :'"
	run3dLMEr="${run3dLMEr} -gltCode pulse_female 'sex : 1*f pulse :'"
	run3dLMEr="${run3dLMEr} -qVars 'meanarterial,pulsepressure,pulse'"
	run3dLMEr="${run3dLMEr} -dataTable  "
	run3dLMEr="${run3dLMEr}       Subj session sex meanarterial pulsepressure pulse InputFile                        "

	for k in $(seq 1 ${nrep})
	do
		run3dLMEr="${run3dLMEr}       ${sub[$k]}  ${ses[$k]} ${sex[$k]} ${meanarterial[$k]} ${pulsepressure[$k]} ${pulse[$k]} norm/std_optcom_${inmap}_${sub[$k]}_${ses[$k]}_smooth.nii.gz"
	done
	echo ""
	echo "${run3dLMEr}"
	echo ""
	eval ${run3dLMEr}
done

echo "End of script!"

cd ${cwd}