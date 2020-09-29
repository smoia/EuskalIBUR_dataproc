#!/usr/bin/env python3

import os

import matplotlib.pyplot as plt
import numpy as np


PARC_LIST = ['schaefer-100', 'flowterritories']  # , 'anatomical']

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#2ca02cff', '#d62728ff']  # , '#1f77b4ff']

PARC_DICT = {'schaefer-100': 'Functional Networks',
             'flowterritories': 'Vascular Territories',
             'rand': 'Random' }  #, 
             # 'anatomical': 'Anatomical regions'}

cwd = os.getcwd()
os.chdir('/data/CVR_reliability')

# Expand parc list
all_parcs = PARC_LIST
all_colours = COLOURS
for i in range(6, 121, 2):
    if i != 56:
        all_parcs = all_parcs + [f'rand-{i}']
        all_colours = all_colours + ['#bbbbbbff']

all_parcs = all_parcs + PARC_LIST
all_colours = all_colours + COLOURS

# Prepare dictionaries
icc = {'cvr': {}, 'lag': {}}
parcel_nlabels = {'cvr': {}, 'lag': {}}

for map in ['cvr']:  #, 'lag']:
    # Setup plot
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.xlabel('Number of parcels')
    plt.xlim(0, 120)
    plt.ylabel('ICC')
    plt.ylim(0, 1)

    # Import ICC values and populate plot #!# Check axes
    for i, parc in enumerate(all_parcs):
        icc[map][parc] = np.genfromtxt(f'ICC2_{map}_{parc}.1D')[:, 0]
        parcel_nlabels[map][parc] = np.asarray([icc[map][parc].shape[0]] *
                                               icc[map][parc].shape[0])
        plt.plot(parcel_nlabels[map][parc], icc[map][parc], '.', color=all_colours[i])

    plt.legend(PARC_DICT.values())
    plt.tight_layout()

    # Save plot
    plt.savefig(f'{map}_ICC.png', dpi=SET_DPI)
    plt.close('all')

os.chdir(cwd)
