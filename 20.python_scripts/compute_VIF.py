#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Apr 18 00:06:59 2020

@author: nemo
"""

import numpy as np
import sys
sys.path.append('/usr/lib/afni/bin')
from lib_afni1D import Afni1D as afni
import nibabel as nib
from copy import deepcopy
from statsmodels.stats.outliers_influence import variance_inflation_factor as vif
import matplotlib.pyplot as plt

model = afni('sub-001_ses-01_meica-aggr_mat/mat.1D')
mat = np.asarray(model.mat)
mat = np.delete(mat, 5, 0)

vif_time = {}
vif_time['optcom'] = np.empty(60)
vif_time['meica-aggr'] = np.empty(60)
vif_time['polorts'] = np.empty(60)
vif_time['motion'] = np.empty(60)
vif_time['icaonly_meica-aggr'] = np.empty(60)
vif_time['icapol_meica-aggr'] = np.empty(60)
vif_time['icamot_meica-aggr'] = np.empty(60)

for i in range(60):
    co2 = np.genfromtxt(f'../sub-001_ses-01_GM_optcom_avg_regr_shift/shift_{(i*12):04d}.1D')
    co2 = np.atleast_2d(co2)
    full_mat = np.append(co2, mat, axis=0)
    vif_time['optcom'][i] = vif(full_mat[:18,:].T,0)
    vif_time['meica-aggr'][i] = vif(full_mat.T,0)
    vif_time['polorts'][i] = vif(full_mat[:6,:].T,0)
    
    p_mat = np.append(co2, mat[5:17,:], axis=0)
    vif_time['motion'][i] = vif(p_mat.T,0)
    
    p_mat = np.append(co2, mat[17:,:], axis=0)
    vif_time['icaonly_meica-aggr'][i] = vif(p_mat.T,0)
    
    p_mat = np.append(co2, mat[5:,:], axis=0)
    vif_time['icamot_meica-aggr'][i] = vif(p_mat.T,0)
    
    p_mat = np.append(full_mat[:6,:], mat[17:,:], axis=0)
    vif_time['icapol_meica-aggr'][i] = vif(p_mat.T,0)

for j in ['meica-orth', 'meica-cons']:
    vif_time[j] = np.empty(60)
    vif_time[f'icaonly_{j}'] = np.empty(60)
    vif_time[f'icamot_{j}'] = np.empty(60)
    vif_time[f'icapol_{j}'] = np.empty(60)
    for i in range(60):
        model = afni(f'sub-001_ses-01_{j}_mat/mat_{(i*12):04d}.1D')
        mat = np.asarray(model.mat)
        vif_time[j][i] = vif(mat.T,5)

        p_mat = np.append(co2, mat[17:,:], axis=0)
        vif_time[f'icaonly_{j}'][i] = vif(p_mat.T,0)
    
        p_mat = np.append(co2, mat[5:,:], axis=0)
        vif_time[f'icamot_{j}'][i] = vif(p_mat.T,0)
    
        p_mat = np.append(full_mat[:6,:], mat[17:,:], axis=0)
        vif_time[f'icapol_{j}'][i] = vif(p_mat.T,0)

for i, j in enumerate(['optcom', 'meica-aggr', 'meica-orth']):  # , 'meica-cons']):
    plt.subplot(1, 3, i+1)
    plt.plot(vif_time[j])
    plt.title(j)


img = {}
data = {}
vif_map = {}
out = {}

for j in ['meica-orth', 'meica-cons', 'meica-aggr', 'optcom']:
    np.savetxt(f'sub-001_ses-01_{j}_VIF.1D', vif_time[j])
    img[j] = nib.load(f'sub-001_ses-01_{j}_map_cvr/sub-001_ses-01_{j}_cvr_idx.nii.gz')
    data[j] = img[j].get_fdata()
    vif_map[j] = deepcopy(data[j])
    for x in range(88):
        for y in range(88):
            for z in range(52):
                vif_map[j][x,y,z] = vif_time[j][int(data[j][x,y,z])]

    out[j] = nib.Nifti1Image(vif_map[j], img[j].affine, img[j].header)
    out[j].to_filename(f'sub-001_ses-01_{j}_map_cvr/sub-001_ses-01_{j}_vif.nii.gz')





import numpy as np
import sys
sys.path.append('/usr/lib/afni/bin')
from lib_afni1D import Afni1D as afni
import nibabel as nib
from copy import deepcopy
from statsmodels.stats.outliers_influence import variance_inflation_factor as vif

idx_img = nib.load('sub-001_ses-01_optcom_cvr_idx.nii.gz')
idx_data = idx_img.get_fdata()
idx_data_int = np.asarray(idx_data, dtype=int)
data={}
img={}
twosteps={}
out={}
for j in ['aggr','cons','orth']:
    img[j] = nib.load(f'../sub-001_ses-01_meica-{j}_betas_time.nii.gz')
    data[j] = img[j].get_fdata()
    twosteps[j] = deepcopy(idx_data)
    for x in range(88):
        for y in range(88):
            for z in range(52):
                twosteps[j][x,y,z] = data[j][x,y,z,(idx_data_int[x,y,z]-1)]
    
    twosteps[j] = twosteps[j]/71.2*100

    out[j] = nib.Nifti1Image(twosteps[j], img[j].affine, img[j].header)
    out[j].to_filename(f'../sub-001_ses-01_meica-{j}-twosteps_cvr.nii.gz')
