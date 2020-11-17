#!/usr/bin/env bash


wdr=${1:-/data}
scriptdir=${2:-/scripts}
tmp=${3:-/tmp}

logname=pipeline_plot_log

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
echo "*** Start virtualenv"
echo "************************************"
echo "************************************"
${scriptdir}/80.virtual_environments/fsleyes_venv/bin/activate

echo "************************************"
echo "*** Make LME maps"
echo "************************************"
echo "************************************"
${scriptdir}/10.visualisation/05.plot_cvr_comparison.sh ${wdr} ${scriptdir} ${tmp}

echo "************************************"
echo "*** Make session maps chart"
echo "************************************"
echo "************************************"
${scriptdir}/10.visualisation/01.plot_cvr_maps.sh ${wdr} ${scriptdir}

# echo "************************************"
# echo "*** Plot FD vs DVARS"
# echo "************************************"
# echo "************************************"

# ${scriptdir}/10.visualisation/02.plot_motion_denoise.sh ${wdr}

# echo "************************************"
# echo "*** Make ICC maps"
# echo "************************************"
# echo "************************************"

# ${scriptdir}/10.visualisation/06.plot_icc_maps.sh ${wdr} ${scriptdir} ${tmp}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}