#!/usr/bin/env python3

import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

SET_DPI = 100
FIGSIZE = (18, 10)
BH_LEN = 39  # in TRs

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
        plot_title = f'DVARS vs FD sub {sub}'
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
                            label=ftype_list[i], color=colours[i])

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
plot_title = f'DVARS vs FD sub {sub}'
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
                        fit_reg=True, label=ftype_list[i], color=colours[i])

plt.legend()
plt.xlabel('FD')
plot_ylabel = 'DVARS'
if dvars_type == 'norm':
    plot_ylabel = f'NORM {plot_ylabel}'

plt.ylabel(plot_ylabel)
if dvars_type == 'simple':
    fig_name = f'{sub}_DVARS_vs_FD.png'
else:
    fig_name = f'{sub}_{dvars_type}_DVARS_vs_FD.png'

plt.savefig(fig_name, dpi=SET_DPI)
plt.clf()
plt.close()

# 02. Make timeseries plots skipping "pre"
colours = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff']
ftype_list = ['pre', 'echo-2', 'optcom', 'meica']

for sub in sub_list:
    for i in range(1, len(ftype_list)):
        bh_responses = []
        for ses in range(1, 10):
            avg_gm = np.genfromtxt(f'sub-{sub}_ses-{ses}_GM_{ftype_list[i]}_avg.1D')
            for bh in range(8):
                bh_responses.append(avg_gm[BH_LEN*i:BH_LEN*(i+1)])

        





plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
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
                        fit_reg=True, label=ftype_list[i], color=colours[i])

plt.legend()
plt.xlabel('FD')
plot_ylabel = 'DVARS'
if dvars_type == 'norm':
    plot_ylabel = f'NORM {plot_ylabel}'

plt.ylabel(plot_ylabel)
if dvars_type == 'simple':
    fig_name = f'{sub}_DVARS_vs_FD.png'
else:
    fig_name = f'{sub}_{dvars_type}_DVARS_vs_FD.png'

plt.savefig(fig_name, dpi=SET_DPI)
plt.clf()
plt.close()




os.chdir(cwd)
