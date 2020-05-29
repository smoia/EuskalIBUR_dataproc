#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}
tmp=${3:-/tmp}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR_reliability

if [ -d ${tmp}/tmp.07pcm ]
then
	rm -rf ${tmp}/tmp.07pcm
fi

mkdir ${tmp}/tmp.07pcm

for mtype in masked  # corrected masked
do
	for sub in 001 002 003 004 007 008 009
	do
		for map in cvr lag
		do
			appending="convert -append"
			appending_noclip="convert -append"

			map=${map}_${mtype}
			for ftype in echo-2 optcom meica-aggr meica-orth meica-cons all-orth
			do
				echo "CoV_${sub}_${map}_${ftype}"
				fsleyes render -of CoV_${sub}_${map}_${ftype} --size 1400 500 --scene lightbox --displaySpace reg/MNI_T1_brain.nii.gz \
						--zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 6 --nrows 1 --hideCursor --showColourBar \
						--colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 70.0 --labelSize 18 \
						--performance 3 reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume --alpha 100.0 \
						--brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 \
						--gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 \
						--numInnerSteps 10 --volume 0 CoV_${sub}_${map}_${ftype}.nii.gz --name "CoV_${map}" --overlayType volume \
						--alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso --negativeCmap blue-lightblue \
						--useNegativeCmap --displayRange 0 5.0 --clippingRange 0 100000 --gamma 0.0 --cmapResolution 256 \
						--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0

				convert CoV_${sub}_${map}_${ftype}.png -filter Point -resize 1035x370 +repage -crop 920x212+15+70 +repage ${tmp}/tmp.07pcm/CoV_${sub}_${map}_${ftype}_res.png

				appending="${appending} ${tmp}/tmp.07pcm/CoV_${sub}_${map}_${ftype}_res.png"
			done

			appending="${appending} +repage ${tmp}/tmp.07pcm/CoV_${sub}_${map}_app.png"
			${appending}
		done
		composite ${tmp}/tmp.07pcm/CoV_${sub}_cvr_${mtype}_app.png ${scriptdir}/10.visualisation/canvas/CoV_canvas.png +repage ${tmp}/tmp.07pcm/CoV_${sub}_cvr_${mtype}.png
		composite -geometry +990+0 ${tmp}/tmp.07pcm/CoV_${sub}_lag_${mtype}_app.png ${tmp}/tmp.07pcm/CoV_${sub}_cvr_${mtype}.png +repage CoV_${sub}_${mtype}.png
	done
done

rm -rf ${tmp}/tmp.07pcm

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

mv *.png ${wdr}/plots/.

cd ${cwd}
