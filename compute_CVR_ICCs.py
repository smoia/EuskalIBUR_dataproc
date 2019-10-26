#!/usr/bin/env python3

import os
import ICC
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

FTYPE_LIST = ['echo-2', 'optcom', 'meica', 'vessels']  #, 'networks']
VALUE_LIST = ['cvrvals', 'lagvals', 'tvals']
SUB_LIST = ['002', '003', '007']
COLOURS = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff']  #, '#d62728ff', '#ac45a8ff']

SET_DPI = 100
FIGSIZE = (18, 10)


cwd = os.getcwd()

# os.chdir('/bcbl/home/public/PJMASK_2/preproc/CVR/00.Reliability')
# os.chdir('/home/nemo/Documenti/Archive/Data/gdrive/PJMASK/CVR/00.Reliability')
os.chdir('/data/CVR/00.Reliability')

n_ftypes = len(FTYPE_LIST)
n_subs = len(SUB_LIST)

for val in VALUE_LIST:
    iccs = np.empty((n_subs+1, n_ftypes))
    for i in range(n_ftypes):
        print(f'\n\n {FTYPE_LIST[i]} {val}: ')
        fname = f'{FTYPE_LIST[i]}_{val}_alltypes_mask'
        iccs[0, i], iccs[1:, i] = ICC.compute_spatial_ICC_1(fname)

    df = pd.DataFrame(iccs, columns=FTYPE_LIST)
    df.to_csv(f'ICC_table_{val}_alltypes_mask')

    df_tidy = pd.melt(df[1:], var_name='type', value_name='ICC')
    df_tidy['sub'] = np.tile(np.array(range(n_subs)), 4)

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    sns.pointplot(x='type', y='ICC', hue='sub', data=df_tidy,
                  palette=COLOURS, ci=None).legend_.remove()
    plt.title(f'Spatial ICC, {val}')
    plt.savefig(f'Spatial_ICC_plot_{val}_alltypes_mask.png', dpi=SET_DPI)
    plt.clf()
    plt.close()

for val in VALUE_LIST:
    iccs = np.empty((n_subs+1, n_ftypes))
    for i in range(n_ftypes):
        print(f'\n\n {FTYPE_LIST[i]} {val}: ')
        fname = f'{FTYPE_LIST[i]}_{val}_GM_mask'
        iccs[0, i], iccs[1:, i] = ICC.compute_spatial_ICC_1(fname)

    df = pd.DataFrame(iccs, columns=FTYPE_LIST)
    df.to_csv(f'ICC_table_{val}_GM_mask')

    df_tidy = pd.melt(df[1:], var_name='type', value_name='ICC')
    df_tidy['sub'] = np.tile(np.array(range(n_subs)), 4)

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    sns.pointplot(x='type', y='ICC', hue='sub', data=df_tidy,
                  palette=COLOURS, ci=None).legend_.remove()
    plt.title(f'Spatial ICC, {val}, comparison in GM')
    plt.savefig(f'Spatial_ICC_plot_{val}_GM_mask.png', dpi=SET_DPI)
    plt.clf()
    plt.close()

for val in VALUE_LIST:
    iccs = np.empty((n_subs+1, n_ftypes))
    for i in range(n_ftypes):
        print(f'\n\n {FTYPE_LIST[i]} {val}: ')
        fname = f'{FTYPE_LIST}_{val}'
        iccs[0, i], iccs[1:, i] = ICC.compute_spatial_ICC_1(fname)

    df = pd.DataFrame(iccs, columns=FTYPE_LIST)
    df.to_csv(f'ICC_table_{val}')

    df_tidy = pd.melt(df[1:], var_name='type', value_name='ICC')
    df_tidy['sub'] = np.tile(np.array(range(n_subs)), 4)

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    sns.pointplot(x='type', y='ICC', hue='sub', data=df_tidy,
                  palette=COLOURS, ci=None).legend_.remove()
    plt.title(f'Spatial ICC, {val}, comparison in all significant voxels')
    plt.savefig(f'Spatial_ICC_plot_{val}.png', dpi=SET_DPI)
    plt.clf()
    plt.close()

os.chdir(cwd)