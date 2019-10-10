#!/usr/bin/env bash


wdr=${1:-/data}

logname=pipeline_motion_denoise_log

######################################
######### Script starts here #########
######################################

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${logname}" ]]; then rm ${wdr}/log/${logname}; fi

echo "************************************" >> ${wdr}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdr}/log/${logname} 2>&1

date
echo "************************************"

# saving the current wokdir
cwd=$(pwd)

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

cd ${cwd}