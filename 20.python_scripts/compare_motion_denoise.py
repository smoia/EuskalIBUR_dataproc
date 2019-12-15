#!/usr/bin/env python3

import os
import pandas as pd
import numpy as np

NTE = 5
LAST_SES = 5
SUB_LIST = ['001', '002', '003', '004', '007']


def compute_slope(x, y):
    m = ((x*y).mean() - x.mean()*y.mean()) / ((x**2).mean() - (x.mean())**2)
    return m


cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')


# 01. Read and organise motion related parameters
ftype_list = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth', 'meica-preg',
              'meica-mvar']

LAST_SES += 1

sub_table = pd.DataFrame()
slope_table = pd.DataFrame()

for sub in SUB_LIST:
    slopes = np.zeros([len(ftype_list) * LAST_SES])
    for ses in range(1, LAST_SES):
        for mot_type in ['dvars_pre', 'fd']:
            col_name = f'{sub}_{ses:02d}_{mot_type}'
            filename = f'sub-{sub}/{mot_type}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[col_name] = np.genfromtxt(filename)

        # loop for ftype_list
        dvars_pre = f'{sub}_{ses:02d}_dvars_pre'
        for i, ftype in enumerate(ftype_list):
            dvars_type = f'{sub}_{ses:02d}_dvars_{ftype}'
            filename = f'sub-{sub}/dvars_{ftype}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[dvars_type] = np.genfromtxt(filename)

            delta_dvars = f'{sub}_{ses:02d}_delta_dvars_{ftype}'
            sub_table[delta_dvars] = sub_table[dvars_pre] - sub_table[dvars_type]

            slopes[i*LAST_SES+ses-1] = compute_slope(np.array(sub_table[delta_dvars][1:]),
                                                     np.array(sub_table[f'{sub}_{ses:02d}_fd'][1:]))

    for i, ftype in enumerate(ftype_list):
        slope_table[f'{sub}_{ftype}'] = slopes[i*LAST_SES:(i*LAST_SES+LAST_SES)]

sub_table.drop(sub_table.index[0])

sub_table.to_csv('sub_table.csv')
slope_table.to_csv('slope_table.csv')

os.chdir(cwd)