subjects=('sub-001' 'sub-002' 'sub-003' 'sub-004' 'sub-005' 'sub-006' 'sub-007' 'sub-008' 'sub-009' 'sub-010')

for subj in ${subjects[*]};
    do
    error=/bcbl/home/home_n-z/vferrer/freesurfer_${subj}_error.txt
    qsub -e $error -o $error -N ${subj}_PJMASK_FRESURFER /bcbl/home/home_n-z/vferrer/EuskalIBUR_dataproc/30.plugins/01.freesurfer/singularity_freesurfer_run.sh $subj
done
