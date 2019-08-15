for sub in `seq -f %03g 1 10`
do
	for ses in `seq -f %02g 1 10`
	do
		csvtool namedcol Num,${sub}_${ses} Decomposition.csv > ${sub}_${ses}_comp
		cat ${sub}_${ses}_comp | grep ,R | csvtool col 1 - > ${sub}_${ses}_rc

		while read -r line
		do
			let line++
			echo $line
		done < ${sub}_${ses}_rc > ${sub}_${ses}_rd

		csvtool transpose ${sub}_${ses}_rd > ${sub}_${ses}_rej
	done
done

rm 0??_??_rc
rm 0??_??_rd