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
	touch) if [ -e $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

sub=$1
lastses=$2
run=$3
wdr=${4:-/data}
tmp=${5:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/fALFF || exit

picdir=${wdr}/Mennes_replication/fALFF/pics/run-${run}
if_missing_do mkdir ${picdir%/*}
if_missing_do mkdir ${picdir}

tmp=${tmp}/tmp.${sub}_${run}_08pf
replace_and mkdir ${tmp}

# Set the T1 in native space
bckimg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref

# Check number of bricks and remove one cause 0-index
for ses in $( seq -f %02g 1 ${lastses} )
do
	falff=sub-${sub}_ses-${ses}_task-rest_run-${run}_fALFF
	# fsleyes all the way
	fsleyes render -of ${picdir}/${sub}_${ses}_r-${run}_fALFF.png --size 1900 200 \
	--scene lightbox --zaxis 2 --sliceSpacing 12 --zrange 19.3 139.9 --ncols 10 --nrows 1 --hideCursor --bgColour 1.0 1.0 1.0 --fgColour 0.0 0.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
	${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
	${falff}.nii.gz --name "fALFF" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
done

rm -rf ${tmp}

cd ${cwd}