#!/usr/bin/env bash

wdr=${1:-/data}
scriptdir=${2:-/scripts}
tmp=${3:-/tmp}

### Main ###

cwd=$( pwd )

if [ -e ${tmp}/tmp.05pcc ]; then rm -rf ${tmp}/tmp.05pcc; fi

mkdir ${tmp}/tmp.05pcc

cd ${tmp}/tmp.05pcc

nbuck=$(fslval ${wdr}/CVR_reliability/LMEr_cvr_masked_physio_only.nii.gz dim5)

let nbuck--

for map in cvr lag
do
	# Separate buckets
	for i in $(seq 0 ${nbuck})
	do
		echo "Extract bucket ${i}"
		3dbucket -prefix ${map}_buck${i}.nii.gz -abuc ${wdr}/CVR_reliability/LMEr_${map}_masked_physio_only.nii.gz[$i]
	done

	# Threshold model chi square and mask
	# Chi 5.991 = p 0.05
	fslmaths ${map}_buck0 -abs -thr 5.991 -bin ${map}_buck0
	# Threshold all Z maps
	# Z 2.807 = p 0.005 (0.5 Sidak corrected for 10 comparisons) 
	for i in $(seq 2 2 ${nbuck})
	do
		fslmaths ${map}_buck${i}.nii.gz -abs -thr 2.807 -bin ${map}_buck${i}.nii.gz
	done

	# Plot
	appending="convert -append"

	for i in $(seq 1 2 ${nbuck})
	do
		let j=i+1
		# case ${i} in
		# 	01 ) name=echo-2_vs_optcom ;;
		# 	03 ) name=echo-2_vs_meica-aggr ;;
		# 	05 ) name=echo-2_vs_meica-orth ;;
		# 	07 ) name=echo-2_vs_meica-cons ;;
		# 	09 ) name=optcom_vs_meica-aggr ;;
		# 	11 ) name=optcom_vs_meica-orth ;;
		# 	13 ) name=optcom_vs_meica-cons ;;
		# 	15 ) name=meica-aggr_vs_meica-orth ;;
		# 	17 ) name=meica-aggr_vs_meica-cons ;;
		# 	19 ) name=meica-orth_vs_meica-cons ;;
		# 	21 ) name=all_models ;;
		# esac
		if [ ${i} -lt 20 ]
		then
			appending="${appending} LMEr_${map}${i}_res.png"
			if [ ${map} == "cvr" ]
			then
				dr=1
			else
				dr=5
			fi
		else
			j=0
			dr=100
		fi

		# In order: MNI, unthresholded semitransparent, thresholded, thresholded borders, thresholded tansparent (for colorbar)
		fsleyes render -of LMEr_${map}${i}.png --size 1400 500 --scene lightbox \
				--displaySpace ${wdr}/CVR_reliability/reg/MNI_T1_brain.nii.gz \
				--zaxis 2 --sliceSpacing 21.4 --zrange 15.55 178.75 --ncols 6 --nrows 1 \
				--hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right \
				--colourBarSize 70.0 --labelSize 18 --performance 3 \
				${wdr}/CVR_reliability/reg/MNI_T1_brain.nii.gz --name "MNI_T1_brain" --overlayType volume \
				--alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --displayRange 0.0 8337.0 \
				--clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --numSteps 100 --blendFactor 0.1 \
				--smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 \
				${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				--alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap actc_iso_pos \
				--negativeCmap actc_iso_neg --useNegativeCmap --clipImage cvr_buck${j}.nii.gz \
				--unlinkLowRanges --displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 \
				--cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 \
				--resolution 100 --numInnerSteps 10 --volume 0 \
				${map}_buck${j}.nii.gz --name "${map}_buck${j}" --overlayType mask \
				--alpha 0.0 --brightness 50.0 --contrast 50.0 --maskColour 0.0 0.0 0.0 \
				--threshold 0.4 100 --outline --outlineWidth 1 --interpolation none --volume 0 \
				${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				--alpha 0.0 --brightness 50.0 --contrast 50.0 --cmap actc_iso_pos \
				--negativeCmap actc_iso_neg --useNegativeCmap \
				--unlinkLowRanges --displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 \
				--cmapResolution 256 --numSteps 100 --blendFactor 0.1 --smoothing 0 \
				--resolution 100 --numInnerSteps 10 --volume 0
				# --alpha 100.0 --brightness 50.0 --contrast 50.0 --maskColour 0.0 0.0 0.0 \
				# ${map}_buck${i}.nii.gz --name "${map}_buck${i}" --overlayType volume \
				# --alpha 30.0 --brightness 50.0 --contrast 50.0 --cmap brain_colours_1hot_iso \
				# --negativeCmap cool --useNegativeCmap \
				# --displayRange 0 ${dr} --clippingRange 0 100 --gamma 0.0 --cmapResolution 256 \
				# --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --volume 0 \

		convert LMEr_${map}${i}.png -filter Point -resize 1035x370 +repage -crop 920x212+15+70 +repage LMEr_${map}${i}_res.png

	done
	appending="${appending} +repage LMEr_${map}_app.png"
	${appending}
done

## Adding to canvas
composite LMEr_cvr21_res.png ${scriptdir}/10.visualisation/canvas/LMEr_canvas.png +repage LMEr_cvr_oncanvas_1.png
composite -geometry +990+0 LMEr_lag21_res.png LMEr_cvr_oncanvas_1.png +repage LMEr_cvr_oncanvas_2.png
composite -geometry +0+353 LMEr_cvr_app.png LMEr_cvr_oncanvas_2.png +repage LMEr_cvr_oncanvas_3.png
composite -geometry +990+353 LMEr_lag_app.png LMEr_cvr_oncanvas_3.png +repage LMEr.png


if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

mv LMEr.png ${wdr}/plots/.

cd ${cwd}

# rm -rf ${tmp}/tmp.05pcc*
