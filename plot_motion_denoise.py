#!/usr/bin/env python3

import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

SET_DPI = 100
FIGSIZE = (18, 10)
BH_LEN = 39

COLOURS = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff']
FTYPE_LIST = ['pre', 'echo-2', 'optcom', 'meica']
SUB_LIST = ['007', '003', '002']
DVARS_LIST = ['norm', 'simple']
TIME = np.asarray(range(BH_LEN))


# 01. Make scatterplots of DVARS vs FD
def plot_DVARS_vs_FD(data):
    for sub in SUB_LIST:
        for dvars_type in DVARS_LIST:
            plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
            plot_title = f'DVARS vs FD, subject {sub}'
            if dvars_type == 'norm':
                plot_title = f'NORM {plot_title}'

            plt.title(plot_title)

            for ses in range(1, 10):
                x_col = f'{sub}_{ses:02g}_fd'
                # Skip ftype pre if norm_dvars
                if dvars_type == 'simple':
                    first_ftype = 0
                else:
                    first_ftype = 1

                # loop for ftype
                for i in range(first_ftype, 4):
                    if dvars_type == 'simple':
                        y_col = f'{sub}_{ses:02g}_dvars_{FTYPE_LIST[i]}'
                    else:
                        y_col = f'{sub}_{ses:02g}_{dvars_type}_dvars_{FTYPE_LIST[i]}'

                    sns.regplot(x=data[x_col], y=data[y_col], fit_reg=True,
                                label=FTYPE_LIST[i], color=COLOURS[i],
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
    for sub in SUB_LIST:
        for ses in range(1, 10):
            x_col = f'{sub}_{ses:02g}_fd'
            # loop for ftype
            for i in range(4):
                if dvars_type == 'simple':
                    y_col = f'{sub}_{ses:02g}_dvars_{FTYPE_LIST[i]}'
                else:
                    y_col = f'{sub}_{ses:02g}_{dvars_type}_dvars_{FTYPE_LIST[i]}'

                sns.regplot(x=data[x_col], y=data[y_col], scatter=False,
                            fit_reg=True, label=FTYPE_LIST[i], color=COLOURS[i],
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


# 02. Make timeseries plots
def plot_timeseries_and_BOLD_vs_FD():
    for sub in SUB_LIST:
        bh_timeplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
        bh_scatterplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
        bh_timeplot.suptitle(f'BreathHold (BH) response, subject {sub}')
        bh_scatterplot.suptitle(f'BOLD vs FD, subject {sub}')

        gs = bh_timeplot.add_gridspec(ncols=1, nrows=3, height_ratios=[2, 2, 1])
        bh_timesubplot = bh_timeplot.add_subplot(gs[2, 0])
        fd_responses = np.empty((72, BH_LEN))
        for ses in range(1, 10):
            fd = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02g}.1D')
            for bh in range(8):
                fd_responses[(8*(ses-1)+bh), :] = fd[BH_LEN*bh:BH_LEN*(bh+1)]

        bh_timesubplot.plot(fd_responses.mean(axis=0))

        bh_timesubplot.set_ylabel('avg FD')
        bh_timesubplot.set_xlabel('TPs')

        bh_timesubplot = bh_timeplot.add_subplot(gs[1, 0])

        for i in range(len(FTYPE_LIST)):
            dvars_responses = np.empty((72, BH_LEN))
            for ses in range(1, 10):
                dvars = np.genfromtxt(f'sub-{sub}/dvars_{FTYPE_LIST[i]}_sub-{sub}_ses-{ses:02d}.1D')
                for bh in range(8):
                    dvars_responses[(8*(ses-1)+bh), :] = dvars[BH_LEN*bh:BH_LEN*(bh+1)]

            avg = dvars_responses.mean(axis=0)
            std = dvars_responses.std(axis=0)
            bh_timesubplot.plot(TIME, avg,
                                label=f'{FTYPE_LIST[i]}', color=COLOURS[i])
            bh_timesubplot.fill_between(TIME, avg - std, avg + std,
                                        color=COLOURS[i], alpha=0.2)

        bh_timesubplot.set_ylabel('avg DVARS')

        bh_timesubplot = bh_timeplot.add_subplot(gs[0, 0])
        bh_scattersubplot = bh_scatterplot.add_subplot(1, 1, 1)

        for i in range(len(FTYPE_LIST)):
            bh_responses = np.empty((72, BH_LEN))
            for ses in range(1, 10):
                avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{FTYPE_LIST[i]}_sub-{sub}_ses-{ses:02g}.1D')
                for bh in range(8):
                    bh_responses[(8*(ses-1)+bh), :] = (avg_gm[BH_LEN*bh:BH_LEN*(bh+1)] -
                                                       avg_gm[BH_LEN*bh:BH_LEN*(bh+1)].mean())

            avg = bh_responses.mean(axis=0)
            std = bh_responses.std(axis=0)
            bh_timesubplot.plot(TIME, avg,
                                label=f'{FTYPE_LIST[i]}', color=COLOURS[i])
            bh_timesubplot.fill_between(TIME, avg - std, avg + std,
                                        color=COLOURS[i], alpha=0.2)
            bh_scattersubplot.plot(bh_responses.mean(axis=0), fd_responses.mean(axis=0),
                                   'o', label=f'{FTYPE_LIST[i]}', color=COLOURS[i])

        bh_timeplot.legend()
        bh_timesubplot.set_ylabel('avg BOLD')
        bh_timeplot.savefig(f'{sub}_BOLD_time.png', dpi=SET_DPI)

        bh_scatterplot.legend()
        bh_scattersubplot.set_xlabel('avg BOLD')
        bh_scattersubplot.set_ylabel('FD')
        bh_scatterplot.savefig(f'{sub}_BOLD_vs_FD.png', dpi=SET_DPI)


# 03. Make DBOLD vs FD plot
def plot_tps_BOLD_vs_FD():
    for sub in SUB_LIST:
        fd_responses = np.empty((72, BH_LEN))
        for ses in range(1, 10):
            fd = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02g}.1D')
            for bh in range(8):
                fd_responses[(8*(ses-1)+bh), :] = fd[BH_LEN*bh:BH_LEN*(bh+1)]

        bh_responses = np.empty((72, BH_LEN, len(FTYPE_LIST)))
        for i in range(len(FTYPE_LIST)):
            for ses in range(1, 10):
                avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{FTYPE_LIST[i]}_sub-{sub}_ses-{ses:02g}.1D')
                for bh in range(8):
                    bh_responses[(8*(ses-1)+bh), :, i] = avg_gm[BH_LEN*bh:BH_LEN*(bh+1)]

        bh_delta_responses = np.empty((72, BH_LEN, len(FTYPE_LIST)))
        for i in range(len(FTYPE_LIST)):
            bh_delta_responses[:, :, i] = (bh_responses[:, :, i] -
                                           bh_responses[:, :, 0])

        for tps in range(BH_LEN):
            plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
            plt.title(f'BOLD_vs_FD, sub {sub}, tp {tps:02g}')
            for i in range(1, len(FTYPE_LIST)):
                # plt.plot(bh_delta_responses[:, tps, i], fd_responses[:, tps],
                #          'o', label=f'{FTYPE_LIST[i]}', color=COLOURS[i])
                sns.regplot(x=bh_delta_responses[:, tps, i],
                            y=fd_responses[:, tps], fit_reg=True,
                            label=FTYPE_LIST[i], color=COLOURS[i],
                            robust=False, ci=None)

            plt.legend()
            plt.ylabel('FD')
            plt.ylim(0, 0.7)
            plt.xlabel('BOLD post - BOLD pre')
            plt.xlim(-3000, 0)
            plt.savefig(f'{sub}_BOLD_vs_FD_tps_{tps:02g}', dpi=SET_DPI)
            plt.clf()
            plt.close()


if __name__ == '__main__':
    cwd = os.getcwd()

    os.chdir('/data/ME_Denoising')

    data = pd.read_csv('sub_table.csv')

    plot_DVARS_vs_FD(data)
    plot_timeseries_and_BOLD_vs_FD()
    # os.makedirs('tps')
    # os.chdir('tps')
    # plot_tps_BOLD_vs_FD()

    os.chdir(cwd)
