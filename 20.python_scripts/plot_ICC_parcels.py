#!/usr/bin/env python3

import glob
import os
import re

import matplotlib.pyplot as plt
import numpy as np


PARC_LIST = ['schaefer-100', 'flowterritories']  # , 'anatomical']

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#2ca02cff', '#d62728ff']  # , '#1f77b4ff']

PARC_DICT = {'schaefer-100': 'Functional Networks',
             'flowterritories': 'Vascular Territories',
             'rand': 'Random'}  #, 
             # 'anatomical': 'Anatomical regions'}
MAPS = ['cvr', 'lag']

cwd = os.getcwd()
os.chdir('/data/CVR_reliability')

# Prepare dictionaries
icc = {'cvr': {}, 'lag': {}}
parcel_nlabels = {'cvr': {}, 'lag': {}}
parcel_nvoxels = {'cvr': {}, 'lag': {}}
all_parcs = {'cvr': PARC_LIST, 'lag': PARC_LIST}
all_colours = {'cvr': COLOURS, 'lag': COLOURS}
files = {'cvr': [], 'lag': []}

for k in MAPS:  # equivalent to icc.keys():
    # Expand parc list into two lists by reading the files in the folder
    files[k] = glob.glob(f'*{k}_rand*')

    for fl in files[k]:
        all_parcs[k] = all_parcs[k] + [re.search(f'{k}_(.+?).1D', fl).group(1)]
        all_colours[k] = all_colours[k] + ['#bbbbbbff']

    # Read parcels voxels
    for parc in all_parcs[k]:
        parcel_nvoxels[k][parc] = np.genfromtxt(f'/scripts/90.template/masked_atlases/{parc}_vx.1D')[:, 0]

    # Plot ICC against parcels
    # Setup plot
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.xlabel('Number of parcels')
    plt.xlim(0, 120)
    plt.ylabel('ICC')
    # plt.ylim(0, 1)

    # Import ICC values and populate plot #!# Check axes
    for i, parc in enumerate(all_parcs[k]):
        icc[k][parc] = np.genfromtxt(f'ICC2_{k}_{parc}.1D')[:, 0]
        # Assuming that if the labels are 20 or less a sharp 0 was added just for processing data
        if icc[k][parc].shape[0] <= 20:
            icc[k][parc] = icc[k][parc][icc[k][parc] != 0]

        parcel_nlabels[k][parc] = np.asarray([icc[k][parc].shape[0]] *
                                             icc[k][parc].shape[0])
        plt.plot(parcel_nlabels[k][parc], icc[k][parc], '.', color=all_colours[k][i])

    for i, parc in enumerate(all_parcs[k][:2]):
        plt.plot(parcel_nlabels[k][parc], icc[k][parc], '.', color=all_colours[k][i])

    plt.legend(PARC_DICT.values())
    plt.tight_layout()

    # Save plot
    plt.savefig(f'../{k}_ICC_by_parcel.png', dpi=SET_DPI)
    # plt.close('all')

    # Plot ICC against parcels
    # Setup plot
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.xlabel('Number of voxels in MNI')
    # plt.xlim(0, 120)
    plt.ylabel('ICC')
    # plt.ylim(0, 1)

    for i, parc in enumerate(all_parcs[k]):
        plt.plot(parcel_nvoxels[k][parc], icc[k][parc], '.', color=all_colours[k][i])

    for i, parc in enumerate(all_parcs[k][:2]):
        plt.plot(parcel_nvoxels[k][parc][:len(icc[k][parc])], icc[k][parc], '.', color=all_colours[k][i])

    plt.legend(PARC_DICT.values())
    plt.tight_layout()

    # Save plot
    plt.savefig(f'../{k}_ICC_by_voxel.png', dpi=SET_DPI)
    # plt.close('all')

os.chdir(cwd)
