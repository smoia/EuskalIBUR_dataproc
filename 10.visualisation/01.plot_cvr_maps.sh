#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR

for sub in 001 002 003 004 007 008 009
do
	for ses in $( seq -f %02g 1 10 )
	do
		for ftype in echo-2 optcom meica-aggr meica-orth meica-cons all-orth 
		do
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			echo "cvr"
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.nii.gz \
			--name "cvr_original" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.nii.gz \
			--name "cvr_masked" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.nii.gz \
			--name "cvr_corrected" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked.nii.gz \
			--name "tmap" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0 50.0 --clippingRange 0 100.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			echo "lag"
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.nii.gz \
			--name "cvr_lag_original" --overlayType volume --alpha 100.0 --cmap brain_colours_actc_iso --invert \
			--displayRange -5 5 --clippingRange -9 9 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.nii.gz \
			--name "cvr_lag_corrected" --overlayType volume --alpha 100.0 --cmap brain_colours_actc_iso --invert \
			--displayRange -5 5 --clippingRange -9 9 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.png \
			+repage tmp.01pcm_${sub}_${ses}_${ftype}_1.png
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.png \
			+repage tmp.01pcm_${sub}_${ses}_${ftype}_2.png
			convert -background black +append tmp.01pcm_${sub}_${ses}_${ftype}_1.png tmp.01pcm_${sub}_${ses}_${ftype}_2.png +repage sub-${sub}_ses-${ses}_${ftype}.png
			rm tmp.01pcm_${sub}_${ses}_${ftype}_?.png
		done
	done

	# Creating full sessions maps
	appending="convert -append"
	for ftype in echo-2 optcom meica-aggr meica-orth meica-cons all-orth 
	do
		for ses in $( seq -f %02g 1 10 )
		do
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			convert sub-${sub}_ses-${ses}_${ftype}.png -crop 234x265+466+642 +repage tmp.01pcm_${sub}_${ses}_${ftype}.png
		done
		convert +append tmp.01pcm_${sub}_??_${ftype}.png +repage tmp.01pcm_${sub}_${ftype}.png
		appending="${appending} tmp.01pcm_${sub}_${ftype}.png"
	done
	appending="${appending} +repage sub-${sub}_alltypes.png"
	${appending}
done

rm tmp.01pcm_*

cd ${cwd}
