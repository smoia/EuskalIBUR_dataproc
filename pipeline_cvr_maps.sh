#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###


for sub in 007 003 002
do
	for ses in $( seq -f %02g 1 9 )
	do
		./21.prepare_CVR_mapping.sh ${sub} ${ses}
	done
done

./24.compute_CVR_regressors.sh

for sub in 007 003 002
do
	for ftype in echo-2 optcom meica vessels networks
	do
		for ses in $( seq -f %02g 1 9 )
		do
			./30.cvr_map.sh ${sub} ${ses} ${ftype} 
		done

		./50.generalcvrmaps.sh ${sub} ${ftype}
	done
done

./70.plot_cvr_maps.sh