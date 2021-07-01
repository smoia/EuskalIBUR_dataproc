#!/usr/bin/env bash

if_missing_do() {
if [ $1 == 'mkdir' ]
then
       if [ ! -d $2 ]
       then
              mkdir "${@:2}"
       fi
elif [ ! -e $3 ]
then
       printf "%s is missing, " "$3"
       case $1 in
              copy ) echo "copying $2"; cp $2 $3 ;;
              mask ) echo "binarising $2"; fslmaths $2 -bin $3 ;;
              * ) echo "and you shouldn't see this"; exit ;;
       esac
fi
}

brickname=${1}
wdr=${2:-/data}

### Main ###
cwd=$( pwd )
cd ${wdr}/Dataset_QC || exit

echo "Creating folders"
if_missing_do mkdir MEMA

cd norm

# Fix ICC out name for 3dMEMA
brickout=${brickname%#*}_${brickname##*#}

# Compute ICC
rm ../mema/MEMA_${brickout}.nii.gz

run3dMEMA="3dMEMA -prefix ../mema/MEMA_${brickout}.nii.gz -jobs 10"
run3dMEMA="${run3dMEMA} -mask ../reg/MNI_T1_brain_mask.nii.gz"
run3dMEMA="${run3dMEMA} -jobs 4 -max_zeros 4 -HKtest"
run3dMEMA="${run3dMEMA} -set ${brickout}"
for sub in 001 002 003 004 007 008 009
do
       001 001_allses_acalc#0_Coef.nii.gz 001_allses_acalc#0_Tstat.nii.gz
	run3dMEMA="${run3dMEMA}      ${sub} ${sub}_allses_${brickname}_Coef.nii.gz  ${sub}_allses_${brickname}_Tstat.nii.gz"
done
echo ""
echo "${run3dMEMA}"
echo ""
eval ${run3dMEMA}

echo "End of script!"

cd ${cwd}