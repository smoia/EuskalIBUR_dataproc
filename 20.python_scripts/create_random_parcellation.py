#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Sep 24 00:59:55 2020

@author: nemo
"""

from copy import deepcopy
import os
import numpy as np
import nibabel as nib
from itertools import compress

os.chdir('../90.template')
os.makedirs('rand_atlas')
mni_img = nib.load('MNI152_T1_1mm_GM_resamp_2.5mm_dil.nii.gz')
mni_data = mni_img.get_fdata()

# Flatten mni_data
mni_res = mni_data.reshape(np.prod(mni_data.shape[:3]), order='F')
# Extract mni_data = 1, give it indexes and shuffle
mask = mni_res == 1
mni_masked = mni_res[mask]
mni_indexed = mni_masked * range(mni_masked.size)

for n in range(2, 121):
    np.random.shuffle(mni_indexed)
    rand_atlas = mni_masked * 0
    thr = int(mni_masked.size // n)
    for m in range(n, 0, -1):
        rand_atlas[mni_indexed < m*thr] = rand_atlas[mni_indexed < m*thr] + 1
    
    out = deepcopy(mni_res)
    # Populate the output target and reshape to 3D
    out[mask == True] = rand_atlas
    out_data = out.reshape(mni_data.shape, order='F')
    # Create the nifti file and export it
    out_img = nib.Nifti1Image(out_data.astype(int), mni_img.affine, mni_img.header)
    out_img.to_filename(f'rand_atlas/{n}-parc.nii.gz')

    
        
    
    