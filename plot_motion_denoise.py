#!/usr/bin/env python3

import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

SET_DPI = 100
FIGSIZE = (18, 10)
BH_LEN = 39

cwd = os.getcwd()

os.chdir('/data/ME_Denoising')

data = pd.read_csv('sub_table.csv')

colours = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff']
ftype_list = ['pre', 'echo-2', 'optcom', 'meica']
sub_list = ['007', '003', '002']
dvars_list = ['norm', 'simple']

# 01. Make scatterplots of DVARS vs FD
for sub in sub_list:
    for dvars_type in dvars_list:
        plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
        plot_title = f'DVARS vs FD, subject {sub}'
        if dvars_type == 'norm':
            plot_title = f'NORM {plot_title}'

        plt.title(plot_title)

        for ses in range(1, 10):
            x_col = f'{sub}_{ses:02g}_fd'
            # loop for ftype
            for i in range(4):
                if dvars_type == 'simple':
                    y_col = f'{sub}_{ses:02g}_dvars_{ftype_list[i]}'
                else:
                    y_col = f'{sub}_{ses:02g}_{dvars_type}_dvars_{ftype_list[i]}'

                sns.regplot(x=data[x_col], y=data[y_col], fit_reg=True,
                            label=ftype_list[i], color=colours[i],
                            robust=True, ci=None)

        plt.legend()
        plt.xlabel('FD')
        plt.xlim(-1, 5)
        plot_ylabel = 'DVARS'
        if dvars_type == 'norm':
            plot_ylabel = f'NORM {plot_ylabel}'

        plt.ylabel(plot_ylabel)
        plt.ylim(-80, 300)
        if dvars_type == 'simple':
            fig_name = f'{sub}_DVARS_vs_FD.png'
        else:
            fig_name = f'{sub}_{dvars_type}_DVARS_vs_FD.png'

        plt.savefig(fig_name, dpi=SET_DPI)
        plt.clf()
        plt.close()

plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
plot_title = f'DVARS vs FD, all subjects'
if dvars_type == 'norm':
    plot_title = f'NORM {plot_title}'

plt.title(plot_title)
for sub in sub_list:
    for ses in range(1, 10):
        x_col = f'{sub}_{ses:02g}_fd'
        # loop for ftype
        for i in range(4):
            if dvars_type == 'simple':
                y_col = f'{sub}_{ses:02g}_dvars_{ftype_list[i]}'
            else:
                y_col = f'{sub}_{ses:02g}_{dvars_type}_dvars_{ftype_list[i]}'

            sns.regplot(x=data[x_col], y=data[y_col], scatter=False,
                        fit_reg=True, label=ftype_list[i], color=colours[i],
                        robust=True, ci=None)

plt.legend()
plt.xlabel('FD')
plot_ylabel = 'DVARS'
if dvars_type == 'norm':
    plot_ylabel = f'NORM {plot_ylabel}'

plt.ylabel(plot_ylabel)
if dvars_type == 'simple':
    fig_name = f'allsubs_DVARS_vs_FD.png'
else:
    fig_name = f'allsubs_{dvars_type}_DVARS_vs_FD.png'

plt.savefig(fig_name, dpi=SET_DPI)
plt.clf()
plt.close()

# 02. Make timeseries plots skipping "pre"

for sub in sub_list:
    bh_timeplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    bh_scatterplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    bh_timeplot.title(f'BreathHold (BH) response, subject {sub}')
    bh_scatterplot.title(f'BreathHold (BH) response, subject {sub}')

    bh_timeplot.subplot(2, 1, 2, gridspec_kw={'height_ratios': [2, 1]})
    fd_responses = []
    for ses in range(1, 10):
        fd = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02g}.1D')
        for bh in range(8):
            fd_responses.append(fd[BH_LEN*i:BH_LEN*(i+1)])

        fd_responses = np.asarray(fd_responses)
        bh_timeplot.plot(bh_responses.mean(axis=0))

    bh_timeplot.ylabel('avg FD')
    bh_timeplot.xlabel('TPs')

    bh_timeplot.subplot(2, 1, 1, gridspec_kw={'height_ratios': [2, 1]})
    for i in range(1, len(ftype_list)):
        bh_responses = []
        for ses in range(1, 10):
            avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{ftype_list[i]}_sub-{sub}_ses-{ses:02g}.1D')
            for bh in range(8):
                bh_responses.append(avg_gm[BH_LEN*i:BH_LEN*(i+1)])

        bh_responses = np.asarray(bh_responses)
        bh_timeplot.plot(bh_responses.std(axis=0),
                         label=f'{ftype_list[i]}', color=colours[i])
        bh_scatterplot.plot(bh_responses.std(axis=0), fd_responses.mean(axis=0),
                            label=f'{ftype_list[i]}', color=colours[i])

    bh_timeplot.legend()
    bh_timeplot.ylabel('stdev of CVR')
    bh_timeplot.savefig(f'{sub}_CVR_time.png', dpi=SET_DPI)
    bh_timeplot.clf()
    bh_timeplot.close()

    bh_scatterplot.legend()
    bh_scatterplot.ylabel('stdev of CVR vs FD')
    bh_scatterplot.savefig(f'{sub}_CVR_vs_FD.png', dpi=SET_DPI)
    bh_scatterplot.clf()
    bh_scatterplot.close()

os.chdir(cwd)
