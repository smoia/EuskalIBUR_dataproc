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
		* ) "and you shouldn't see this"; exit ;;
	esac
fi
}

map=$1
wdr=${2:-/data}
sdr=${3:-/scripts}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Surr_reliability || exit

# Copy files for transformation & create mask
if_missing_do mask ${sdr}/90.template/MNI152_T1_1mm_GM_resamp_2.5mm_mcorr.nii.gz ./MNI_GM.nii.gz

# Create folder ICC

if_missing_do mkdir ICC ICC/lag ICC/cvr

# Run ICC once for original data
rm ICC/${map}/1000_orig.nii.gz

3dICC -prefix ICC/${map}/1000_orig.nii.gz -jobs 10  \
-mask ./MNI_GM.nii.gz                               \
-model '1+(1|session)+(1|Subj)'                     \
-dataTable                                          \
    Subj  session   InputFile                       \
    001  01  norm/std_001_01_${map}.nii.gz          \
    001  02  norm/std_001_02_${map}.nii.gz          \
    001  03  norm/std_001_03_${map}.nii.gz          \
    001  04  norm/std_001_04_${map}.nii.gz          \
    001  05  norm/std_001_05_${map}.nii.gz          \
    001  06  norm/std_001_06_${map}.nii.gz          \
    001  07  norm/std_001_07_${map}.nii.gz          \
    001  08  norm/std_001_08_${map}.nii.gz          \
    001  09  norm/std_001_09_${map}.nii.gz          \
    001  10  norm/std_001_10_${map}.nii.gz          \
    002  01  norm/std_002_01_${map}.nii.gz          \
    002  02  norm/std_002_02_${map}.nii.gz          \
    002  03  norm/std_002_03_${map}.nii.gz          \
    002  04  norm/std_002_04_${map}.nii.gz          \
    002  05  norm/std_002_05_${map}.nii.gz          \
    002  06  norm/std_002_06_${map}.nii.gz          \
    002  07  norm/std_002_07_${map}.nii.gz          \
    002  08  norm/std_002_08_${map}.nii.gz          \
    002  09  norm/std_002_09_${map}.nii.gz          \
    002  10  norm/std_002_10_${map}.nii.gz          \
    003  01  norm/std_003_01_${map}.nii.gz          \
    003  02  norm/std_003_02_${map}.nii.gz          \
    003  03  norm/std_003_03_${map}.nii.gz          \
    003  04  norm/std_003_04_${map}.nii.gz          \
    003  05  norm/std_003_05_${map}.nii.gz          \
    003  06  norm/std_003_06_${map}.nii.gz          \
    003  07  norm/std_003_07_${map}.nii.gz          \
    003  08  norm/std_003_08_${map}.nii.gz          \
    003  09  norm/std_003_09_${map}.nii.gz          \
    003  10  norm/std_003_10_${map}.nii.gz          \
    004  01  norm/std_004_01_${map}.nii.gz          \
    004  02  norm/std_004_02_${map}.nii.gz          \
    004  03  norm/std_004_03_${map}.nii.gz          \
    004  04  norm/std_004_04_${map}.nii.gz          \
    004  05  norm/std_004_05_${map}.nii.gz          \
    004  06  norm/std_004_06_${map}.nii.gz          \
    004  07  norm/std_004_07_${map}.nii.gz          \
    004  08  norm/std_004_08_${map}.nii.gz          \
    004  09  norm/std_004_09_${map}.nii.gz          \
    004  10  norm/std_004_10_${map}.nii.gz          \
    005  01  norm/std_005_01_${map}.nii.gz          \
    005  02  norm/std_005_02_${map}.nii.gz          \
    005  03  norm/std_005_03_${map}.nii.gz          \
    005  04  norm/std_005_04_${map}.nii.gz          \
    005  05  norm/std_005_05_${map}.nii.gz          \
    005  06  norm/std_005_06_${map}.nii.gz          \
    005  07  norm/std_005_07_${map}.nii.gz          \
    005  08  norm/std_005_08_${map}.nii.gz          \
    005  09  norm/std_005_09_${map}.nii.gz          \
    005  10  norm/std_005_10_${map}.nii.gz          \
    006  01  norm/std_006_01_${map}.nii.gz          \
    006  02  norm/std_006_02_${map}.nii.gz          \
    006  03  norm/std_006_03_${map}.nii.gz          \
    006  04  norm/std_006_04_${map}.nii.gz          \
    006  05  norm/std_006_05_${map}.nii.gz          \
    006  06  norm/std_006_06_${map}.nii.gz          \
    006  07  norm/std_006_07_${map}.nii.gz          \
    006  08  norm/std_006_08_${map}.nii.gz          \
    006  09  norm/std_006_09_${map}.nii.gz          \
    006  10  norm/std_006_10_${map}.nii.gz


# Repeat for surrogates
for n in $(seq -f %03g 0 1000)
do
rm ICC/${map}/${n}.nii.gz

3dICC -prefix ICC/${map}/${n}.nii.gz -jobs 10      \
-mask ./MNI_GM.nii.gz                              \
-model '1+(1|session)+(1|Subj)'                    \
-dataTable                                         \
    Subj  session   InputFile                      \
    001  01  surr/std_001_01_${map}/std_001_01_${map}_Surr_${n}.nii.gz \
    001  02  surr/std_001_02_${map}/std_001_02_${map}_Surr_${n}.nii.gz \
    001  03  surr/std_001_03_${map}/std_001_03_${map}_Surr_${n}.nii.gz \
    001  04  surr/std_001_04_${map}/std_001_04_${map}_Surr_${n}.nii.gz \
    001  05  surr/std_001_05_${map}/std_001_05_${map}_Surr_${n}.nii.gz \
    001  06  surr/std_001_06_${map}/std_001_06_${map}_Surr_${n}.nii.gz \
    001  07  surr/std_001_07_${map}/std_001_07_${map}_Surr_${n}.nii.gz \
    001  08  surr/std_001_08_${map}/std_001_08_${map}_Surr_${n}.nii.gz \
    001  09  surr/std_001_09_${map}/std_001_09_${map}_Surr_${n}.nii.gz \
    001  10  surr/std_001_10_${map}/std_001_10_${map}_Surr_${n}.nii.gz \
    002  01  surr/std_002_01_${map}/std_002_01_${map}_Surr_${n}.nii.gz \
    002  02  surr/std_002_02_${map}/std_002_02_${map}_Surr_${n}.nii.gz \
    002  03  surr/std_002_03_${map}/std_002_03_${map}_Surr_${n}.nii.gz \
    002  04  surr/std_002_04_${map}/std_002_04_${map}_Surr_${n}.nii.gz \
    002  05  surr/std_002_05_${map}/std_002_05_${map}_Surr_${n}.nii.gz \
    002  06  surr/std_002_06_${map}/std_002_06_${map}_Surr_${n}.nii.gz \
    002  07  surr/std_002_07_${map}/std_002_07_${map}_Surr_${n}.nii.gz \
    002  08  surr/std_002_08_${map}/std_002_08_${map}_Surr_${n}.nii.gz \
    002  09  surr/std_002_09_${map}/std_002_09_${map}_Surr_${n}.nii.gz \
    002  10  surr/std_002_10_${map}/std_002_10_${map}_Surr_${n}.nii.gz \
    003  01  surr/std_003_01_${map}/std_003_01_${map}_Surr_${n}.nii.gz \
    003  02  surr/std_003_02_${map}/std_003_02_${map}_Surr_${n}.nii.gz \
    003  03  surr/std_003_03_${map}/std_003_03_${map}_Surr_${n}.nii.gz \
    003  04  surr/std_003_04_${map}/std_003_04_${map}_Surr_${n}.nii.gz \
    003  05  surr/std_003_05_${map}/std_003_05_${map}_Surr_${n}.nii.gz \
    003  06  surr/std_003_06_${map}/std_003_06_${map}_Surr_${n}.nii.gz \
    003  07  surr/std_003_07_${map}/std_003_07_${map}_Surr_${n}.nii.gz \
    003  08  surr/std_003_08_${map}/std_003_08_${map}_Surr_${n}.nii.gz \
    003  09  surr/std_003_09_${map}/std_003_09_${map}_Surr_${n}.nii.gz \
    003  10  surr/std_003_10_${map}/std_003_10_${map}_Surr_${n}.nii.gz \
    004  01  surr/std_004_01_${map}/std_004_01_${map}_Surr_${n}.nii.gz \
    004  02  surr/std_004_02_${map}/std_004_02_${map}_Surr_${n}.nii.gz \
    004  03  surr/std_004_03_${map}/std_004_03_${map}_Surr_${n}.nii.gz \
    004  04  surr/std_004_04_${map}/std_004_04_${map}_Surr_${n}.nii.gz \
    004  05  surr/std_004_05_${map}/std_004_05_${map}_Surr_${n}.nii.gz \
    004  06  surr/std_004_06_${map}/std_004_06_${map}_Surr_${n}.nii.gz \
    004  07  surr/std_004_07_${map}/std_004_07_${map}_Surr_${n}.nii.gz \
    004  08  surr/std_004_08_${map}/std_004_08_${map}_Surr_${n}.nii.gz \
    004  09  surr/std_004_09_${map}/std_004_09_${map}_Surr_${n}.nii.gz \
    004  10  surr/std_004_10_${map}/std_004_10_${map}_Surr_${n}.nii.gz \
    007  01  surr/std_007_01_${map}/std_007_01_${map}_Surr_${n}.nii.gz \
    007  02  surr/std_007_02_${map}/std_007_02_${map}_Surr_${n}.nii.gz \
    007  03  surr/std_007_03_${map}/std_007_03_${map}_Surr_${n}.nii.gz \
    007  04  surr/std_007_04_${map}/std_007_04_${map}_Surr_${n}.nii.gz \
    007  05  surr/std_007_05_${map}/std_007_05_${map}_Surr_${n}.nii.gz \
    007  06  surr/std_007_06_${map}/std_007_06_${map}_Surr_${n}.nii.gz \
    007  07  surr/std_007_07_${map}/std_007_07_${map}_Surr_${n}.nii.gz \
    007  08  surr/std_007_08_${map}/std_007_08_${map}_Surr_${n}.nii.gz \
    007  09  surr/std_007_09_${map}/std_007_09_${map}_Surr_${n}.nii.gz \
    007  10  surr/std_007_10_${map}/std_007_10_${map}_Surr_${n}.nii.gz \
    008  01  surr/std_008_01_${map}/std_008_01_${map}_Surr_${n}.nii.gz \
    008  02  surr/std_008_02_${map}/std_008_02_${map}_Surr_${n}.nii.gz \
    008  03  surr/std_008_03_${map}/std_008_03_${map}_Surr_${n}.nii.gz \
    008  04  surr/std_008_04_${map}/std_008_04_${map}_Surr_${n}.nii.gz \
    008  05  surr/std_008_05_${map}/std_008_05_${map}_Surr_${n}.nii.gz \
    008  06  surr/std_008_06_${map}/std_008_06_${map}_Surr_${n}.nii.gz \
    008  07  surr/std_008_07_${map}/std_008_07_${map}_Surr_${n}.nii.gz \
    008  08  surr/std_008_08_${map}/std_008_08_${map}_Surr_${n}.nii.gz \
    008  09  surr/std_008_09_${map}/std_008_09_${map}_Surr_${n}.nii.gz \
    008  10  surr/std_008_10_${map}/std_008_10_${map}_Surr_${n}.nii.gz \
    009  01  surr/std_009_01_${map}/std_009_01_${map}_Surr_${n}.nii.gz \
    009  02  surr/std_009_02_${map}/std_009_02_${map}_Surr_${n}.nii.gz \
    009  03  surr/std_009_03_${map}/std_009_03_${map}_Surr_${n}.nii.gz \
    009  04  surr/std_009_04_${map}/std_009_04_${map}_Surr_${n}.nii.gz \
    009  05  surr/std_009_05_${map}/std_009_05_${map}_Surr_${n}.nii.gz \
    009  06  surr/std_009_06_${map}/std_009_06_${map}_Surr_${n}.nii.gz \
    009  07  surr/std_009_07_${map}/std_009_07_${map}_Surr_${n}.nii.gz \
    009  08  surr/std_009_08_${map}/std_009_08_${map}_Surr_${n}.nii.gz \
    009  09  surr/std_009_09_${map}/std_009_09_${map}_Surr_${n}.nii.gz \
    009  10  surr/std_009_10_${map}/std_009_10_${map}_Surr_${n}.nii.gz
done

echo "Merge all ICCs together"
fslmerge -t ICC/ICC_${map}.nii.gz ICC/${map}/* 

echo "End of script!"

cd ${cwd}
