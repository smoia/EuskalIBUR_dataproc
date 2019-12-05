#!/usr/bin/env bash

wdr=${1:-/data}
slices=${2:-7}
### Main ###

cwd=$( pwd )

cd ${wdr}/BHT_decomp || exit

for sub in 001 002 003 004 007 008
do
	for ses in `seq -f %02g 1 10`
	do
		for set in rest trials-2 trials-3 trials-4 trials-5 trials-6 trials-7 trials-8
		do
			cd sub-${sub}_ses-${ses}_${set}
			dx=`fslval melodic_IC.nii.gz dim1`
			dz=`fslval melodic_IC.nii.gz dim3`
			pdx=`fslval melodic_IC.nii.gz pixdim1`
			pdz=`fslval melodic_IC.nii.gz pixdim3`
			nvol=`fslval melodic_IC.nii.gz dim4`
			ssx=`bc <<< "$dx/$slices*$pdx"`
			ssz=`bc <<< "$dz/$slices*$pdz"`

			mkdir sub-${sub}_ses-${ses}_${set}_figures

			for i in `seq 0 $nvol`
			do
				let j=i+1
				echo "sub ${sub}, ses ${ses}, ${set}, vol ${i}"
				fsleyes render -of tmp.volume_${i}_x.png --size 1000 150 --scene lightbox --zaxis x --sliceSpacing ${ssx} --ncols ${slices} --nrows 1 -hc ./mean.nii.gz ./melodic_IC.nii.gz --cmap hot --negativeCmap cool --useNegativeCmap --displayRange 1.5 8.0 --volume ${i}
				fsleyes render -of tmp.volume_${i}_z.png --size 1000 150 --scene lightbox --zaxis z --sliceSpacing ${ssz} --ncols ${slices} --nrows 1 -hc ./mean.nii.gz ./melodic_IC.nii.gz --cmap hot --negativeCmap cool --useNegativeCmap --displayRange 1.5 8.0 --volume ${i}
				convert -background black -append tmp.volume_${i}_x.png tmp.volume_${i}_z.png ./report/t${j}.png ./report/f${j}.png ./sub-${sub}_ses-${ses}_${set}_figures/volume_${i}.png
			done
			cd ${wdr}/BHT_decomp || exit
		done
	done
done

cd ${cwd}