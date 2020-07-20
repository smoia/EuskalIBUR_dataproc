#!/usr/bin/env python3

import json
import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns


FTYPE_LIST = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth', 'meica-cons']

SET_DPI = 100
FIGSIZE = (19.2, 2)

COLOURS = ['#07ad95ff', '#ff7f0eff', '#2ca02cff', '#ff33ccff',
           '#1f77b4ff']

FTYPE_DICT = {'pre': 'SE-PRE', 'echo-2': 'SE-MPR', 'optcom': 'OC-MPR',
              'meica-aggr': 'ME-AGG', 'meica-orth': 'ME-MOD',
              'meica-cons': 'ME-CON'}

cwd = os.getcwd()
os.chdir('/data/CVR_reliability/tests')

# Prepare dictionaries
icc = {'cvr': pd.DataFrame(), 'lag': pd.DataFrame()}
m_icc = {'cvr': {}, 'lag': {}}
s_icc = {'cvr': {}, 'lag': {}}

# Setup plot
bh_plot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
c = 13
hc = c//2
gs = bh_plot.add_gridspec(nrows=1, ncols=c)
bh_splt = {}
bh_splt['cvr'] = bh_plot.add_subplot(gs[0,:hc])
bh_splt['lag'] = bh_plot.add_subplot(gs[0,-hc:])
plt.tight_layout()

for map in ['cvr', 'lag']:
    # name axis
    bh_splt[map].set_xlabel(f'{map.upper()}', labelpad=-2)
    # Read files, import ICC values, compute average, and plot them
    for i, ftype in enumerate(FTYPE_LIST):
        icc[map][ftype] = np.genfromtxt(f'val/ICC2_{map}_masked_{ftype}.txt')[:, 3]
        m_icc[map][ftype] = icc[map][ftype].mean()
        s_icc[map][ftype] = icc[map][ftype].std()
        sns.kdeplot(data=icc[map][ftype], clip=(0, 1), color=COLOURS[i],
                    ax=bh_splt[map], label=FTYPE_DICT[ftype])

# Tweak legend
bh_splt['lag'].legend(bbox_to_anchor=(-1.05, .83, 1, .102), loc='upper right')
bh_splt['cvr'].legend().remove()
# Save plot
plt.savefig('hist_ICC.png', dpi=SET_DPI)

# Export jsons
with open(f'avg_icc.json', 'w') as outfile:
    json.dump(m_icc, outfile, indent=4, sort_keys=True)

with open(f'std_icc.json', 'w') as outfile:
    json.dump(s_icc, outfile, indent=4, sort_keys=True)

os.chdir(cwd)
