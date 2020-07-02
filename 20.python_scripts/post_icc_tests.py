#!/usr/bin/env python3

import json
import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


FTYPE_LIST = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth', 'meica-cons']

SET_DPI = 100
FIGSIZE = (18, 10)


def histogram_icc(f_dict, filename, map):
    df = pd.DataFrame(columns=['val', 'ftype'])

    # Rearrange data in long format table
    for ftype in FTYPE_LIST:
        tdf = pd.DataFrame(data=f_dict[ftype], columns=['val', ])
        tdf['ftype'] = ftype
        df = df.append(tdf)

    # Seaborn it out!
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    sns.boxenplot(x='ftype', y='val', data=df)
    plt.xlabel('')
    plt.ylabel(f'{map.upper()}')
    fig_name = f'{filename}.png'
    plt.savefig(fig_name, dpi=SET_DPI)
    plt.clf()
    plt.close()


# THIS IS MAIN
cwd = os.getcwd()
os.chdir('/data/CVR_reliability/tests')

# Prepare dictionaries
icc = {'cvr': {}, 'lag': {}}
m_icc = {'cvr': {}, 'lag': {}}
s_icc = {'cvr': {}, 'lag': {}}

for map in ['cvr', 'lag']:
    # Read files, import ICC and CoV values, and compute average
    for ftype in FTYPE_LIST:
        icc[map][ftype] = np.genfromtxt(f'val/ICC2_{map}_masked_{ftype}.txt')[:, 3]
        m_icc[map][ftype] = icc[map][ftype].mean()
        s_icc[map][ftype] = icc[map][ftype].std()

    # Tests
    histogram_icc(icc[map], f'hist_ICC_{map.upper()}', map)

# Export jsons
with open(f'avg_icc.json', 'w') as outfile:
    json.dump(m_icc, outfile, indent=4, sort_keys=True)

with open(f'std_icc.json', 'w') as outfile:
    json.dump(s_icc, outfile, indent=4, sort_keys=True)

os.chdir(cwd)
