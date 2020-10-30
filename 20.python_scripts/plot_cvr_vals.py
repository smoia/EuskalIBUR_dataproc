#!/usr/bin/env python3

import os
import sys

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
import pandas as pd
import seaborn as sns


SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

SET_DPI = 100
FIGSIZE_1 = (9, 10)
FIGSIZE_2 = (15, 8)

FTYPE_LIST = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth',
              'meica-cons']
COLOURS = ['#d62728ff', '#2ca02cff', '#ff7f0eff', '#1f77b4ff',
           '#ff33ccff']
FTYPE_DICT = {'echo-2': 'SE-MPR', 'optcom': 'OC-MPR',
              'meica-aggr': 'ME-AGG', 'meica-orth': 'ME-MOD',
              'meica-cons': 'ME-CON'}

LAST_SES += 1

sub = sys.argv[1]
wdr = sys.argv[2]

os.chdir(wdr)
try:
    os.makedirs('plots')
except Exception:
    pass

# Load segmentation
seg_img = nib.load(f'sub-{sub}/ses-01/anat_preproc/'
                   f'sub-{sub}_ses-01_acq-uni_T1w_seg2mref.nii.gz')
seg = seg_img.get_data()
# GM = 2, WM = 3

# Create data dictionary
data = {'CVR': {}, 'Lag': {}}
dmean = {'CVR': {}, 'Lag': {}}

# Prepare legends for plots

patch = []
for n, ftype in enumerate(FTYPE_LIST):
    patch = patch + [mpatches.Patch(color=COLOURS[n], label=FTYPE_DICT[ftype])]

pal = sns.color_palette('light:#000000ff', n_colors=3)
patch = patch + [mpatches.Patch(color=pal[-1], label='Grey Matter'),
                 mpatches.Patch(color=pal[-2], label='White Matter')]

for k in data.keys():
    data[k] = pd.DataFrame(columns=[k, 'tissue', 'ftype', 'ses', 'sub'])
    for sub in SUB_LIST:
        for ses in range(1, LAST_SES):
            for ftype in FTYPE_LIST:
                # Load maps
                if k == 'Lag':
                    img = nib.load(f'CVR/sub-{sub}_ses-{ses:02d}_{ftype}_map_cvr/'
                                   f'sub-{sub}_ses-{ses:02d}_{ftype}_cvr_lag_masked.nii.gz')
                else:
                    img = nib.load(f'CVR/sub-{sub}_ses-{ses:02d}_{ftype}_map_cvr/'
                                   f'sub-{sub}_ses-{ses:02d}_{ftype}_cvr_masked.nii.gz')

                img_data = img.get_data()

                # Get GM and WM, remove 0, absolutise, remove outliers
                d = {'gm': img_data[seg == 2], 'wm': img_data[seg == 3]}

                for dk in d.keys():
                    if k == 'CVR':
                        # d[dk] = np.abs(d[dk])
                        d[dk] = d[dk][(d[dk] < 5) & (d[dk] > -5)]

                    d[dk] = d[dk][d[dk] != 0]

                    df = pd.DataFrame({k: d[dk], 'tissue': [dk]*d[dk].size,
                                      'ftype': [FTYPE_DICT[ftype]]*d[dk].size},
                                      'ses': [f'{ses:02d}']*d[dk].size,
                                      'sub': [sub]*d[dk].size)
                    data[k] = [data[k].append(df, ignore_index=True)

        # Plot value plots per subjects
        fig, ax = plt.subplots(len(FTYPE_LIST), figsize=FIGSIZE_1, dpi=SET_DPI,
                               sharex=True)

        plt.suptitle(f'Subject {sub}, {k} values across approaches')

        for n, ftype in enumerate(FTYPE_LIST):
            pal = sns.color_palette(f'light:{COLOURS[n]}', n_colors=3)
            sns.violinplot(data=data[k].loc(data[k]['sub'] == sub), x=k, y='ftype',
                           hue='tissue', split=True, inner='quartile',
                           palette=pal[::-1], ax=ax[n], gridsize=10000,
                           cut=0)

            if n != len(FTYPE_LIST)-1:
                ax[n].xaxis.set_visible(False)
            ax[n].yaxis.set_label_text('')
            ax[n].legend().remove()
            if n == 0:
                plt.legend(handles=patch)
            if k == 'CVR':
                ax[n].set_xlim([-1, 1])
            else:
                ax[n].set_xlim([-9, 9])

        plt.savefig(f'plots/sub-{sub}_{k}_vals.png', dpi=SET_DPI)

    # Prepare new dataframe and dictionaries
    nvox = pd.DataFrame(columns=['nvox', 'tissue', 'ftype'])
    for ftype in FTYPE_LIST:
        for ses in range(1, LAST_SES):
            key = f'{ses:02d}{ftype}'
            for tissue in ['gm', 'wm']:
                # Count voxels (it's a size)
                entry = {'nvox':
                         data[k][key].loc(data[k][key]['tissue' == tissue]).size(),
                         'tissue': tissue, 'ftype': ftype}
                nvox = nvox.append(entry, ignore_index=True)

    # Plot the amount of significant voxels
    fig, ax = plt.subplots(1, len(FTYPE_LIST), figsize=FIGSIZE_2, dpi=SET_DPI,
                           sharey=True)
    plt.suptitle(f'Subject {sub}, number of significant voxels')

    for n, ftype in enumerate(FTYPE_LIST):
        pal = sns.color_palette(f'light:{COLOURS[n]}', n_colors=3)
        sns.boxplot(data=nvox, x='ftype', y='Significant voxels', hue='Tissue',
                    palette=pal[::-1], ax=ax[n])

        if n != 0:
            ax[n].yaxis.set_visible(False)
        else:
            ax[n].yaxis.set_label_text('Significant voxels')
        ax[n].xaxis.set_label_text('')
        ax[n].legend().remove()
        if n == len(FTYPE_LIST)-1:
            plt.legend(handles=patch)

    plt.savefig(f'plots/sub-{sub}_count.png', dpi=SET_DPI)
