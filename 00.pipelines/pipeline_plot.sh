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

# Make session maps chart
${scriptdir}/10.visualisation/01.plot_cvr_maps.sh ${wdr}

# Normally these two do not have to be run
# Plot FD vs DVARS
# ${scriptdir}/10.visualisation/02.plot_motion_denoise.sh ${wdr}
# Make the ten session x N methods chart
# ${scriptdir}/10.visualisation/03.plot_all_cvr_maps.sh ${wdr}
# Make ICC maps
${scriptdir}/10.visualisation/06.plot_icc_maps.sh ${wdr} ${scriptdir} ${tmp}
${scriptdir}/10.visualisation/07.plot_cov_maps.sh ${wdr} ${scriptdir} ${tmp}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}