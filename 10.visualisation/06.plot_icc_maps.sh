#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR_reliability

for map in cvr lag
do
	for ftype in echo-2 optcom meica-aggr meica-mvar meica-orth meica-preg
	do
		fsleyes render -of ICC2_${map}_${ftype} --size 1400 500 --scene lightbox --displaySpace reg/MNI_T1_brain.nii.gz --zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 8 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 70.0 --labelSize 18 --performance 3 reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 ICC2_${map}_${ftype}.nii.gz --name "ICC(2,1) ${map^^}" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso --displayRange 0.4 1.0 --clippingRange 0.4 100 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0
		fsleyes render -of ICC2_${map}_${ftype}_noclip --size 1400 500 --scene lightbox --displaySpace reg/MNI_T1_brain.nii.gz --zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 8 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 70.0 --labelSize 18 --performance 3 reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 ICC2_${map}_${ftype}.nii.gz --name "ICC(2,1) ${map^^}" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso --displayRange 0 1.0 --clippingRange 0 100 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0
	done
done

cd ${cwd}
