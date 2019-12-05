#!/usr/bin/env bash

wdr=${1:-/data}

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
			nvol=`fslval melodic_IC.nii.gz dim4`
			mkdir sub-${sub}_ses-${ses}_${set}_figures
			for i in 0  #`seq 0 $nvol`
			do
				echo "sub ${sub}, ses ${ses}, ${set}, vol ${i}"
				fsleyes render -of ./sub-${sub}_ses-${ses}_${set}_figures/volume_${i}.png --size 1000 350 --scene lightbox --zaxis 0 --sliceSpacing 7 --zrange 0 200 --ncols 5 --nrows 2 --movieSync ./melodic_IC.nii.gz --name "volume ${i}" --overlayType volume --alpha 100.0 --cmap hot --negativeCmap cool --useNegativeCmap --displayRange 1.5 8.0 --volume ${i}
			done
			cd ${wdr}/BHT_decomp || exit
		done
	done
done

cd ${cwd}