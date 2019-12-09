#!/usr/bin/env bash

sub=$1
ses=$2
wdr=${3:-/data}
slices=${4:-7}
### Main ###

cwd=$( pwd )

cd ${wdr}/BHT_decomp || exit

for set in rest trials-1 trials-2 trials-3 trials-5 trials-8
do
	cd sub-${sub}_ses-${ses}_${set} || exit
	dx=$( fslval melodic_IC.nii.gz dim1 )
	dz=$( fslval melodic_IC.nii.gz dim3 )
	pdx=$( fslval melodic_IC.nii.gz pixdim1 )
	pdz=$( fslval melodic_IC.nii.gz pixdim3 )
	nvol=$( fslval melodic_IC.nii.gz dim4 )
	let nvol--
	ssx=$( bc <<< "$dx/$slices*$pdx" )
	ssz=$( bc <<< "$dz/$slices*$pdz" )

	if [ ! -d ../sub-${sub}_ses-${ses}_${set}_figures ]
	then
		mkdir ../sub-${sub}_ses-${ses}_${set}_figures
	fi

	for i in $( seq 0 $nvol )
	do
		if [ ! -e ../sub-${sub}_ses-${ses}_${set}_figures/volume_${i}.png ]
		then
			let j=i+1
			echo "sub ${sub}, ses ${ses}, ${set}, vol ${i}"
			fsleyes render -of tmp.volume_${i}_x.png --size 1000 150 --scene lightbox --zaxis x --sliceSpacing ${ssx} --ncols ${slices} --nrows 1 -hc ./mean.nii.gz ./melodic_IC.nii.gz --cmap hot --negativeCmap cool --useNegativeCmap --displayRange 1.5 8.0 --volume ${i}
			fsleyes render -of tmp.volume_${i}_z.png --size 1000 150 --scene lightbox --zaxis z --sliceSpacing ${ssz} --ncols ${slices} --nrows 1 -hc ./mean.nii.gz ./melodic_IC.nii.gz --cmap hot --negativeCmap cool --useNegativeCmap --displayRange 1.5 8.0 --volume ${i}
			convert -background black -append tmp.volume_${i}_x.png tmp.volume_${i}_z.png ./report/t${j}.png ./report/f${j}.png ../sub-${sub}_ses-${ses}_${set}_figures/volume_${i}.png
			rm tmp.volume_${i}*
		fi
	done
	cd ${wdr}/BHT_decomp || exit
done


cd ${cwd}