#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Sep 24 00:59:55 2020

@author: nemo
"""

from copy import deepcopy
import os
import random
import numpy as np
import nibabel as nib

os.chdir('../90.template')
os.makedirs('rand_parc')
mni_img = nib.load('MNI152_T1_1mm_GM_resamp_2.5mm.nii.gz')
# Extract mni_data = 1, give it indexes and shuffle
mask = mni_res == 1
mni_masked = mni_res[mask]
mni_indexed = mni_masked * range(mni_masked.size)

for m in range(5):
    for n in range(2, 121):
        rand_seed = random.choices(mni_indexed, k=n)
        rand_atlas = mni_masked * 0
        for i, k in enumerate(rand_seed):
            rand_atlas[int(k)] = i+1

        out = deepcopy(mni_res)
        # Populate the output target and reshape to 3D
        out[mask == True] = rand_atlas
        out_data = out.reshape(mni_data.shape, order='F')
        # Create the nifti file and export it
        out_img = nib.Nifti1Image(out_data.astype(int), mni_img.affine, mni_img.header)
        out_img.to_filename(f'rand_parc/{n}-{m}-parc.nii.gz')
