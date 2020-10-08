#!/usr/bin/env bash

parc=${1}
wdr=${2:-/data}
# lastses=${2:-10}
lastses=10

logname=pipeline_cvr_parcels_${parc}_log

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

echo "************************************"
echo "***    CVR mapping ${parc}"
echo "************************************"
echo "************************************"
echo ""
echo ""

for sub in 001 002 003 004 007 008 009
do
	rm ${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}_labels.1D
	rm ${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}_vx.1D
	rm ${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}_masked.nii.gz

	for ses in $( seq -f %02g 1 ${lastses} )
	do

		echo "************************************"
		echo "*** Extract timeseries sub ${sub} ses ${ses} parc ${parc}"
		echo "************************************"
		echo "************************************"
		/scripts/03.data_preproc/06.extract_timeseries.sh ${sub} ${ses} ${parc}

		echo "************************************"
		echo "*** CVR map sub ${sub} ses ${ses} ${ftype}"
		echo "************************************"
		echo "************************************"
		/scripts/04.first_level_analysis/05.cvr_map_text.sh ${sub} ${ses} ${parc} 
	done
done

echo "************************************"
echo "*** Compute ICC ${parc}"
echo "************************************"
echo "************************************"

/scripts/05.second_level_analysis/04.cvr_text_reliability.sh ${parc}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}