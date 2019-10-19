#!/usr/bin/env bash

wdr=${1:-/data}

logname=pipeline_cvr_maps_log

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
echo "***    CVR mapping ${flpr}    ***"
echo "************************************"
echo "************************************"
echo ""
echo ""
echo "************************************"
echo "*** Processing xslx sheet"
echo "************************************"
echo "************************************"

./20.sheet_preproc.sh

for sub in 007 003 002
do
	for ses in $( seq -f %02g 1 9 )
	do

		echo "************************************"
		echo "*** Denoising sub ${sub} ses ${ses}"
		echo "************************************"
		echo "************************************"
		./30.reg_manual_meica.sh ${sub} ${ses}

		echo "************************************"
		echo "*** Preparing CVR sub ${sub} ses ${ses}"
		echo "************************************"
		echo "************************************"
		./21.prepare_CVR_mapping.sh ${sub} ${ses}
	done
done

echo "************************************"
echo "*** Compute CVR regressors"
echo "************************************"
echo "************************************"


./24.compute_CVR_regressors.sh

for sub in 007 003 002
do
	for ftype in echo-2 optcom meica vessels  # networks
	do
		for ses in $( seq -f %02g 1 9 )
		do
					echo "************************************"
					echo "*** CVR map sub ${sub} ses ${ses} ${ftype}"
					echo "************************************"
					echo "************************************"

			./31.cvr_map.sh ${sub} ${ses} ${ftype} 
		done

		echo "************************************"
		echo "*** General CVR sub ${sub} ${ftype}"
		echo "************************************"
		echo "************************************"

		./50.generalcvrmaps.sh ${sub} ${ftype}
	done
done

echo "************************************"
echo "*** Plot CVRs"
echo "************************************"
echo "************************************"

./70.plot_cvr_maps.sh

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}