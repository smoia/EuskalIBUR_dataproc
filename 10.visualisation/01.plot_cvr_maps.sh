#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr}/CVR

for sub in 001 002 003 004 007 008 009
do
	# Get the right brain mask from the subject folder file
	mask=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_sbref_brain_mask.nii.gz

	for ses in $( seq -f %02g 1 10 )
	do
		for ftype in echo-2 optcom meica-aggr meica-orth meica-cons
		do
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			echo "cvr"
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.nii.gz \
			--name "CVR_(unmasked)" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			
			# In order: unthresholded semitransparent, thresholded, thresholded borders, thresholded tansparent (for colorbar)
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.nii.gz \
			--name "CVR" --overlayType volume --alpha 40.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.nii.gz \
			--name "CVR" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.nii.gz \
			--name "CVR" --overlayType mask --alpha 100.0 --brightness 50.0 --contrast 50.0 --maskColour 0.0 0.0 0.0 \
			--threshold 0.0 10 --outline --outlineWidth 1 --interpolation none --volume 0 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.nii.gz \
			--name "CVR" --overlayType volume --alpha 0.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0

			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.nii.gz \
			--name "CVR_(corrected)" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked.nii.gz \
			--name "tmap" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue \
			--useNegativeCmap --displayRange 0 50.0 --clippingRange 0 100.0 --gamma 0.0 --cmapResolution 256 --interpolation none \
			--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0

			echo "lag"

			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${mask} --name "mask" --disabled --overlayType volume --alpha 100.0 \
			--brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --unlinkLowRanges --displayRange 0.0 1.0 \
			--clippingRange 0.0 1.01 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.nii.gz \
			--name "CVR_lag" --overlayType volume --alpha 100.0 --cmap viridis --invert \
			--clipImage ${mask} --displayRange -5.0 5.0 --clippingRange 0.0 1.01 \
			--gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 \
			--blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected \
			--size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 --performance 3 \
			${mask} --name "mask" --disabled --overlayType volume --alpha 100.0 \
			--brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --unlinkLowRanges --displayRange 0.0 1.0 \
			--clippingRange 0.0 1.01 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${wdr}/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.nii.gz \
			--name "CVR_lag_(corrected)" --overlayType volume --alpha 100.0 --cmap viridis --invert \
			--clipImage ${mask} --displayRange -5.0 5.0 --clippingRange 0.0 1.01 \
			--gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 \
			--blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.png \
			+repage tmp.01pcm_${sub}_${ses}_${ftype}_1.png
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap_masked.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.png \
			+repage tmp.01pcm_${sub}_${ses}_${ftype}_2.png
			convert -background black +append tmp.01pcm_${sub}_${ses}_${ftype}_1.png tmp.01pcm_${sub}_${ses}_${ftype}_2.png \
			+repage sub-${sub}_ses-${ses}_${ftype}.png
			rm tmp.01pcm_${sub}_${ses}_${ftype}_?.png
		done
	done

	# Creating Alltypes all sessions maps
	for map in cvr lag
	do
		# Choose the right crop position for the right map
		case ${map} in
			cvr ) cropsize="192x265+488+670"; cropbar="744x70+320+520" ;;
			lag ) cropsize="192x265+1888+160"; cropbar="744x70+1726+22" ;;
			* ) echo "This shouldn't be happening: map ${map}"; exit ;;
		esac
		# Crop the colourbar
		convert sub-${sub}_ses-01_echo-2.png -crop ${cropbar} +repage tmp.01pcm_${sub}_colourbar_${map}.png
		# Start composing the append cmd
		appending="convert -background black -gravity South -append"
		for ftype in echo-2 optcom meica-aggr meica-orth meica-cons
		do
			for ses in $( seq -f %02g 1 10 )
			do
				echo "sub ${sub} ses ${ses} ftype ${ftype}"
				# crop the right image
				convert sub-${sub}_ses-${ses}_${ftype}.png -crop ${cropsize} +repage tmp.01pcm_${sub}_${ses}_${ftype}_${map}.png
			done
			# append all the session (row)
			convert +append tmp.01pcm_${sub}_??_${ftype}_${map}.png +repage tmp.01pcm_${sub}_${ftype}_${map}.png
			appending="${appending} tmp.01pcm_${sub}_${ftype}_${map}.png"
		done
		# Append colourbar
		appending="${appending} tmp.01pcm_${sub}_colourbar_${map}.png +repage tmp.01pcm_sub-${sub}_alltypes_${map}.png"
		${appending}
		composite -geometry +60+40 tmp.01pcm_sub-${sub}_alltypes_${map}.png ${scriptdir}/10.visualisation/canvas/Alltypes_canvas.png +repage sub-${sub}_alltypes_${map}.png
	done
done

rm tmp.01pcm_*

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

mv *.png ${wdr}/plots/.

cd ${cwd}
