#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}
tmp=${3:-/tmp}

### Main ###

cwd=$( pwd )

mkdir ${tmp}/tmp.05pcc

cd ${tmp}/tmp.05pcc

nbuck=$(fslval LMEr_cvr_masked_physio_only.nii.gz dim5)

let nbuck--

for map in cvr lag
do
	# Separate buckets
	for i in $(seq -f %04g 0 ${nbuck})
	do
		3dbucket -prefix ${map}_buck${i}.nii.gz -abuc ${wdr}/CVR_reliability/LMEr_${map}_masked_physio_only.nii.gz[$i]
	done

	# Threshold model chi square and mask
	# Chi 5.991 = p 0.05
	fslmaths ${map}_buck0000 -thr 5.991 -bin ${map}_buck0000
	# Threshold all Z maps
	# Z 2.807 = p 0.005 (0.5 Sidak corrected for 10 comparisons) 
	for i in $(seq -f %04g 2 2 ${nbuck})
	do
		fslmaths ${map}_buck${i}.nii.gz -thr 2.807 -bin ${map}_buck${i}.nii.gz
	done

	# Plot
	appending="convert -append"

	for i in $(seq -f %04g 1 2 ${nbuck})
	do
		let j=i+1
		# case ${i} in
		# 	0001 ) name=echo-2_vs_optcom ;;
		# 	0003 ) name=echo-2_vs_meica-aggr ;;
		# 	0005 ) name=echo-2_vs_meica-orth ;;
		# 	0007 ) name=echo-2_vs_meica-cons ;;
		# 	0009 ) name=optcom_vs_meica-aggr ;;
		# 	0011 ) name=optcom_vs_meica-orth ;;
		# 	0013 ) name=optcom_vs_meica-cons ;;
		# 	0015 ) name=meica-aggr_vs_meica-orth ;;
		# 	0017 ) name=meica-aggr_vs_meica-cons ;;
		# 	0019 ) name=meica-orth_vs_meica-cons ;;
		# 	0021 ) name=all_models ;;
		# esac
		if [ ${i} -lt 20 ]
		then
			appending="${appending} LMEr_${map}${i}_res.png"
			dr=5
		else
			dr=100
		fi

		# In order: MNI, unthresholded semitransparent, thresholded, thresholded borders, thresholded tansparent (for colorbar)
		fsleyes render -of LMEr_${map}${i} --size 1400 500 --scene lightbox \
				--displaySpace ${wdr}/CVR_reliability/reg/MNI_T1_brain.nii.gz \
				--zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 6 --nrows 1 \
				--hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right \
				--colourBarSize 70.0 --labelSize 18 --performance 3 \
				${wdr}/CVR_reliability/reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume \
				--alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 \
				--clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 \
				--smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 \
				${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				--alpha 30.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso \
				--negativeCmap cool --useNegativeCmap \
				--displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 --cmapResolution 256 \
				--numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 \
				${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				--alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso \
				--negativeCmap cool --useNegativeCmap \
				--unlinkLowRanges --displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 \
				--cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 \
				--resolution 100 --numInnerSteps 10 --volume 0 \
				${map}_buck${j}.nii.gz --name "${map}_buck${j}" --overlayType mask \
				--alpha 100.0 --brightness 50.0 --contrast 50.0 --maskColour 0.0 0.0 0.0 \
				--threshold 0.4 100 --outline --outlineWidth 1 --interpolation none --volume 0 \
				${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				--alpha 0.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso \
				--negativeCmap cool --useNegativeCmap \
				--unlinkLowRanges --displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 \
				--cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 \
				--resolution 100 --numInnerSteps 10 --volume 0

		convert LMEr_${map}${i}.png -filter Point -resize 1035x370 +repage -crop 920x212+15+70 +repage LMEr_${map}${i}_res.png

	done
	appending="${appending} +repage LMEr_${map}_app.png"
	${appending}
done

## Adding to canvas
composite LMEr_cvr_app.png ${scriptdir}/10.visualisation/canvas/LMEr_canvas.png +repage LMEr_cvr_oncanvas.png
composite -geometry +990+0 LMEr_lag_app.png LMEr_cvr_oncanvas.png +repage LMEr.png


# if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

# mv LMEr.png ${wdr}/plots/.

cd ${cwd}

# rm -rf ${tmp}/tmp.05pcc*
