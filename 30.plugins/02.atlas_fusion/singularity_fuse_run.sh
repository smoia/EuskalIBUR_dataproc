

singularity exec -e --no-home -B $PRJDIR/preproc:/Data -B ${PRJDIR}/EuskalIBUR_dataproc:/scripts ${PRJDIR}/EuskalIBUR_dataproc/euskalibur.simg\
 ${wdir}/EuskalIBUR_dataproc/30.plugins/02.atlas_fusion/mni_2_func.sh $SUBJ