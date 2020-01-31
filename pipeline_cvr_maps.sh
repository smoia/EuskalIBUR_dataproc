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


for sub in 001 002 003 004 007 008 009
do
	echo "************************************"
	echo "*** Processing xslx sheet"
	echo "************************************"
	echo "************************************"
	./03.data_preproc/01.sheet_preproc.sh

	for ses in $( seq -f %02g 1 10 )
	do

		echo "************************************"
		echo "*** Denoising sub ${sub} ses ${ses}"
		echo "************************************"
		echo "************************************"
		./04.first_level_analysis/01.reg_manual_meica.sh ${sub} ${ses}

		echo "************************************"
		echo "*** Preparing CVR sub ${sub} ses ${ses}"
		echo "************************************"
		echo "************************************"
		./03.data_preproc/02.prepare_CVR_mapping.sh ${sub} ${ses}

		for ftype in optcom echo-2 meica-aggr meica-orth meica-preg meica-mvar meica-recn vessels-preg
		do
			echo "************************************"
			echo "*** Compute CVR regressors"
			echo "************************************"
			echo "************************************"
			./03.data_preproc/05.compute_CVR_regressors.sh ${sub} ${ses} ${ftype}

			echo "************************************"
			echo "*** CVR map sub ${sub} ses ${ses} ${ftype}"
			echo "************************************"
			echo "************************************"
			./04.first_level_analysis/02.cvr_map.sh ${sub} ${ses} ${ftype} 
		done
	done
done

for sub in 001 002 003 004 007 008 009
do
	for ftype in optcom echo-2 meica-aggr meica-orth meica-preg meica-mvar meica-recn vessels-preg
	do
		echo "************************************"
		echo "*** General CVR sub ${sub} ${ftype}"
		echo "************************************"
		echo "************************************"

		./05.second_level_analysis/01.generalcvrmaps.sh ${sub} ${ftype}
	done
done

echo "************************************"
echo "*** Plot CVRs"
echo "************************************"
echo "************************************"

./10.visualisation/01.plot_cvr_maps.sh

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}