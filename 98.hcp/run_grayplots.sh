#$ -S /bin/bash
#$ -cwd
#$ -m be
#$ -M s.moia@bcbl.eu

module load singularity/3.3.0

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

date

sub=$1
ses=$2
echo=$3

wdr=/bcbl/home/public/PJMASK_2/preproc
sdr=/bcbl/home/public/PJMASK_2/EuskalIBUR_dataproc

cd ${sdr}

logname=grayplots_${sub}_${ses}_${echo}_pipe

# Preparing log folder and log file, removing the previous one
if [[ ! -d "${wdr}/log" ]]; then mkdir ${wdr}/log; fi
if [[ -e "${wdr}/log/${logname}" ]]; then rm ${wdr}/log/${logname}; fi

echo "************************************" >> ${wdr}/log/${logname}

exec 3>&1 4>&2

exec 1>${wdr}/log/${logname} 2>&1

date
echo "************************************"

for run in 01 02 03 04
do
# Run grayplots
singularity exec -e --no-home \
-B ${wdr}:/data -B ${sdr}:/scripts \
-B /export/home/smoia/scratch:/tmp \
euskalibur.sif 02.func_preproc/12.func_grayplot.sh \
00.sub-${sub}_ses-${ses}_task-rest_run-${run}_${echo}_bold_native_preprocessed \
${wdr}/sub-${sub}/ses-${ses}/func_preproc \
sub-${sub}_ses-01_T2w \
${wdr}/sub-${sub}/ses-${ses}/reg/sub-${sub}_sbref \
sub-${sub}_ses-01_acq-uni_T1w \
-1
done