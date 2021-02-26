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
		* ) "and you shouldn't see this"; exit ;;
	esac
fi
}

replace_and() {
case $1 in
	mkdir) if [ -d $2 ]; then rm -rf $2; fi; mkdir $2 ;;
	touch) if [ -d $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

sub=$1
lastses=$2
task=$3
pval=${4:-0.01}
wdr=${5:-/data}
tmp=${6:-.}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/GLM/${task}/output || exit

picdir=${wdr}/Mennes_replication/GLM/${task}/pics
if_missing_do mkdir ${picdir}

tmp=${tmp}/tmp.${sub}_${task}_06ptg
replace_and mkdir ${tmp}

# Set the T1 in native space
bckimg=${wdr}/sub-${sub}/ses-01/reg/sub-${sub}_ses-01_T2w2sub-${sub}_sbref

# for sfx in spm spm-IM
# do
# 	# Check number of bricks and remove one cause 0-index
# 	lastbrick=$( fslval ${sub}_01_task-${task}_${sfx} dim5 )
# 	let lastbrick--
# 	for ses in $( seq -f %02g 1 ${lastses}; echo "allses" )
# 	do
# 		rbuck=${sub}_${ses}_task-${task}_${sfx}.nii.gz
# 		if [ ! -e ${rbuck} ]; then continue; else echo "Exploding ${rbuck}"; fi
# 		for brick in $(seq 0 ${lastbrick})
# 		do
# 			# Break bricks
# 			brickname=$( 3dinfo -verb ${rbuck} | grep 'brick #${brick} ' | awk -F "'" '{ print $2 }' )
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_${sfx}_${brickname}.nii.gz -abuc "${rbuck}[${brick}]" -overwrite
# 		done
# 	done
# done

# # Until it is not fixed, correctly rename GLT contrasts bricks
# for ses in $( seq -f %02g 1 ${lastses}; echo "allses" )
# do
# 	rbuck=${sub}_${ses}_task-${task}_${sfx}.nii.gz
# 	if [ ! -e ${rbuck} ]; then continue; else echo "Exploding ${rbuck}"; fi
# 	case ${task} in
# 		motor )
# 			rm ${tmp}/${sub}_${ses}_spm_*#1*.nii.gz
# 			# Two GLT are coded: all motor activations, and all motor activations against the sham to remove visual stimuli"
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_allmotors#0_Coef.nii.gz -abuc ${rbuck}'[13]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_allmotors#0_Tstat.nii.gz -abuc ${rbuck}'[14]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_allmotors_vs_sham#0_Coef.nii.gz -abuc ${rbuck}'[15]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_allmotors_vs_sham#0_Tstat.nii.gz -abuc ${rbuck}'[16]' -overwrite
# 		;;
# 		simon )
# 			rm ${tmp}/${sub}_${ses}_spm_*#1*.nii.gz ${tmp}/${sub}_${ses}_spm_*#2*.nii.gz ${tmp}/${sub}_${ses}_spm_*#3*.nii.gz
# 			# Four GLTs are coded, good congruents, good incongruents, good congruents vs good incongruents and good congruents + good incongruents
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_congruent#0_Coef.nii.gz -abuc ${rbuck}'[17]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_congruent#0_Tstat.nii.gz -abuc ${rbuck}'[18]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_incongruent#0_Coef.nii.gz -abuc ${rbuck}'[19]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_incongruent#0_Tstat.nii.gz -abuc ${rbuck}'[20]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_congruent_vs_incongruent#0_Coef.nii.gz -abuc ${rbuck}'[21]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_congruent_vs_incongruent#0_Tstat.nii.gz -abuc ${rbuck}'[22]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_congruent_and_incongruent#0_Coef.nii.gz -abuc ${rbuck}'[23]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_congruent_and_incongruent#0_Tstat.nii.gz -abuc ${rbuck}'[24]' -overwrite
# 		;;
# 		pinel )
# 			rm ${tmp}/${sub}_${ses}_spm_*#1*.nii.gz ${tmp}/${sub}_${ses}_spm_*#2*.nii.gz ${tmp}/${sub}_${ses}_spm_*#3*.nii.gz
# 			rm ${tmp}/${sub}_${ses}_spm_*#4*.nii.gz ${tmp}/${sub}_${ses}_spm_*#5*.nii.gz ${tmp}/${sub}_${ses}_spm_*#6*.nii.gz
# 			rm ${tmp}/${sub}_${ses}_spm_*#7*.nii.gz ${tmp}/${sub}_${ses}_spm_*#8*.nii.gz ${tmp}/${sub}_${ses}_spm_*#9*.nii.gz
# 			rm ${tmp}/${sub}_${ses}_spm_*#10*.nii.gz ${tmp}/${sub}_${ses}_spm_*#11*.nii.gz ${tmp}/${sub}_${ses}_spm_*#12*.nii.gz
# 			rm ${tmp}/${sub}_${ses}_spm_*#13*.nii.gz
# 			# Pinel models 8 contrasts: right vs left hand, vertical vs horizontal checkers, auditory stims, visual stims, 
# 			# auditory calc vs auditory noncalc, visual calc vs visual noncalc, auditory vs visual, visual vs checkerboards.
# 			# Added all sentences, all motor, all calculus, all motor vs sentences, all calculus vs sentences.
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_right_vs_left#0_Coef.nii.gz -abuc ${rbuck}'[21]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_right_vs_left#0_Tstat.nii.gz -abuc ${rbuck}'[22]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_vertical_vs_horizontal_cb#0_Coef.nii.gz -abuc ${rbuck}'[23]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_vertical_vs_horizontal_cb#0_Tstat.nii.gz -abuc ${rbuck}'[24]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_auditory#0_Coef.nii.gz -abuc ${rbuck}'[25]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_auditory#0_Tstat.nii.gz -abuc ${rbuck}'[26]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_visual#0_Coef.nii.gz -abuc ${rbuck}'[27]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_visual#0_Tstat.nii.gz -abuc ${rbuck}'[28]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_auditory_calc_vs_noncalc#0_Coef.nii.gz -abuc ${rbuck}'[29]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_auditory_calc_vs_noncalc#0_Tstat.nii.gz -abuc ${rbuck}'[30]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_visual_calc_vs_noncalc#0_Coef.nii.gz -abuc ${rbuck}'[31]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_visual_calc_vs_noncalc#0_Tstat.nii.gz -abuc ${rbuck}'[32]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_auditory_vs_visual#0_Coef.nii.gz -abuc ${rbuck}'[33]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_auditory_vs_visual#0_Tstat.nii.gz -abuc ${rbuck}'[34]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_visual_vs_cb#0_Coef.nii.gz -abuc ${rbuck}'[35]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_visual_vs_cb#0_Tstat.nii.gz -abuc ${rbuck}'[36]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_sentences#0_Coef.nii.gz -abuc ${rbuck}'[37]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_sentences#0_Tstat.nii.gz -abuc ${rbuck}'[38]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_motor#0_Coef.nii.gz -abuc ${rbuck}'[39]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_motor#0_Tstat.nii.gz -abuc ${rbuck}'[40]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_calc#0_Coef.nii.gz -abuc ${rbuck}'[41]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_calc#0_Tstat.nii.gz -abuc ${rbuck}'[42]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_motor_vs_sentences#0_Coef.nii.gz -abuc ${rbuck}'[43]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_motor_vs_sentences#0_Tstat.nii.gz -abuc ${rbuck}'[44]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_calc_vs_sentences#0_Coef.nii.gz -abuc ${rbuck}'[45]' -overwrite
# 			3dbucket -prefix ${tmp}/${sub}_${ses}_spm_all_calc_vs_sentences#0_Tstat.nii.gz -abuc ${rbuck}'[46]' -overwrite
# 		;;
# 		* ) echo "    !!! Warning !!! Invalid task: ${task}"; exit ;;
# 	esac
# done

for sfx in spm spm-IM
do
	for ses in $( seq -f %02g 1 ${lastses}; echo "allses" )
	do
		rbuck=${sub}_${ses}_task-${task}_${sfx}.nii.gz
		if [ ! -e ${rbuck} ]; then continue; else echo "Plot ${rbuck}"; fi
		# Find right tstat value
		ndof=($( 3dinfo -verb ${rbuck} | grep statpar | awk -F " = " '{ print $3 }' ))
		printf "%s " "DoF found:" "${ndof[@]}"
		echo ""
		dof="${ndof[3]}"
		echo "DoF selected: ${dof}"
		thr=$( cdf -p2t fitt ${pval} ${dof} )
		echo "thr: ${thr}"

		for brick in $(ls ${tmp}/${sub}_${ses}_${sfx}*_Coef.nii.gz)
		do
			echo ${brick}
			brickname=${brick%%_Coef.nii.gz}
			# mask the functional brick with the right tstat
			fslmaths ${brickname}_Tstat -abs -thr ${thr} -bin -mul ${brick} ${brickname}_fmkd
			# fsleyes all the way
			fsleyes render -of ${brickname}_tmp_axial.png --size 1900 200 \
			--scene lightbox --zaxis 2 --sliceSpacing 12 --zrange 19.3 139.9 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
			${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --modulateRange 0.0 625.6470947265625 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${brickname}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${brickname}_tmp_sagittal.png --size 1900 200 \
			--scene lightbox --zaxis 0 --sliceSpacing 13 --zrange 39.5 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
			${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --modulateRange 0.0 625.6470947265625 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${brickname}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			fsleyes render -of ${brickname}_tmp_coronal.png --size 1900 200 \
			--scene lightbox --zaxis 1 --sliceSpacing 15 --zrange 21 169 --ncols 10 --nrows 1 --hideCursor --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 12 --performance 3 --movieSync \
			${bckimg}.nii.gz --name "anat" --overlayType volume --alpha 100.0 --brightness 49.75000000000001 --contrast 49.90029860765409 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 631.9035656738281 --clippingRange 0.0 631.9035656738281 --modulateRange 0.0 625.6470947265625 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \
			${brickname}_fmkd.nii.gz --name "beta" --overlayType volume --alpha 100.0 --cmap brain_colours_1hot --negativeCmap cool --useNegativeCmap --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
			# Mount visions
			convert -append ${brickname}_tmp_axial.png ${brickname}_tmp_sagittal.png ${brickname}_tmp_coronal.png +repage ${brickname}.png
			rm ${brickname}_tmp*
		done
	done
done

mv ${tmp}/*.png ${picdir}/.

# rm -rf ${tmp}/${task}

cd ${cwd}