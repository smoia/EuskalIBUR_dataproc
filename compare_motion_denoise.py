#!/usr/bin/env python3

import os
import matplotlib
import pandas as pd
import numpy as np


def compute_slope(x, y):
    m = ((x*y).mean() - x.mean()*y.mean()) / ((x**2).mean() - (x.mean())**2)
    return m


cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')

sub_list = ['007', '003', '002']
ftype_list = ['echo-2', 'optcom', 'meica']

sub_table = pd.DataFrame()
slope_table = pd.DataFrame()

for sub in sub_list:
    slopes = np.zeros([30])
    for ses in range(1, 10):

        for mottype in ['dvars_pre', 'fd']:
            col_name = f'{sub}_{ses:02d}_{mottype}'
            filename = f'sub-{sub}/{mottype}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[col_name] = np.genfromtxt(filename)

        # loop for ftype_list
        dvars_pre = f'{sub}_{ses:02d}_dvars_pre'
        for i in range(3):
            dvars_type = f'{sub}_{ses:02d}_dvars_{ftype_list[i]}'
            filename = f'sub-{sub}/dvars_{ftype_list[i]}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[dvars_type] = np.genfromtxt(filename)

            delta_dvars = f'{sub}_{ses:02d}_delta_dvars_{ftype_list[i]}'
            dvars_norm = f'{sub}_{ses:02d}_delta_dvars_{ftype_list[i]}_normalised'
            sub_table[delta_dvars] = sub_table[dvars_pre] - sub_table[dvars_type]
            sub_table[dvars_norm] = sub_table[delta_dvars] / sub_table[dvars_type]
            sub_table[dvars_norm][0] = 0

            slopes[i*10+ses-1] = compute_slope(np.array(sub_table[delta_dvars]),
                                               np.array(sub_table[f'{sub}_{ses:02d}_fd']))

    for i in range(3):
        slope_table[f'{sub}_{ftype_list[i]}'] = slopes[i*10:(i*10+10)]

sub_table.to_csv('sub_table.csv')
slope_table.to_csv('slope_table.csv')

os.chdir(cwd)