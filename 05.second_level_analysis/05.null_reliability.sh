#!/usr/bin/env bash

if_missing_do() {
if [ ! -e $3 ]
then
      printf "%s is missing, " "$3"
      case $1 in
            copy ) echo "copying $2"; cp $2 $3 ;;
            mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
            * ) "and you shouldn't see this"; exit ;;
      esac
fi
}

lastses=${1:-10}
wdr=${2:-/data}
tmp=${3:-/tmp}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

cd CVR_reliability

# Copy files for transformation & create mask
if_missing_do copy /scripts/90.template/MNI152_T1_1mm_brain_resamp_2.5mm.nii.gz ./reg/MNI_T1_brain.nii.gz
if_missing_do mask ./reg/MNI_T1_brain.nii.gz -bin ./reg/MNI_T1_brain_mask.nii.gz

# Crete folder ICC

if [ -d "ICC" ]; then rm -rf ICC; fi
mkdir ICC

cd normalised

for n in $(seq -f %04g 0 1000)
do
    for map in cvr lag
    do
        rm ../ICC2_${map}_optcom.nii.gz

        if [ ${n} -eq "1000" ]
        then
            run3dICC="3dICC -prefix ../ICC/${map}_orig.nii.gz -jobs 10                  "
        else
            run3dICC="3dICC -prefix ../ICC/${map}_${n}.nii.gz -jobs 10             "
        fi

        run3dICC="${run3dICC} -mask ../reg/MNI_T1_brain_mask.nii.gz                        "
        run3dICC="${run3dICC} -model  '1+(1|session)+(1|Subj)'                             "
        run3dICC="${run3dICC} -dataTable                                                   "
        run3dICC="${run3dICC}       Subj session                           InputFile       "

        for sub in 001 002 003 004 007 008 009
        do
            for ses in $(seq -f %02g 1 ${lastses})
            do
                if [ ${n} -eq "1000" ]
                then
                    run3dICC="${run3dICC}       ${sub}  ${ses}   surrogates_std_optcom_${map}_masked_${sub}_${ses}_resamp.nii.gz "
                else
                    run3dICC="${run3dICC}       ${sub}  ${ses}   surr/surrogates_std_optcom_${map}_masked_${sub}_${ses}_resamp_${n}.nii.gz "
                fi
            done
        done

        ${run3dICC}

    done
done

echo "End of script!"

cd ${cwd}