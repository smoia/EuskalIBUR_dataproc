#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR || exit

for sub in 001 002 003 004 007 008 009
do
	# Creating full sessions maps
	appending="convert -append"
	for ftype in echo-2 optcom meica-mvar meica-aggr meica-orth meica-cons all-orth meica-aggr-twosteps meica-orth-twosteps meica-cons-twosteps all-orth-twosteps
	do
		for ses in $( seq -f %02g 1 10 )
		do
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			convert sub-${sub}_ses-${ses}_${ftype}.png -crop 234x265+466+642 +repage tmp.01pcm_${sub}_${ses}_${ftype}.png
		done
		convert +append tmp.01pcm_${sub}_??_${ftype}.png +repage tmp.01pcm_${sub}_${ftype}.png
		appending="${appending} tmp.01pcm_${sub}_${ftype}.png"
	done
	appending="${appending} +repage sub-${sub}_alltypes.png"
	${appending}
done

rm tmp.*.png

cd ${cwd} || exit
