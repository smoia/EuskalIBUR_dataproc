#!/usr/bin/env python3

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

from scipy.stats import kurtosis, iqr

SET_DPI = 100
FIGSIZE = (18, 10)

SUB_LIST = ['002', '003', '007']
FTYPE_LIST = ['echo-2', 'optcom', 'meica', 'vessels']  #, 'networks']
VALUE_LIST = ['cvrvals', 'lagvals']
COLOURS = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff']  #, '#ac45a8ff']


# voxels in session
def vx_vs_ses(ftypes=FTYPE_LIST, subs=SUB_LIST, vals=VALUE_LIST):
    for sub in subs:
        for val in vals:
            for ftype in ftypes:
                fname = f'sub-{sub}_{ftype}_{val}'
                data = pd.read_csv(f'{fname}.csv')
                data = data.sort_values(by=['ses-01'])
                decimated_data = data.iloc[::100, :]
                formatted_data = pd.melt(decimated_data, var_name="ses",
                                         value_name="cvr")
                formatted_data['vox'] = np.tile(np.array(range(decimated_data.shape[0])), 9)
                cmap = sns.color_palette("coolwarm", decimated_data.shape[0])
                plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
                sns.lineplot(x="ses", y="cvr", hue="vox",
                             data=formatted_data,
                             palette=cmap, alpha=.1)
                sns.scatterplot(x="ses", y="cvr", hue="vox",
                                data=formatted_data,
                                palette=cmap, marker='.', edgecolor=None)
                plt.title(f'sub {sub} {ftype} {val}')
                plt.savefig(f'{fname}_vox_by_session.png', dpi=SET_DPI)
                plt.clf()
                plt.close()


# histograms
def ftype_histograms(ftypes=FTYPE_LIST, subs=SUB_LIST, vals=VALUE_LIST):
    for sub in subs:
        for val in vals:
            data_dic = {}
            for ftype in ftypes:
                fname = f'sub-{sub}_{ftype}_{val}.csv'
                data_dic[ftype] = pd.read_csv(fname)

            data = pd.concat(data_dic.values(), axis=1, keys=data_dic.keys())

            nrows = len(ftypes)
            ncols = len(data[ftypes[0]])
            kurt_df = pd.DataFrame()
            kurt_df['type'] = [x for x in ftypes for _ in range(ncols)]
            kurt_df['k'] = kurtosis(data)
            fig = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
            plt.title(f'sub {sub} {val} kurtosis')
            sns.boxplot(x='type', y='k', data=kurt_df,
                        palette=COLOURS, hue='type')
            plt.savefig(f'sub-{sub}_{val}_kurtosis.png', dpi=SET_DPI)
            plt.clf()
            plt.close()

            fig = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
            plt.title(f'sub {sub} {val}')
            gs = fig.add_gridspec(nrows=nrows, ncols=ncols)
            for i in range(nrows):
                for j in range(ncols):
                    plt.subplot(gs[i, j])
                    sns.kdeplot(data=data[ftypes[i], f'ses-{(j+1):02g}'],
                                shade=True, color=COLOURS[i]).legend_.remove()

            plt.savefig(f'sub-{sub}_{val}_histograms.png', dpi=SET_DPI)
            plt.clf()
            plt.close()


if __name__ == '__main__':
    cwd = os.getcwd()

    os.chdir('/bcbl/home/public/PJMASK_2/preproc/CVR/00.Reliability')
    # os.chdir('/home/nemo/Documenti/Archive/Data/gdrive/PJMASK/CVR/00.Reliability')
    # os.chdir('/data/CVR/00.Reliability')

    # vx_vs_ses()
    ftype_histograms()

    plt.close('all')
    os.chdir(cwd)