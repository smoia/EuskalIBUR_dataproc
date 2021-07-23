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
pval=$2
wdr=${3:-/data}
sdr=${4:-/scripts}
tmp=${5:-/tmp}

### print input
printline=$( basename -- $0 )
echo "${printline} " "$@"
######################################
######### Script starts here #########
######################################

cwd=$(pwd)

cd ${wdr}/Mennes_replication/pics/lme || exit

picdir=${wdr}/Mennes_replication/pics/lme/final
if_missing_do mkdir ${picdir}

tmp=${tmp}/${task}_12pcim

replace_and mkdir ${tmp}

bricks=( CVR_cvr RSFA_r-01_RSFA ALFF_r-01_ALFF fALFF_r-01_fALFF )
case ${task} in
	motor )
		contrasts=( motors_vs_sham )
		canvas=${sdr}/10.visualisation/canvas/CVR_tIA_RS_overlay.png

		;;
	simon )
		contrasts=( all_congruent all_incongruent congruent_and_incongruent )
		canvas=${sdr}/10.visualisation/canvas/CVR_tIA_RS_overlay.png
		;;
	falff )
		contrasts=( ${bricks[0]} )
		bricks=( ${bricks[@]:1} )
		bricks=( ${bricks[@]%_*} )
		canvas=${sdr}/10.visualisation/canvas/CVR_RS_overlay.png
		;;
	* ) echo "Nothing to be seen"; exit
		;;
esac

nbricks=${#bricks[@]}
let nbricks--
ncontrasts=${#contrasts[@]}
let ncontrasts--
for m in $( seq 0 ${ncontrasts} )
do
	runconvert="convert"
	for n in $( seq 0 ${nbricks} )
	do
		[ ${task} == "falff" ] && img=${task}/${bricks[$n]}_${contrasts[$m]}_${pval}.png || img=${task}/${contrasts[$m]}_${bricks[$n]}_${pval}.png
		convert ${img} -crop 1900x195+0+0 +repage ${tmp}/ax.png
		convert ${img} -crop 172x192+911+408 +repage ${tmp}/c1.png
		convert ${img} -crop 172x192+1272+408 +repage ${tmp}/c2.png
		composite -geometry +71+0 ${tmp}/c1.png ${tmp}/ax.png +repage ${tmp}/l1.png
		composite -geometry +234+0 ${tmp}/c2.png ${tmp}/l1.png +repage ${tmp}/l2.png
		if [ ${n} -lt ${nbricks} ]
		then
			mv ${tmp}/l2.png ${tmp}/${task}_${bricks[$n]}.png
			# convert ${tmp}/l2.png -fill black -draw "rectangle 1805,0 1900,195" ${tmp}/${task}_${bricks[$n]}.png
		else
			mv ${tmp}/l2.png ${tmp}/${task}_${bricks[$n]}.png
		fi
		runconvert="${runconvert} ${tmp}/${task}_${bricks[$n]}.png"
	done

	runconvert="${runconvert} -background black -splice 0x30+0+0 -append +repage ${tmp}/${task}_${contrasts[$m]}.png"
	echo "+++ ${runconvert}"
	eval ${runconvert}
	composite -geometry +0+0 ${canvas} ${tmp}/${task}_${contrasts[$m]}.png ${picdir}/${task}_${contrasts[$m]}_${pval}.png

done

rm -rf ${tmp}

cd ${cwd}