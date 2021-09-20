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
	touch) if [ -e $2 ]; then rm -rf $2; fi; touch $2 ;;
esac
}

task=$1
wdr=${2:-/data}
sdr=${3:-/scripts}
tmp=${4:-/tmp}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Dataset_QC/pics || exit

picdir=${wdr}/Dataset_QC/pics/final
if_missing_do mkdir ${picdir}

tmp=${tmp}/${task}_14pcim

replace_and mkdir ${tmp}

case ${task} in
	motor )
		bricks=( tongue_vs_sham_0 finger_right_vs_sham_0 finger_left_vs_sham_0 toe_right_vs_sham_0 toe_left_vs_sham_0 )
		;;
	simon )
		bricks=( all_congruent_0 all_incongruent_0 congruent_vs_incongruent_0 congruent_and_incongruent_t_0 )
		;;
	pinel )
		bricks=( all_visual_0 all_auditory_0 all_motor_0 all_sentences_0 all_calc_0 vertical_vs_horizontal_cb_0 all_calc_vs_sentences_0 all_motor_vs_sentences_0 auditory_vs_visual_0 visual_vs_cb_0 auditory_calc_vs_noncalc_0 visual_calc_vs_noncalc_0 right_vs_left_0 )
		;;
	falff )
		bricks=( fALFF_run-01 fALFF_run-02 fALFF_run-03 fALFF_run-04 )
		;;
	alff )
		bricks=( ALFF_run-01 ALFF_run-02 ALFF_run-03 ALFF_run-04 )
		;;
	rsfa )
		bricks=( RSFA_run-01 RSFA_run-02 RSFA_run-03 RSFA_run-04 )
		;;
	* ) echo "Nothing to be seen"; exit
		;;
esac

for sub in 001 002 003 004 007 008 009
do
	runMEMAconvert="convert"
	nbricks=${#bricks[@]}
	let nbricks--
	for n in $( seq 0 ${nbricks} )
	do
		convert ${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png -crop 1900x195+0+0 +repage ${tmp}/ax.png
		convert ${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png -crop 172x192+911+408 +repage ${tmp}/c1.png
		convert ${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png -crop 172x192+1272+408 +repage ${tmp}/c2.png
		composite -geometry +71+0 ${tmp}/c1.png ${tmp}/ax.png +repage ${tmp}/l1.png
		composite -geometry +234+0 ${tmp}/c2.png ${tmp}/l1.png +repage ${tmp}/l2.png
		if [ ${n} -lt ${nbricks} ]
		then
			mv ${tmp}/l2.png ${tmp}/${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png
			# convert ${tmp}/l2.png -fill black -draw "rectangle 1805,0 1900,195" ${tmp}/${bricks[$n]}_${bricks[$n]}_q-0.05.png
		else
			mv ${tmp}/l2.png ${tmp}/${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png
		fi
		runMEMAconvert="${runMEMAconvert} ${tmp}/${bricks[$n]}_sub-${sub}_${bricks[$n]}_q-0.05.png"
	done
	runMEMAconvert="${runMEMAconvert} -background black -splice 0x30+0+0 -append +repage ${tmp}/${task}_sub-${sub}_${task}_q-0.05.png"
	echo "+++ ${runMEMAconvert}"
	eval ${runMEMAconvert}
	composite -geometry +0+0 ${sdr}/10.visualisation/canvas/${task}_tasks_overlay.png ${tmp}/${task}_sub-${sub}_${task}_q-0.05.png ${picdir}/${task}_sub-${sub}_${task}_q-0.05.png
done

cd ${cwd}