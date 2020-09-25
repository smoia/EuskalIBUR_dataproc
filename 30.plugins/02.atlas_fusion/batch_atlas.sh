subjects=('sub-001' 'sub-002' 'sub-003' 'sub-004' 'sub-007' 'sub-008' 'sub-009')
# project main directory 
PRJDIR=/bcbl/home/public/PJMASK_2
# directory containing scripts and containers
wdir=/bcbl/home/public/PJMASK_2
for subj in ${subjects[*]};
    do
    log=/bcbl/home/public/PJMASK_2/LogFiles/${subj}_atlasing_pipe
    rm $log
    qsub -e $log -o $log -N ${subj}_PJMASK_atlases ${wdir}/EuskalIBUR_dataproc/30.plugins/02.atlas_fusion/singularity_fuse_run.sh $PRJDIR $wdir $subj
done