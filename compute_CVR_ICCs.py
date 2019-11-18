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

for val in VALUE_LIST:
    iccs = np.empty((4, 4))
    for i in range(len(FTYPE_LIST)):
        print(f'\n\n {FTYPE_LIST[i]} {val}: ')
        fname = f'{FTYPE_LIST}_{val}_alltypes_mask'
        iccs[0, i], iccs[1:, i] = ICC.compute_spatial_ICC_1(f'{FTYPE_LIST[i]}_{val}')

    df = pd.DataFrame(iccs, columns=FTYPE_LIST)
    df.to_csv(f'ICC_table_{val}')

    df_tidy = pd.melt(df[1:], var_name='type', value_name='ICC')
    df_tidy['sub'] = np.tile(np.array(range(len(SUB_LIST))), 4)

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    sns.pointplot(x='type', y='ICC', hue='sub', data=df_tidy,
                  palette=COLOURS, ci=None).legend_.remove()
    plt.title(f'Spatial ICC, {val}')
    plt.savefig(f'Spatial_ICC_plot_{val}.png', dpi=SET_DPI)
    plt.clf()
    plt.close()

os.chdir(cwd)