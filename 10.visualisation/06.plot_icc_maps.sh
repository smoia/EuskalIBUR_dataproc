#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR_reliability

mkdir tmp.06pim

for mtype in corrected masked
do
	for map in cvr lag
	do
		appending="convert -append"

		map=${map}_${mtype}
		for ftype in echo-2 optcom meica-aggr meica-mvar meica-orth meica-cons
		do
			echo "ICC2_${map}_${ftype}"
			fsleyes render -of ICC2_${map}_${ftype} --size 1400 500 --scene lightbox --displaySpace reg/MNI_T1_brain.nii.gz --zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 6 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 70.0 --labelSize 18 --performance 3 reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 ICC2_${map}_${ftype}.nii.gz --name "ICC(2,1) ${map^^}" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso --displayRange 0.4 1.0 --clippingRange 0.4 100 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0
			fsleyes render -of ICC2_${map}_${ftype}_noclip --size 1400 500 --scene lightbox --displaySpace reg/MNI_T1_brain.nii.gz --zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 6 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 70.0 --labelSize 18 --performance 3 reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 ICC2_${map}_${ftype}.nii.gz --name "ICC(2,1) ${map^^}" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso --displayRange 0 1.0 --clippingRange 0 100 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0
			convert ICC2_${map}_${ftype}.png -filter Point -resize 1035x370 +repage -crop 920x212+5+70 tmp.06pim/ICC2_${map}_${ftype}_res.png

			appending="${appending} tmp.06pim/ICC2_${map}_${ftype}_res.png"
		done

		appending="${appending} tmp.06pim/ICC2_${map}_app.png"
		${appending}
	done
	montage ${scriptdir}/10.visualisation/canvas/ICC_canvas.png -page +0+0 tmp.06pim/ICC2_cvr_${mtype}_app.png -page +1000+0 tmp.06pim/ICC2_lag_${mtype}_app.png ICC2_cvr_${mtype}.png
done

rm -rf tmp.06pim

cd ${cwd}
