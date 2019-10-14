#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR

for sub in 007 003 002
do
	for ftype in echo-2 optcom meica vessels networks
	do
		for ses in $( seq -f %02g 1 9 )
		do
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			convert sub-${sub}_ses-${ses}_${ftype}.png -crop 234x265+466+642 tmp.${sub}_${ses}_${ftype}.png
		done
		convert +append tmp.${sub}_??_${ftype}.png +repage tmp.${sub}_${ftype}.png
	done
	convert -append tmp.${sub}_echo-2.png tmp.${sub}_optcom.png tmp.${sub}_meica.png tmp.${sub}_vessels.png tmp.${sub}_networks.png sub-${sub}_alltypes.png
done
rm tmp.*.png

cd ${cwd}
