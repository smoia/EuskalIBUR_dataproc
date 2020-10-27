#!/usr/bin/env bash

sub=${1}
wdr=${2:-/data}
scriptdir=${3:-/scripts}

### Main ###

cwd=$( pwd )

cd ${wdr} || exit

echo "Plotting motion outliers"

if [ ! -d ${wdr}/plots ]; then mkdir ${wdr}/plots; fi

python3 ${scriptdir}/20.python_scripts/plot_cvr_vals.py ${sub} ${wdr} ${scriptdir}

# Go on modifying plots
if [ -e ${tmp}/tmp.04pcv_${sub} ]; then rm -rf ${tmp}/tmp.04pcv_${sub}; fi

mkdir ${tmp}/tmp.04pcv_${sub}

cd ${tmp}/tmp.04pcv_${sub}

# # Crop lags and CVR
# for map in CVR lags
# do
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x49+30+0 +repage tit.png
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x146+30+106 +repage 1.png
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x129+30+281 +repage 2.png
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x129+30+441 +repage 3.png
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x129+30+600 +repage 4.png
# 	convert ${wdr}/plots/sub-${sub}_${map}_vals.png -crop 782x189+30+756 +repage 5.png

# 	convert -append tit.png 1.png 2.png 3.png 4.png 5.png +repage sub_${sub}_${map}_app.png
# done

# # Crop counts
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 1082x43+209+0 +repage tit.png
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 291x663+96+77 +repage 1.png
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 197x663+430+77 +repage 2.png
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 197x663+671+77 +repage 3.png
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 197x663+911+77 +repage 4.png
# convert ${wdr}/plots/sub-${sub}_Lag_count.png -crop 200x663+1152+77 +repage 5.png

# convert +append 1.png 2.png 3.png 4.png 5.png +repage sub_${sub}_bars_app.png
# convert -append tit.png sub_${sub}_bars_app.png +repage sub_${sub}_count_app.png

cd ${cwd}

rm -rf ${tmp}/tmp.04pcv_${sub}