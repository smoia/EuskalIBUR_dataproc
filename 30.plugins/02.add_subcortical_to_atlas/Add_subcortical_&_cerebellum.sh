# first ATT atlas
atlas=ATTbasedFlowTerritories_resamp_2.5mm
FS_files=(aparc.a2009s+aseg FS_Lh_mask FS_Rh_mask FS_Subcortical FS_Cerebellum)
for FS_f in ${FS_files[*]}; do
    3dresample -input $FS_f.nii.gz -master $atlas.nii.gz -prefix ${FS_f}_space_ATT.nii.gz
done
3dcalc -overwrite -a $atlas.nii.gz -b FS_Rh_mask_space_ATT.nii.gz -expr "a*b" -prefix ${atlas}_Rh.nii.gz
3dcalc -overwrite -a $atlas.nii.gz -b FS_Lh_mask_space_ATT.nii.gz -expr "(a+10)*b*(step(a))" -prefix ${atlas}_Lh.nii.gz
3dcalc -overwrite -a ${atlas}_Lh.nii.gz -b ${atlas}_Rh.nii.gz -expr "a+b" -prefix ${atlas}_by_hemis.nii.gz
3dcalc -overwrite -a ${atlas}_by_hemis.nii.gz -c aparc.a2009s+aseg_space_ATT.nii.gz -d FS_Subcortical_space_ATT.nii.gz -e FS_Cerebellum_space_ATT.nii.gz  -expr "a+(c+100-a)*d+(c+100-a)*e" -datum short -prefix ${atlas}_sub_ceb.nii.gz

# Now yeo atlas
atlas=Yeo2011_7Networks_MNI152_AFNI_FreeSurferConformed1mm_LiberalMask2
FS_files=(aparc.a2009s+aseg FS_Lh_mask FS_Rh_mask FS_Subcortical FS_Cerebellum)
for FS_f in ${FS_files[*]}; do
    3dresample -overwrite -input $FS_f.nii.gz -master $atlas.nii.gz -prefix ${FS_f}_space_Yeo.nii.gz
done
3dcalc -overwrite -a ${atlas}.nii.gz -c aparc.a2009s+aseg_space_Yeo.nii.gz -d FS_Subcortical_space_Yeo.nii.gz -e FS_Cerebellum_space_Yeo.nii.gz  -expr "a+(c+100-a)*d+(c+100-a)*e" -datum short -prefix ${atlas}_sub_ceb.nii.gz
