#!/usr/bin/env bash

parc=${1}
lastses=${2:-10}
lastsub=${3:-10}
wdr=${4:-/data}
scriptdir=${5:-/scripts}

### Main ###
cwd=$( pwd )
cd ${wdr} || exit

echo "Creating folders"
if [ ! -d CVR_reliability ]
then
	mkdir CVR_reliability
fi

cd CVR_reliability

mkdir parcels

# Copy
for sub in $( seq -f %03g 1 ${lastsub} )
do
	if [[ ${sub} == 005 || ${sub} == 006 || ${sub} == 010 ]]
	then
		continue
	fi

      atlas=${wdr}/sub-${sub}/ses-01/atlas/sub-${sub}_${parc}_labels

      if [ ! -e ${atlas}_check.1D ]
      then
            python3 ${scriptdir}/20.python_scripts/check_labels_20.py ${atlas}.1D ${atlas}_check.1D
      fi

	echo "%%% Working on subject ${sub} %%%"

      for inmap in cvr_masked_physio_only cvr_lag tmap
      do
            case ${inmap} in
                  cvr_masked_physio_only ) map=cvr ;;
                  cvr_lag ) map=lag ;;
                  tmap ) map=tmap ;;
            esac
            for ses in $( seq -f %02g 1 ${lastses} )
            do
    		      echo "Adjusting files for 3dICC call"
                  flpr=sub-${sub}_ses-${ses}
                  3dROIstats -mask ${atlas}_check.1D -1Dformat \
                             ${wdr}/CVR/${flpr}_${parc}_map_cvr/${flpr}_${parc}_${inmap}.1D > parcels/${sub}_${ses}_${parc}_${map}.1D
		done
      done
done	

cd parcels

for map in cvr lag
do
# Compute ICC
rm ../ICC2_${map}_${parc}.1D

3dICC -prefix ../ICC2_${map}_${parc}.1D -jobs 10                       \
      -model  '1+(1|session)+(1|Subj)'                                     \
      -tStat 'tFile'                                                       \
      -dataTable                                                           \
      Subj session         tFile                             InputFile     \
      001  01       001_01_${parc}_tmap.1D\'    001_01_${parc}_${map}.1D\' \
      001  02       001_02_${parc}_tmap.1D\'    001_02_${parc}_${map}.1D\' \
      001  03       001_03_${parc}_tmap.1D\'    001_03_${parc}_${map}.1D\' \
      002  01       002_01_${parc}_tmap.1D\'    002_01_${parc}_${map}.1D\' \
      002  02       002_02_${parc}_tmap.1D\'    002_02_${parc}_${map}.1D\' \
      002  03       002_03_${parc}_tmap.1D\'    002_03_${parc}_${map}.1D\' \
      001  04       001_04_${parc}_tmap.1D\'    001_04_${parc}_${map}.1D\' \
      001  05       001_05_${parc}_tmap.1D\'    001_05_${parc}_${map}.1D\' \
      001  06       001_06_${parc}_tmap.1D\'    001_06_${parc}_${map}.1D\' \
      001  07       001_07_${parc}_tmap.1D\'    001_07_${parc}_${map}.1D\' \
      001  08       001_08_${parc}_tmap.1D\'    001_08_${parc}_${map}.1D\' \
      001  09       001_09_${parc}_tmap.1D\'    001_09_${parc}_${map}.1D\' \
      001  10       001_10_${parc}_tmap.1D\'    001_10_${parc}_${map}.1D\' \
      002  04       002_04_${parc}_tmap.1D\'    002_04_${parc}_${map}.1D\' \
      002  05       002_05_${parc}_tmap.1D\'    002_05_${parc}_${map}.1D\' \
      002  06       002_06_${parc}_tmap.1D\'    002_06_${parc}_${map}.1D\' \
      002  07       002_07_${parc}_tmap.1D\'    002_07_${parc}_${map}.1D\' \
      002  08       002_08_${parc}_tmap.1D\'    002_08_${parc}_${map}.1D\' \
      002  09       002_09_${parc}_tmap.1D\'    002_09_${parc}_${map}.1D\' \
      002  10       002_10_${parc}_tmap.1D\'    002_10_${parc}_${map}.1D\' \
      003  01       003_01_${parc}_tmap.1D\'    003_01_${parc}_${map}.1D\' \
      003  02       003_02_${parc}_tmap.1D\'    003_02_${parc}_${map}.1D\' \
      003  03       003_03_${parc}_tmap.1D\'    003_03_${parc}_${map}.1D\' \
      003  04       003_04_${parc}_tmap.1D\'    003_04_${parc}_${map}.1D\' \
      003  05       003_05_${parc}_tmap.1D\'    003_05_${parc}_${map}.1D\' \
      003  06       003_06_${parc}_tmap.1D\'    003_06_${parc}_${map}.1D\' \
      003  07       003_07_${parc}_tmap.1D\'    003_07_${parc}_${map}.1D\' \
      003  08       003_08_${parc}_tmap.1D\'    003_08_${parc}_${map}.1D\' \
      003  09       003_09_${parc}_tmap.1D\'    003_09_${parc}_${map}.1D\' \
      003  10       003_10_${parc}_tmap.1D\'    003_10_${parc}_${map}.1D\' \
      004  01       004_01_${parc}_tmap.1D\'    004_01_${parc}_${map}.1D\' \
      004  02       004_02_${parc}_tmap.1D\'    004_02_${parc}_${map}.1D\' \
      004  03       004_03_${parc}_tmap.1D\'    004_03_${parc}_${map}.1D\' \
      004  04       004_04_${parc}_tmap.1D\'    004_04_${parc}_${map}.1D\' \
      004  05       004_05_${parc}_tmap.1D\'    004_05_${parc}_${map}.1D\' \
      004  06       004_06_${parc}_tmap.1D\'    004_06_${parc}_${map}.1D\' \
      004  07       004_07_${parc}_tmap.1D\'    004_07_${parc}_${map}.1D\' \
      004  08       004_08_${parc}_tmap.1D\'    004_08_${parc}_${map}.1D\' \
      004  09       004_09_${parc}_tmap.1D\'    004_09_${parc}_${map}.1D\' \
      004  10       004_10_${parc}_tmap.1D\'    004_10_${parc}_${map}.1D\' \
      007  01       007_01_${parc}_tmap.1D\'    007_01_${parc}_${map}.1D\' \
      007  02       007_02_${parc}_tmap.1D\'    007_02_${parc}_${map}.1D\' \
      007  03       007_03_${parc}_tmap.1D\'    007_03_${parc}_${map}.1D\' \
      007  04       007_04_${parc}_tmap.1D\'    007_04_${parc}_${map}.1D\' \
      007  05       007_05_${parc}_tmap.1D\'    007_05_${parc}_${map}.1D\' \
      007  06       007_06_${parc}_tmap.1D\'    007_06_${parc}_${map}.1D\' \
      007  07       007_07_${parc}_tmap.1D\'    007_07_${parc}_${map}.1D\' \
      007  08       007_08_${parc}_tmap.1D\'    007_08_${parc}_${map}.1D\' \
      007  09       007_09_${parc}_tmap.1D\'    007_09_${parc}_${map}.1D\' \
      007  10       007_10_${parc}_tmap.1D\'    007_10_${parc}_${map}.1D\' \
      008  01       008_01_${parc}_tmap.1D\'    008_01_${parc}_${map}.1D\' \
      008  02       008_02_${parc}_tmap.1D\'    008_02_${parc}_${map}.1D\' \
      008  03       008_03_${parc}_tmap.1D\'    008_03_${parc}_${map}.1D\' \
      008  04       008_04_${parc}_tmap.1D\'    008_04_${parc}_${map}.1D\' \
      008  05       008_05_${parc}_tmap.1D\'    008_05_${parc}_${map}.1D\' \
      008  06       008_06_${parc}_tmap.1D\'    008_06_${parc}_${map}.1D\' \
      008  07       008_07_${parc}_tmap.1D\'    008_07_${parc}_${map}.1D\' \
      008  08       008_08_${parc}_tmap.1D\'    008_08_${parc}_${map}.1D\' \
      008  09       008_09_${parc}_tmap.1D\'    008_09_${parc}_${map}.1D\' \
      008  10       008_10_${parc}_tmap.1D\'    008_10_${parc}_${map}.1D\' \
      009  01       009_01_${parc}_tmap.1D\'    009_01_${parc}_${map}.1D\' \
      009  02       009_02_${parc}_tmap.1D\'    009_02_${parc}_${map}.1D\' \
      009  03       009_03_${parc}_tmap.1D\'    009_03_${parc}_${map}.1D\' \
      009  04       009_04_${parc}_tmap.1D\'    009_04_${parc}_${map}.1D\' \
      009  05       009_05_${parc}_tmap.1D\'    009_05_${parc}_${map}.1D\' \
      009  06       009_06_${parc}_tmap.1D\'    009_06_${parc}_${map}.1D\' \
      009  07       009_07_${parc}_tmap.1D\'    009_07_${parc}_${map}.1D\' \
      009  08       009_08_${parc}_tmap.1D\'    009_08_${parc}_${map}.1D\' \
      009  09       009_09_${parc}_tmap.1D\'    009_09_${parc}_${map}.1D\' \
      009  10       009_10_${parc}_tmap.1D\'    009_10_${parc}_${map}.1D\'

done

echo "End of script!"

cd ${cwd}