#!/usr/bin/env python3

import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

SET_DPI = 100
FIGSIZE = (18, 10)


cwd = os.getcwd()

os.chdir('/data/ME_Denoising')

data = pd.read_csv('sub_table.csv')

colours = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff']
ftype_list = ['pre', 'echo-2', 'optcom', 'meica']
sub_list = ['007', '003', '002']

for sub in sub_list:
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.title(f'DVARS vs FD sub {sub}')

    for ses in range(1,10):
        x_col=f'{sub}_{ses:02g}_fd'
        # loop for ftype
        for i in range(4):
            y_col=f'{sub}_{ses:02g}_dvars_{ftype_list[i]}'
            sns.regplot(x=data[x_col], y=data[y_col], fit_reg=True, label=ftype_list[i], color=colours[i])
    
    plt.legend()
    plt.xlabel('FD')
    plt.xlim(-1, 5)
    plt.ylabel('DVARS')
    plt.ylim(-80, 300)
    plt.savefig(f'{sub}_DVARS_vs_FD.png', dpi=SET_DPI)
    plt.clf()
    plt.close()

plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
plt.title('DVARS vs FD allsubs')
for sub in sub_list:
    for ses in range(1,10):
        x_col=f'{sub}_{ses:02g}_fd'
        # loop for ftype
        for i in range(4):
            y_col=f'{sub}_{ses:02g}_dvars_{ftype_list[i]}'
            sns.regplot(x=data[x_col], y=data[y_col], scatter=False, fit_reg=True, label=ftype_list[i], color=colours[i])

plt.legend()
plt.xlabel('FD')
plt.ylabel('DVARS')
plt.savefig(f'Allsubs_DVARS_vs_FD.png', dpi=SET_DPI)
plt.clf()
plt.close()


os.chdir(cwd)