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

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

slice_coeffs() {
# $1:brickname $2:bckimg $3:[p/q] $4:pval $5:picdir
echo "plot ${1##*/} $3 $4"
fsleyes render -of ${1}_tmp_axial.png --size 1900 200 \
--scene lightbox --zaxis 2 --sliceSpacing 12 --zrange 19.3 139.9 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 10000 --clippingRange 0.0 10000 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of ${1}_tmp_sagittal.png --size 1900 200 \
--scene lightbox --zaxis 0 --sliceSpacing 13 --zrange 39.5 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 10000 --clippingRange 0.0 10000 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of ${1}_tmp_coronal.png --size 1900 200 \
--scene lightbox --zaxis 1 --sliceSpacing 15 --zrange 21 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 10000 --clippingRange 0.0 10000 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
# Mount visions
convert -append ${1}_tmp_axial.png ${1}_tmp_sagittal.png ${1}_tmp_coronal.png +repage ${1}_${3}-${4}.png
rm ${1}_tmp*
mv ${1}_${3}-${4}.png ${5}/.
}

# Declare z-value
declare -A zvals
zvals=( [0.1]=1.64 [0.05]=1.96 [0.02]=2.33 [0.01]=2.58 [0.005]=2.81 [0.002]=3.09 [0.001]=3.29 )

task=$1
pval=${2:-0.01}
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/lme || exit

picdir=${wdr}/Mennes_replication/pics
if_missing_do mkdir ${picdir}
if_missing_do mkdir ${picdir}/lme
if_missing_do mkdir ${picdir}/lme/${task}

tmp=${tmp}/tmp.${task}_p-${pval}_06ptg
replace_and mkdir ${tmp}

# Set the T1 in native space
bckimg=${sdr}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm

rsfc=()
for run in $( seq -f %02g 1 4 )
do
	rsfc+=(fALFF_r-${run} ALFF_r-${run} RSFA_r-${run})
done

case ${task} in
	motor )
		volumes=( allmotors motors_vs_sham ) #finger_left_vs_sham finger_right_vs_sham toe_left_vs_sham toe_right_vs_sham tongue_vs_sham ) #allmotors motors_vs_sham finger_left finger_right toe_left toe_right tongue finger_left_vs_sham finger_right_vs_sham toe_left_vs_sham toe_right_vs_sham tongue_vs_sham )
		rsfc+=( CVR )
		;;
	simon )
		volumes=( all_congruent congruent_vs_incongruent congruent_and_incongruent )
		rsfc+=( CVR )
		;;
	falff )
		volumes=( "${rsfc[@]}" )
		rsfc=( CVR )
		;;
	* ) echo "wrong task ${task}."; exit ;;
esac

# Check number of volumes and remove one cause 0-index

for vol in "${volumes[@]}"
do
	echo "Working on volume ${vol}"
	for rsf in "${rsfc[@]}"
	do 
		if [ ${task} == "falff" ]
		then
			fldr=RSF
		else
			fldr=${vol}
		fi
		cd ${fldr} || continue
		pwd

		rbuck=cause_${vol}_${rsf}.nii.gz
		lastbrick=$( fslval ${rbuck} dim5 )
		let lastbrick--
		[ ! -e ${rbuck} ] && echo "Missing volume ${rbuck}" && return || echo "Exploding ${rbuck}"
		for brick in $(seq 0 ${lastbrick})
		do
			# Break volumes
			brickname=$( 3dinfo -label "${rbuck}[${brick}]" )
			brickname=${brickname// /_}
			3dbucket -prefix ${tmp}/${vol}_${rsf}_${brickname}.nii.gz -abuc "${rbuck}[${brick}]" -overwrite
		done

		# Find right tstat value
		[ -z "${zvals[${pval}]}" ] && echo "Selected pval ${pval} not in list" && return 
		thr=${zvals[${pval}]}
		echo "thr: ${thr}"

		for brick in ${tmp}/${vol}_${rsf}_*_Z.nii.gz
		do
			echo ${brick##*/}
			brickname=${brick%_Z.nii.gz}
			# mask the functional brick with the right tstat
			fslmaths ${brickname}_Z -abs -thr ${thr} -bin -mul ${brick} ${brickname}_fmkd
			# fsleyes all the way
			slice_coeffs ${brickname} ${bckimg} p ${pval} ${picdir}/lme/${task}

			# Repeat with FDR
			echo "Computing FDR with z=${thr}"
			3dFDR -input ${brickname}_Z.nii.gz -prefix ${brickname}_FDR.nii.gz
			fslmaths ${brickname}_FDR -thr ${thr} -bin -mul ${brick} ${brickname}_fmkd
			slice_coeffs ${brickname} ${bckimg} q ${pval} ${picdir}/lme/${task}
		done
		cd ${wdr}/Mennes_replication/lme || exit
	done
done
# rm -rf ${tmp}/${task}

cd ${cwd}