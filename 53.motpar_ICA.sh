#!/usr/bin/env bash

######### CVR MAPS for PJMASK
# Author:  Stefano Moia
# Version: 1.0
# Date:    15.08.2${ses}9
#########


wdr=${1:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d motpar ]
then
	mkdir motpar motpar/deriv1 motpar/par motpar/deriv1/orig motpar/par/orig
fi

echo "Copying motpar files"
cp sub-???/ses-??/func_preproc/*mcf.par motpar/par/orig/.
cp sub-???/ses-??/func_preproc/*mcf_deriv1.par motpar/deriv1/orig/.

cd motpar/par

if [ ! -d split ]; then mkdir split; fi
if [ ! -d nifti ]; then mkdir nifti; fi

echo "Split files"
cd orig
for motfile in *.par
do
	for par in $(seq 1 6)
	do
		csvtool -t ' ' col ${par} ${motfile} > ../split/${motfile::-4}_par-${par}.mot
	done
done
cd ../split

echo "Transform files"
for motfile in *.mot
do
	fslascii2img ${motfile} 1 1 1 390 1 1 1 1.5 ../nifti/${motfile::-4}_tps.nii.gz
	fslascii2img ${motfile} 390 1 1 1 1.5 1 1 1 ../nifti/${motfile::-4}_vox.nii.gz
done
cd ..

echo "Concat files"
for par in $(seq 1 6)
do
	fslmerge -x par-${par}_dep-tps nifti/*par-${par}_tps.nii.gz
	fslmerge -x par-${par}_dep-sub nifti/*par-${par}_vox.nii.gz
done

echo "Running Melodic"
melodic -i par-1_dep-tps,par-2_dep-tps,par-3_dep-tps,par-4_dep-tps,par-5_dep-tps,par-6_dep-tps -o concatica_tps --report
melodic -i par-1_dep-tps,par-2_dep-tps,par-3_dep-tps,par-4_dep-tps,par-5_dep-tps,par-6_dep-tps -o tica_tps -a tica --report
melodic -i par-1_dep-sub,par-2_dep-sub,par-3_dep-sub,par-4_dep-sub,par-5_dep-sub,par-6_dep-sub -o tica_sub -a tica --report

cd ${cwd}