for m in {0..4}
do
	for n in {2..120}
	do
		echo "$m $n"
		fslmaths rand_parc/${n}-${m}-parc.nii.gz -dilall -mas MNI152_T1_1mm_GM_resamp_2.5mm.nii.gz rand_atlas/rand-${n}-${m} -odt int
	done
done

for m in `seq 0 4`
do
	for n in `seq 2 120`
	do
		for o in `seq 3 15`
		do
			echo "----------------------"
			echo "$m $n $o"
			for i in `seq 1 $n`
			do
				fslmaths rand_parc/${n}-${m}-parc.nii.gz -thr $i -uthr $i tmp/$i
				3dmask_tool -inputs tmp/${i}.nii.gz -dilate_inputs $o -prefix tmp/${i}.nii.gz -overwrite
				fslmaths tmp/$i -mul $i tmp/$i
			done
			fslmaths tmp/1 rand_atlas/rand-${n}p-${o}s-${m}r 
			for i in `seq 2 $n`
			do
				fslmaths tmp/$i -mas rand_atlas/rand-${n}p-${o}s-${m}r -sub tmp/$i -mul -1 -add rand_atlas/rand-${n}p-${o}s-${m}r rand_atlas/rand-${n}p-${o}s-${m}r
			done
			fslmaths rand_atlas/rand-${n}p-${o}s-${m}r -mas MNI152_T1_1mm_GM_resamp_2.5mm.nii.gz rand_atlas/rand-${n}p-${o}s-${m}r
		done
	done
done
