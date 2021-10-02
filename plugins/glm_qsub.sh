#!bin/bash

SUB_LIST=('sub-001' 'sub-002' 'sub-003' 'sub-004' 'sub-005' 'sub-006' 'sub-007' 'sub-008' 'sub-009' 'sub-010')
SES=('ses-01' 'ses-02' 'ses-03' 'ses-04' 'ses-05' 'ses-06' 'ses-07' 'ses-08' 'ses-09' 'ses-10')

PRJDIR='/export/home/eurunuela/public/MEPFM/LowRank'

# GLM for the Motor task
qsub -q long.q -N "${SBJ}_${SES}_Motor" -o ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM -e ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM ${PRJDIR}/glm_motor.sh ${SBJ} ${SES}

# GLM for the Pinel task
qsub -q long.q -N "${SBJ}_${SES}_Pinel" -o ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM -e ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM ${PRJDIR}/glm_pinel.sh ${SBJ} ${SES}

# GLM for the Simon task
qsub -q long.q -N "${SBJ}_${SES}_Simon" -o ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM -e ${PRJDIR}/${SBJ}/LogFiles/${SBJ}_${SES}_GLM ${PRJDIR}/glm_simon.sh ${SBJ} ${SES}