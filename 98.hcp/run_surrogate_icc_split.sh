#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

map=$1
miniter=$2
step=$3
wdr=${4:-/data}
sdr=${5:-/scripts}


logname=surr_icc_${map}_${miniter}_log

date

wdr=/bcbl/home/public/PJMASK_2/preproc
sdr=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc
tmp=/export/home/smoia/scratch

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
echo "*** Compute surrogate ICC"
echo "************************************"
echo "************************************"
singularity exec -e --no-home \
-B ${wdr}:/data -B ${sdr}:/scripts \
-B ${tmp}:/tmp \
euskalibur.sif 05.second_level_analysis/05.null_reliability_split.sh ${map} ${miniter} ${step}

echo ""
echo ""
echo "************************************"
echo "************************************"
echo "*** Pipeline Completed!"
echo "************************************"
echo "************************************"
date

cd ${cwd}
