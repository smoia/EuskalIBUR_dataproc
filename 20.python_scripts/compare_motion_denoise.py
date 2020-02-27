#!/usr/bin/env python3

import os
import pandas as pd
import numpy as np

NTE = 5
LAST_SES = 10  # 10
SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']


cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')


# 01. Read and organise motion related parameters
ftype_list = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth', 'meica-cons',
              'meica-mvar']

LAST_SES += 1

sub_table = pd.DataFrame()
sub_long_table = pd.DataFrame(columns=['dvars', 'sub', 'ses', 'ftype', 'fd'])

for sub in SUB_LIST:
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

ftype_list = ['pre', 'echo-2', 'optcom', 'meica-aggr', 'meica-orth',
              'meica-cons', 'meica-mvar']

for sub in SUB_LIST:
    for ses in range(1, LAST_SES):
        fd_col = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02d}.1D')

        for ftype in ftype_list:
            tmp_df = pd.DataFrame()
            tmp_df['dvars'] = np.genfromtxt(f'sub-{sub}/dvars_{ftype}_sub-{sub}_ses-{ses:02d}.1D')
            tmp_df['sub'] = sub
            tmp_df['ses'] = f'{ses:02d}'
            tmp_df['ftype'] = ftype
            tmp_df['fd'] = fd_col
            tmp_df = tmp_df.drop(tmp_df.index[0])

            sub_long_table = sub_long_table.append(tmp_df, ignore_index=True)

sub_table = sub_table.drop(sub_table.index[0])

sub_table.to_csv('sub_table.csv')
sub_long_table.to_csv('sub_long_table.csv')

os.chdir(cwd)
