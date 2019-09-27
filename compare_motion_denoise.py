#!/usr/bin/env python3

import os
import matplotlib
import pandas as pd
import numpy as np


def compute_slope(x, y):
    m = ((x*y).mean - x.mean*y.mean) / ((x**2).mean() - (x.mean())**2)
    return m


cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')

sub_list = ['007', '003', '002']
ftype_list = ['echo-2', 'optcom', 'meica']

sub_table = pd.DataFrame()
slope_table = pd.DataFrame()

for sub in sub_list:
    for ses in range(1, 10):
        slopes = np.zeros([30])

        for mottype in ['dvars_pre', 'fd']:
            col_name = f'{sub}_{ses:02d}_{mottype}'
            filename = f'sub-{sub}/{mottype}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[col_name] = np.genfromtxt(filename)

            avg_col_name = f'{sub}_avg_{mottype}'
            if ses == 1:
                sub_table[avg_col_name] = sub_table[col_name]
            else:
                sub_table[avg_col_name] = sub_table[avg_col_name] + sub_table[col_name]

        # loop for ftype_list
        for i in range(3):
            col_name = f'{sub}_{ses:02d}_dvars_{ftype_list[i]}'
            filename = f'sub-{sub}/dvars_{ftype_list[i]}_sub-{sub}_ses-{ses:02d}.1D'
            sub_table[col_name] = np.genfromtxt(filename)

            avg_col_name = f'{sub}_avg_dvars_{ftype_list[i]}'
            if ses == 1:
                sub_table[avg_col_name] = sub_table[col_name]
            else:
                sub_table[avg_col_name] = sub_table[avg_col_name] + sub_table[col_name]

            delta_col_name = f'{sub}_{ses:02d}_delta_dvars'
            sub_table[delta_col_name] = ((sub_table[col_name] -
                                         sub_table[f'{sub}_{ses:02d}_dvars_pre'])
                                         / sub_table[f'{sub}_{ses:02d}_fd'])

            slopes[ses*(i+1)-1] = compute_slope(sub_table[delta_col_name],
                                                sub_table[f'{sub}_{ses:02d}_fd'])

        for i in range(3):
            slope_table[f'{sub}_{ses:02d}_{ftype_list[i]}'] = slopes[i*10:(i*10+10)]

    slopes = np.zeros([30])
    for i in range(3):
        col_name = f'{sub}_avg_dvars_{ftype_list[i]}'
        delta_col_name = f'{sub}_avg_delta_dvars'
        sub_table[delta_col_name] = ((sub_table[col_name] -
                                     sub_table[f'{sub}_avg_dvars_pre']) /
                                     sub_table[f'{sub}_avg_fd'])

        slopes[ses*(i+1)-1] = compute_slope(sub_table[delta_col_name],
                                            sub_table[f'{sub}_svg_fd'])
        slope_table[f'{sub}_avg_{ftype_list[i]}'] = slopes[i*10:(i*10+10)]


sub_table.to_csv('sub_table.csv', compression='gzip')
slope_table.to_csv('slope_table.csv', compression='gzip')

    # Need to make graphs

    # PSEUDOCODE

    # Graph one: slopes
    # For each session, for each ftype
        # Create a fake point that is (10,10*m)
        # Plot a line in blue?
    # Average: repeat session but plot in red

    # Graph two: violin plot
    # For each ftype
        # Append all the subjects and sessions
        # If needed, tidy the matrix
        # Violin plot


os.chdir(cwd)