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

brick=$1
wdr=${2:-/data}
sdr=${3:-/scripts}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Dataset_QC/icc || exit

picdir=${wdr}/Dataset_QC/pics
if_missing_do mkdir ${picdir}

# Set the T1 in MNI
bckimg=${sdr}/90.template/MNI152_T1_1mm_brain_resamp_2.5mm

icc=ICC2_${brick}
# fsleyes all the way
fsleyes render -of ${picdir}/${icc}_tmp_axial.png --size 1900 200 \
--scene lightbox --zaxis 2 --sliceSpacing 12 --zrange 19.3 139.9 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
${icc}.nii.gz --name "ICC(2,1)" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --displayRange 0.4 1.0 --clippingRange 0.4 1.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of  ${picdir}/${icc}_tmp_sagittal.png --size 1900 200 \
--scene lightbox --zaxis 0 --sliceSpacing 13 --zrange 39.5 169 --ncols 10 --nrows 1 --hideCursor --bgColour 1.0 1.0 1.0 --fgColour 0.0 0.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
 ${icc}.nii.gz --name "ICC(2,1)" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --displayRange 0.4 1.0 --clippingRange 0.4 1.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
fsleyes render -of  ${picdir}/${icc}_tmp_coronal.png --size 1900 200 \
--scene lightbox --zaxis 1 --sliceSpacing 15 --zrange 21 169 --ncols 10 --nrows 1 --hideCursor --bgColour 1.0 1.0 1.0 --fgColour 0.0 0.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
 ${icc}.nii.gz --name "ICC(2,1)" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --displayRange 0.4 1.0 --clippingRange 0.4 1.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
# Mount visions
convert -append  ${picdir}/${icc}_tmp_axial.png  ${picdir}/${icc}_tmp_sagittal.png  ${picdir}/${icc}_tmp_coronal.png +repage  ${picdir}/${icc}.png
rm  ${picdir}/${icc}_tmp*

cd ${cwd}