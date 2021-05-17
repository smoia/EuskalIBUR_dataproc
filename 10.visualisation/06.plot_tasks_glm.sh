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
# $1:brickname $2:bckimg $3:[p/q] $4:pval $5:picdir $6:sub $7:ses
fsleyes render -of ${1}_tmp_axial.png --size 1900 200 \
--scene lightbox --zaxis 2 --sliceSpacing 12 --zrange 19.3 139.9 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of ${1}_tmp_sagittal.png --size 1900 200 \
--scene lightbox --zaxis 0 --sliceSpacing 13 --zrange 39.5 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of ${1}_tmp_coronal.png --size 1900 200 \
--scene lightbox --zaxis 1 --sliceSpacing 15 --zrange 21 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${2}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${1}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
# Mount visions
convert -append ${1}_tmp_axial.png ${1}_tmp_sagittal.png ${1}_tmp_coronal.png +repage ${1}_${3}-${4}.png
rm ${1}_tmp*
mv ${1}_${3}-${4}.png ${5}/${3}-${4}/${6}_${7}_${1}_${3}-${4}.png
}

# Declare z-value
declare -A zvals
zvals=( [0.1]=1.64 [0.05]=1.96 [0.02]=2.33 [0.01]=2.58 [0.005]=2.81 [0.002]=3.09 [0.001]=3.29 )

sub=$1
lastses=$2
task=$3
pval=${4:-0.01}
wdr=${5:-/data}
tmp=${6:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/GLM/${task}/${sub} || exit

picdir=${wdr}/Mennes_replication/GLM/${task}/pics
if_missing_do mkdir ${picdir}
if_missing_do mkdir ${picdir}/p-${pval}

[ -z "${zvals[${pval}]}" ] || if_missing_do mkdir ${picdir}/q-${pval}

tmp=${tmp}/tmp.${sub}_${task}_p-${pval}_06ptg
replace_and mkdir ${tmp}

# Set the T1 in native space
bckimg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref

for sfx in spm #spm-IM
do
	# Check number of bricks and remove one cause 0-index
	lastbrick=$( fslval ${sub}_01_task-${task}_${sfx} dim5 )
	let lastbrick--
	for ses in $( seq -f %02g 1 ${lastses}; echo "allses" )
	do
		rbuck=${sub}_${ses}_task-${task}_${sfx}.nii.gz
		[ ! -e ${rbuck} ] && continue || echo "Exploding ${rbuck}"
		for brick in $(seq 0 ${lastbrick})
		do
			# Break bricks
			brickname=$( 3dinfo -label "${rbuck}[${brick}]" )
			3dbucket -prefix ${tmp}/${sub}_${ses}_${sfx}_${brickname}.nii.gz -abuc "${rbuck}[${brick}]" -overwrite
		done

		# Find right tstat value
		ndof=($( 3dinfo -verb ${rbuck} | grep statpar | awk -F " = " '{ print $3 }' ))
		printf "%s " "DoF found:" "${ndof[@]}"
		echo ""
		dof="${ndof[2]}"
		echo "DoF selected: ${dof}"
		thr=$( cdf -p2t fitt ${pval} ${dof} | awk -F " = " '{ print $2 }' )
		echo "thr: ${thr}"

		for brick in ${tmp}/${sub}_${ses}_${sfx}_*_Coef.nii.gz
		do
			echo ${brick}
			brickname=${brick%_Coef.nii.gz}
			# mask the functional brick with the right tstat
			fslmaths ${brickname}_Tstat -abs -thr ${thr} -bin -mul ${brick} ${brickname}_fmkd
			# fsleyes all the way
			slice_coeffs ${brickname} ${bckimg} p ${pval} ${picdir} ${sub} ${ses}

			[ -z "${zvals[${pval}]}" ] && continue || echo "Computing FDR with z=${zvals[${pval}]}"
			if_missing_do mkdir ${picdir}/q-${pval}
			3dFDR -input ${brickname}_Tstat.nii.gz -prefix ${brickname}_FDR.nii.gz
			fslmaths ${brickname}_FDR -thr ${zvals[${pval}]} -bin -mul ${brick} ${brickname}_fmkd
			slice_coeffs ${brickname} ${bckimg} q ${pval} ${picdir} ${sub} ${ses}
		done
	done
done

rm -rf ${tmp}

cd ${cwd}