#!/usr/bin/env bash

sub=$1
ses=$2
wdr=${3:-/data}

logname=pipeline_sim_cvr_motdenoise_sub-${sub}_ses-${ses}_log

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
echo "***    CVR mapping ${sub} ${ses}    ***"
echo "************************************"
echo "************************************"
echo ""
echo ""

# echo "************************************"
# echo "*** Processing xslx sheet"
# echo "************************************"
# echo "************************************"
# /scripts/03.data_preproc/01.sheet_preproc.sh ${sub}

# echo "************************************"
# echo "*** Denoising sub ${sub} ses ${ses}"
# echo "************************************"
# echo "************************************"
# /scripts/04.first_level_analysis/01.reg_manual_meica_sim.sh ${sub} ${ses}

# echo "************************************"
# echo "*** Preparing CVR sub ${sub} ses ${ses}"
# echo "************************************"
# echo "************************************"
# /scripts/03.data_preproc/02.prepare_CVR_mapping.sh ${sub} ${ses}

# for ftype in meica-mvar optcom echo-2
# do
# 	echo "************************************"
# 	echo "*** Compute CVR regressors"
# 	echo "************************************"
# 	echo "************************************"
# 	/scripts/03.data_preproc/05.compute_CVR_regressors.sh ${sub} ${ses} ${ftype}
# done

for ftype in optcom meica-aggr meica-orth meica-cons echo-2
do
	echo "************************************"
	echo "*** CVR map sub ${sub} ses ${ses} ${ftype}"
	echo "************************************"
	echo "************************************"
	/scripts/04.first_level_analysis/02.cvr_map_sim.sh ${sub} ${ses} ${ftype}

	# echo "************************************"
	# echo "*** Motion outliers sub ${sub} ses ${ses} ${ftype}"
	# echo "************************************"
	# echo "************************************"
	# /scripts/04.first_level_analysis/04.cvr_motion_outliers_sim.sh ${sub} ${ses} ${ftype} 
done

# echo "************************************"
# echo "*** Motion outliers sub ${sub} ses ${ses} pre-preproc"
# echo "************************************"
# echo "************************************"
# /scripts/04.first_level_analysis/03.compute_motion_outliers.sh ${sub} ${ses}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}