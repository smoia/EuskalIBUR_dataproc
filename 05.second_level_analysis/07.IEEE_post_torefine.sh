for model in fullmodel nomot premot
do
cd ${model}
echo "Doing lags $model"
fslmaths ../MNI_bin -mul 8 lag_contribution
fslmaths ../MNI_bin -thr 100 avg_std_lag_corrected
fslmaths ../MNI_bin -thr 100 avg_std_cvr_corrected
fslmaths ../MNI_bin -thr 100 tstat_contribution
for sub in 001 002 003 004 007 008 009 010
do
echo "Doing sub $sub"
# lags
fslmaths std_${sub}_04_optcom_cvr_lag -mas ../MNI_bin -abs -thr 8.45 -bin ${sub}_boundaries_map
fslmaths ../MNI_bin -sub ${sub}_boundaries_map -mas ../MNI_bin -mul std_${sub}_04_optcom_cvr_lag ${sub}_lag_masked
fslmaths lag_contribution -sub ${sub}_boundaries_map lag_contribution
fslmaths avg_std_lag_corrected -add ${sub}_lag_masked avg_std_lag_corrected
# cvr
fslmaths std_${sub}_04_optcom_tmap.nii.gz -mas ../MNI_bin -thr 3.164 -bin ${sub}_tstat
fslmaths ../MNI_bin -sub ${sub}_boundaries_map -mas ../MNI_bin -mul std_${sub}_04_optcom_cvr.nii.gz -mas ${sub}_tstat ${sub}_cvr_masked
fslmaths tstat_contribution -add ${sub}_tstat tstat_contribution
fslmaths avg_std_cvr_corrected -add ${sub}_cvr_masked avg_std_cvr_corrected
done
echo "Adjusting"
fslmaths avg_std_lag_corrected -div lag_contribution avg_std_lag_corrected
fslmaths avg_std_cvr_corrected -div tstat_contribution avg_std_cvr_corrected
cd ..
done

cd noshift
fslmaths ../MNI_bin -thr 100 avg_std_cvr_corrected
fslmaths ../MNI_bin -thr 100 tstat_contribution
for sub in 001 002 003 004 007 008 009 010
do
echo "Doing sub $sub"
# cvr
fslmaths std_${sub}_04_optcom_tmap_bulkshift.nii.gz -mas ../MNI_bin -thr 1.65 -bin ${sub}_tstat
fslmaths std_${sub}_04_optcom_cvr_bulkshift.nii.gz -mas ${sub}_tstat ${sub}_cvr_masked
fslmaths tstat_contribution -add ${sub}_tstat tstat_contribution
fslmaths avg_std_cvr_corrected -add ${sub}_cvr_masked avg_std_cvr_corrected
done
echo "Adjusting"
fslmaths avg_std_cvr_corrected -div tstat_contribution avg_std_cvr_corrected
cd ..

for fld in fullmodel nomot premot
do
fsleyes render --size 600 270 --outfile /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/avg_std_cvr_corrected.png --scene ortho --worldLoc -18.315066461977764 4.747925838850961 1.7419313483430585 --displaySpace /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --xcentre  0.00000  0.00000 --ycentre  0.00000  0.00000 --zcentre  0.00000  0.00000 --xzoom 100.0 --yzoom 100.0 --zzoom 100.0 --hideLabels --layout horizontal --hidey --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --cursorColour 0.0 1.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 16 --performance 3 /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --name "MNI" --disabled --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/avg_std_cvr_corrected.nii.gz --name "CVR [%BOLD/mmHg]" --overlayType volume --alpha 100.0 --brightness 50 --contrast 50 --cmap brain_colours_nih_fire --negativeCmap greyscale --displayRange 0 1 --clippingRange 0 1560.175517535489 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 \

fsleyes render --size 600 270 --outfile /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/avg_std_lag_corrected.png --scene ortho --worldLoc -18.315066461977764 4.747925838850961 1.7419313483430585 --displaySpace /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --xcentre  0.00000  0.00000 --ycentre  0.00000  0.00000 --zcentre  0.00000  0.00000 --xzoom 100.0 --yzoom 100.0 --zzoom 100.0 --hideLabels --layout horizontal --hidey --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --cursorColour 0.0 1.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 16 --performance 3 /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --name "MNI" --disabled --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/avg_std_lag_corrected.nii.gz --name "Lag [s]" --overlayType volume --alpha 100.0 --cmap viridis_neg --negativeCmap viridis_pos --useNegativeCmap --displayRange 0.0 8.4 --clippingRange 0.0 8.4 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0

fsleyes render --size 600 270 --outfile /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/lag_contribution.png --scene ortho --worldLoc -18.315066461977764 4.747925838850961 1.7419313483430585 --displaySpace /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --xcentre  0.00000  0.00000 --ycentre  0.00000  0.00000 --zcentre  0.00000  0.00000 --xzoom 100.0 --yzoom 100.0 --zzoom 100.0 --hideLabels --layout horizontal --hidey --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --cursorColour 0.0 1.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 16 --performance 3 /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --name "MNI" --disabled --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 /home/nemo/Scrivania/00.IEEE/SUBJECTS/${fld}/lag_contribution.nii.gz --name "Subjects [#]" --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap blue-lightblue --negativeCmap greyscale --displayRange 0.0 8.0 --clippingRange 0.0 8.08 --gamma 0.0 --cmapResolution 256 --interpolation none --invert --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0
done

fsleyes render --size 600 270 --outfile /home/nemo/Scrivania/00.IEEE/SUBJECTS/fullmodel/avg_std_lag_corrected_5s.png --scene ortho --worldLoc -18.315066461977764 4.747925838850961 1.7419313483430585 --displaySpace /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --xcentre  0.00000  0.00000 --ycentre  0.00000  0.00000 --zcentre  0.00000  0.00000 --xzoom 100.0 --yzoom 100.0 --zzoom 100.0 --hideLabels --layout horizontal --hidey --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --cursorColour 0.0 1.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 16 --performance 3 /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --name "MNI" --disabled --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 /home/nemo/Scrivania/00.IEEE/SUBJECTS/fullmodel/avg_std_lag_corrected.nii.gz --name "Lag [s]" --overlayType volume --alpha 100.0 --cmap viridis_neg --negativeCmap viridis_pos --useNegativeCmap --displayRange 0.0 5.0 --clippingRange 0.0 8.4 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0

fsleyes render --size 600 270 --outfile /home/nemo/Scrivania/00.IEEE/SUBJECTS/noshift/avg_std_cvr_corrected.png --scene ortho --worldLoc -18.315066461977764 4.747925838850961 1.7419313483430585 --displaySpace /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --xcentre  0.00000  0.00000 --ycentre  0.00000  0.00000 --zcentre  0.00000  0.00000 --xzoom 100.0 --yzoom 100.0 --zzoom 100.0 --hideLabels --layout horizontal --hidey --hideCursor --bgColour 0.0 0.0 0.0 --fgColour 1.0 1.0 1.0 --cursorColour 0.0 1.0 0.0 --showColourBar --colourBarLocation right --colourBarLabelSide bottom-right --colourBarSize 80.0 --labelSize 16 --performance 3 /home/nemo/Scrivania/00.IEEE/SUBJECTS/MNI.nii.gz --name "MNI" --disabled --overlayType volume --alpha 100.0 --brightness 50.0 --contrast 50.0 --cmap greyscale --negativeCmap greyscale --displayRange 0.0 8337.0 --clippingRange 0.0 8420.37 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0 /home/nemo/Scrivania/00.IEEE/SUBJECTS/noshift/avg_std_cvr_corrected.nii.gz --name "CVR [%BOLD/mmHg]" --overlayType volume --alpha 100.0 --brightness 50 --contrast 50 --cmap brain_colours_nih_fire --negativeCmap greyscale --displayRange 0 1 --clippingRange 0 1560.175517535489 --gamma 0.0 --cmapResolution 256 --interpolation none --numSteps 100 --blendFactor 0.1 --smoothing 0 --resolution 100 --numInnerSteps 10 --clipMode intersection --volume 0

for fld in fullmodel nomot premot; do cd ${fld}; for i in *.png; do mv ${i} ../${fld}_${i}; done; cd ..; done

mv noshift/avg_std_cvr_corrected.png noshift_avg_std_cvr_corrected.png
mv fullmodel/avg_std_lag_corrected_5s.png fullmodel_avg_std_lag_corrected_5s.png

for fld in fullmodel nomot premot
do for sub in 001 002 003 004 007 008 009 010
do echo "$fld $sub"
fslstats -K 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz ${fld}/${sub}_lag_masked.nii.gz -l -8.45 -u 8.45 -M
fslstats -K MNI_mask_v3.nii.gz ${fld}/${sub}_lag_masked.nii.gz -l -8.45 -u 8.45 -S
done
done

for fld in fullmodel noshift
do for sub in 001 002 003 004 007 008 009 010
do echo "$fld $sub"
fslstats -K 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz ${fld}/${sub}_cvr_masked.nii.gz -l 0 -u 5 -M
fslstats -K 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz ${fld}/${sub}_cvr_masked.nii.gz -l 0 -u 5 -S
done
done

for fld in fullmodel
do for sub in 001 002 003 004 007 008 009 010
do echo "$fld $sub"
fslstats -K 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz ${fld}/${sub}_lag_masked.nii.gz -l -8.45 -u 8.45 -M
fslstats -K 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz ${fld}/${sub}_lag_masked.nii.gz -l -8.45 -u 8.45 -S
done
done

fslmeants -i fullmodel/avg_std_cvr_corrected.nii.gz  --showall --transpose -m MNI_mask_v3 > cvr_simmot.csv
fslmeants -i noshift/avg_std_cvr_corrected.nii.gz  --showall --transpose -m MNI_mask_v3 > cvr_nonopt.csv
fslmeants -i fullmodel/avg_std_lag_corrected.nii.gz  --showall --transpose -m MNI_mask_v3 > lag.csv
fslmeants -i 90.template/MNI_T1_putamen_cerebellum_v3.nii.gz  --showall --transpose -m MNI_mask_v3 > mask.csv
