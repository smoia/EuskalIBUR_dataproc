#!/usr/bin/env python3

import os
import pandas as pd
import numpy as np

NTE = 5


def compute_slope(x, y):
    m = ((x*y).mean() - x.mean()*y.mean()) / ((x**2).mean() - (x.mean())**2)
    return m


cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')

sub_list = ['007']

# 01. Read and organise motion related parameters
ftype_list = ['optcom', 'meica-aggr', 'meica-orth', 'meica-preg',
              'meica-mvar', 'echo-2']
# ftype_list = ['optcom', 'meica']
# for e in range(NTE):
#     ftype_list.append(f'echo-{e+1}')
#     ftype_list.append(f'meica_echo-{e+1}')


sub_table = pd.DataFrame()
slope_table = pd.DataFrame()

for sub in sub_list:
    slopes = np.zeros([len(ftype_list)*10])
    for ses in range(1, 10):

        for mot_type in ['dvars_pre', 'fd']:
            col_name = f'{sub}_{ses:02d}_{mot_type}'
            filename = f'sub-{sub}/{mot_type}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[col_name] = np.genfromtxt(filename)

        # loop for ftype_list
        dvars_pre = f'{sub}_{ses:02d}_dvars_pre'
        for i in range(len(ftype_list)):
            dvars_type = f'{sub}_{ses:02d}_dvars_{ftype_list[i]}'
            filename = f'sub-{sub}/dvars_{ftype_list[i]}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[dvars_type] = np.genfromtxt(filename)

            delta_dvars = f'{sub}_{ses:02d}_delta_dvars_{ftype_list[i]}'
            dvars_norm = f'{sub}_{ses:02d}_norm_dvars_{ftype_list[i]}'
            sub_table[delta_dvars] = sub_table[dvars_pre] - sub_table[dvars_type]
            sub_table[dvars_norm] = sub_table[delta_dvars] / sub_table[dvars_type]
            sub_table[dvars_norm][0] = 0

            slopes[i*10+ses-1] = compute_slope(np.array(sub_table[delta_dvars][1:]),
                                               np.array(sub_table[f'{sub}_{ses:02d}_fd'][1:]))

    for i in range(len(ftype_list)):
        slope_table[f'{sub}_{ftype_list[i]}'] = slopes[i*10:(i*10+10)]

sub_table.drop(sub_table.index[0])

sub_table.to_csv('sub_table.csv')
slope_table.to_csv('slope_table.csv')

os.chdir(cwd)