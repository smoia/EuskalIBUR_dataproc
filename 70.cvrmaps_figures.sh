#!/usr/bin/env bash

wdr=${1:-/data}

### Main ###

cwd=$( pwd )

cd ${wdr}

for sub in 007 003 002
do
	for ses in $( seq -f %02g 1 9 )
	do
		for ftype in echo-2 optcom meica
		do
			if [[ "${ftype}" == "meica" ]]
			then
				tval=2.7
			else
				tval=2.6
			fi
			echo "sub ${sub} ses ${ses} ftype ${ftype}"
			echo "cvr"
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.nii.gz \
			--name "cvr original" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.nii.gz \
			--name "cvr masked" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.nii.gz \
			--name "cvr corrected" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange 0.0 0.6 --clippingRange 0.0 10.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap.nii.gz \
			--name "tmap" --overlayType volume --alpha 100.0 --cmap red-yellow --negativeCmap blue-lightblue --useNegativeCmap \
			--displayRange ${tval} 50.0 --clippingRange ${tval} 100.0 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			echo "lag"
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.nii.gz \
			--name "cvr lag original" --overlayType volume --alpha 100.0 --cmap brain_colours_actc_iso --invert \
			--displayRange -9 9 --clippingRange -9 9 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected --size 1400 500 --scene lightbox --sliceSpacing 18 --zrange 21 131 \
			--ncols 6 --nrows 1 --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --showColourBar --colourBarLocation top \
			--colourBarLabelSide top-left --colourBarSize 50 --labelSize 11 \
			--performance 3 /media/nemo/ANVILData/gdrive/PJMASK/CVR/sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.nii.gz \
			--name "cvr lag corrected" --overlayType volume --alpha 100.0 --cmap brain_colours_actc_iso --invert \
			--displayRange -9 9 --clippingRange -9 9 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 \
			--smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_masked.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_corrected.png \
			tmp.${sub}_${ses}_${ftype}_1.png
			convert -append sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_tmap.png \
			sub-${sub}_ses-${ses}_${ftype}_map_cvr/sub-${sub}_ses-${ses}_${ftype}_cvr_lag_corrected.png \
			tmp.${sub}_${ses}_${ftype}_2.png
			convert -background black +append tmp.${sub}_${ses}_${ftype}_1.png tmp.${sub}_${ses}_${ftype}_2.png sub-${sub}_ses-${ses}_${ftype}.png
			rm tmp.${sub}_${ses}_${ftype}_?.png
		done
	done
done

cd ${cwd}
