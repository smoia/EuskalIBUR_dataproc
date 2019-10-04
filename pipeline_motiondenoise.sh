#!/usr/bin/env bash


wdr=${1:-/data}

### Main ###

./20.sheet_preproc.sh

for sub in 007 003 002
do
	for ses in $( seq -f %02g 1 9 )
	do
		./31.reg_manual_meica.sh ${sub} ${ses}
		./32.compute_motion_outliers.sh ${sub} ${ses}
	done
done

./51.compare_motion_denoise.sh

./71.plot_motion_denoise.sh