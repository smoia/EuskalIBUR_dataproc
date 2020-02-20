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

for sub in 003 004 007 008 009  # 001 002
do
	/scripts/03.data_preproc/01.sheet_preproc.sh ${sub}
	for ses in $( seq -f %02g 1 10 )
	do
		/scripts/04.first_level_analysis/01.reg_manual_meica.sh ${sub} ${ses}
		/scripts/04.first_level_analysis/03.compute_motion_outliers.sh ${sub} ${ses}
	done
done

/scripts/05.second_level_analysis/02.compare_motion_denoise.sh

/scripts/10.visualisation/02.plot_motion_denoise.sh

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}