#!/usr/bin/env python3

import os
import pandas as pd
import numpy as np

from scipy.stats import ttest_rel
from itertools import combinations

P_VALS = [0.05, 0.01, 0.001]
LAST_SES = 10
SUB_LIST = ['001', '002', '003', '004', '007', '009']  # '008', 
FTYPE_LIST = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth', 'meica-preg',
              'meica-mvar']  #, 'meica-recn']

cwd = os.getcwd()

os.chdir('/data')

os.chdir('ME_Denoising')


# 01. Read and organise motion related parameters

LAST_SES += 1

sub_table = pd.read_csv('sub_table.csv').drop(0)
slope_table = pd.DataFrame(columns=['sub',  'ses', 'ftype', 'm', 'q'])

for sub in SUB_LIST:
    for ses in range(1, LAST_SES):
        fd = sub_table[f'{sub}_{ses:02g}_fd'].to_numpy()
        X = np.vstack([fd, np.ones(len(fd))]).T

        for ftype in FTYPE_LIST:
            dvars = sub_table[f'{sub}_{ses:02g}_dvars_{ftype}'].to_numpy()
            m, q = np.linalg.lstsq(X, dvars)[0]

            slope_table = slope_table.append({'sub': sub,  'ses': f'{ses:02g}',
                                              'ftype': ftype, 'm': m, 'q': q},
                                             ignore_index=True)

slope_table.to_csv('slope_table.csv')

T_t = pd.DataFrame(columns=['ftype1', 'ftype2', 'T_m', 'p_m', 'T_q', 'p_q'])

for ftype_one, ftype_two in list(combinations(FTYPE_LIST, 2)):
    ftype_one_data = slope_table.loc[slope_table['ftype'] == ftype_one]
    ftype_two_data = slope_table.loc[slope_table['ftype'] == ftype_two]
    T_m, p_m = ttest_rel(ftype_one_data['m'], ftype_two_data['m'])
    T_q, p_q = ttest_rel(ftype_one_data['q'], ftype_two_data['q'])

    T_t = T_t.append({'ftype1': ftype_one, 'ftype2': ftype_two,
                      'T_m': T_m, 'p_m': p_m, 'T_q': T_q, 'p_q': p_q},
                     ignore_index=True)

# Compute Sidak correction
for p_val in P_VALS:
    p_corr = 1-(1-p_val)**(1/len(list(combinations(FTYPE_LIST, 2))))

    T_t_mask = T_t.copy(deep=True)
    T_t_mask['p_m'] = T_t['p_m'].mask(T_t['p_m'] > p_corr)
    T_t_mask['p_q'] = T_t['p_q'].mask(T_t['p_q'] > p_corr)

    T_t.to_csv('Ttests.csv')
    T_t_mask.to_csv(f'Ttests_masked_{p_val}.csv')


os.chdir(cwd)
