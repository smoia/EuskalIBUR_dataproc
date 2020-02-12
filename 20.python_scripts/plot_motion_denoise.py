#!/usr/bin/env python3
import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10

SET_DPI = 100
FIGSIZE = (11,7)
BH_LEN = 39

FTYPE_LIST = ['pre', 'echo-2', 'optcom', 'meica-aggr', 'meica-orth',
              'meica-preg', 'meica-mvar']  # , 'meica-recn']
COLOURS = ['#1f77b4ff', '#ff7f0eff', '#2ca02cff', '#d62728ff', '#ff33ccff',
           '#663300ff', '#003300ff']  # , '#07ad95ff']
FTYPE_DICT = {'pre': 'Pre', 'echo-2': 'SE', 'optcom': 'OC',
              'meica-aggr': 'Aggr', 'meica-orth': 'Orth',
              'meica-preg': 'NAggr', 'meica-mvar': '4D'}

TIME = np.asarray(range(BH_LEN))

LAST_SES += 1


# 01. Make scatterplots of DVARS vs FD
def plot_DVARS_vs_FD(data, ftypes=FTYPE_LIST):
    for sub in SUB_LIST:
        plt.figure(figsize=FIGSIZE, dpi=SET_DPI)

        plot_title = f'DVARS vs FD, subject {sub}'
        plt.title(plot_title)

        for ses in range(1, LAST_SES):
            x_col = f'{sub}_{ses:02g}_fd'
            # loop for ftype
            for i, ftype in enumerate(ftypes):
                y_col = f'{sub}_{ses:02g}_dvars_{ftype}'
                sns.regplot(x=data[x_col], y=data[y_col], fit_reg=True,
                            label=FTYPE_DICT[ftype], color=COLOURS[i],
                            robust=True, ci=None)

            if ses == 1:
                plt.legend()

        plt.xlabel('FD')
        plt.xlim(-.1, 1)
        plot_ylabel = 'DVARS'
        plt.ylabel(plot_ylabel)
        plt.ylim(-10, 120)
        fig_name = f'{sub}_DVARS_vs_FD.png'
        plt.savefig(fig_name, dpi=SET_DPI)
        plt.clf()
        plt.close()

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plot_title = f'DVARS vs FD, all subjects'
    plt.title(plot_title)

    for i, ftype in enumerate(ftypes):
        x_data = np.empty(0)
        y_data = np.empty(0)
        for sub in SUB_LIST:
            for ses in range(1, LAST_SES):
                x_col = f'{sub}_{ses:02g}_fd'
                x_data = np.append(x_data, data[x_col])
                y_col = f'{sub}_{ses:02g}_dvars_{ftype}'
                y_data = np.append(y_data, data[y_col])

        sns.regplot(x=x_data, y=y_data, scatter=False,
                    fit_reg=True,  label=FTYPE_DICT[ftype],
                    color=COLOURS[i], ci=100)

    for i, ftype in enumerate(ftypes):
        for sub in SUB_LIST:
            x_col = f'{sub}_{ses:02g}_fd'
            for ses in range(1, LAST_SES):
                y_col = f'{sub}_{ses:02g}_dvars_{ftype}'
                sns.regplot(x=data[x_col], y=data[y_col], scatter=False,
                            fit_reg=True,
                            color=COLOURS[i], robust=True, ci=None,
                            line_kws={'alpha': 0.05})

    plt.legend(FTYPE_DICT.values())
    plt.xlabel('FD')
    plot_ylabel = 'DVARS'
    plt.ylabel(plot_ylabel)
    fig_name = f'allsubs_DVARS_vs_FD.png'
    plt.savefig(fig_name, dpi=SET_DPI)
    plt.clf()
    plt.close()


# 02. Make timeseries plots
def plot_timeseries_and_BOLD_vs_FD(ftypes=FTYPE_LIST):
    for sub in SUB_LIST:
        bh_timeplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
        bh_timeplot.suptitle(f'BreathHold (BH) response, subject {sub}')

        gs = bh_timeplot.add_gridspec(nrows=(len(ftypes)+1), ncols=2)
        for col in range(2):
            bh_timesubplot = bh_timeplot.add_subplot(gs[len(ftypes), col])
            fd_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
            for ses in range(1, LAST_SES):
                fd = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02g}.1D')
                for bh in range(8):
                    fd_responses[(8*(ses-1)+bh), :] = fd[12+BH_LEN*bh:12+BH_LEN*(bh+1)]

            bh_timesubplot.plot(fd_responses.mean(axis=0))

            bh_timesubplot.set_ylabel('FD')
            bh_timesubplot.set_xlabel('TPs')

        avg = np.empty((len(ftypes), BH_LEN))
        std = np.empty((len(ftypes), BH_LEN))

        for i, ftype in enumerate(ftypes):
            dvars_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
            for ses in range(1, LAST_SES):
                dvars = np.genfromtxt(f'sub-{sub}/dvars_{ftype}_sub-{sub}_ses-{ses:02d}.1D')
                for bh in range(8):
                    dvars_responses[(8*(ses-1)+bh), :] = dvars[12+BH_LEN*bh:12+BH_LEN*(bh+1)]

            avg[i, :] = dvars_responses.mean(axis=0)
            std[i, :] = dvars_responses.std(axis=0)

        for i, ftype in enumerate(ftypes):
            bh_timesubplot = bh_timeplot.add_subplot(gs[i, 0])
            bh_timesubplot.plot(TIME, avg[i, :],
                                label=FTYPE_DICT[ftype], color=COLOURS[i])
            bh_timesubplot.fill_between(TIME, avg[i, :] - std[i, :],
                                        avg[i, :] + std[i, :],
                                        color=COLOURS[i], alpha=0.2)

            bh_timesubplot.set_ylim(0, (avg + std).max()+((avg + std).max()/10))
            bh_timesubplot.set_ylabel('DVARS')
            bh_timesubplot.axes.get_xaxis().set_ticks([])

        avg = np.empty((len(ftypes), BH_LEN))
        std = np.empty((len(ftypes), BH_LEN))
        max_delta_y = 0  # This is for visualisation purposes

        for i, ftype in enumerate(ftypes):
            bh_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
            for ses in range(1, LAST_SES):
                avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{ftype}_sub-{sub}_ses-{ses:02g}.1D')
                for bh in range(8):
                    bh_trial = avg_gm[12+BH_LEN*bh:12+BH_LEN*(bh+1)]
                    bh_responses[(8*(ses-1)+bh), :] = (bh_trial - bh_trial.mean()) / bh_trial.mean()

            avg[i, :] = bh_responses.mean(axis=0)
            std[i, :] = bh_responses.std(axis=0)

            delta_y = (avg + std)[i, :].max() - (avg - std)[i, :].min() + 0.004
            if delta_y > max_delta_y:
                max_delta_y = delta_y

        for i, ftype in enumerate(ftypes):
            bh_timesubplot = bh_timeplot.add_subplot(gs[i, 1])
            bh_timesubplot.plot(TIME, avg[i, :],
                                label=FTYPE_DICT[ftype], color=COLOURS[i])
            bh_timesubplot.fill_between(TIME, avg[i, :] - std[i, :],
                                        avg[i, :] + std[i, :],
                                        color=COLOURS[i], alpha=0.2)

            min_y = (avg - std)[i, :].min() - 0.002
            bh_timesubplot.set_ylim(min_y, min_y + delta_y)
            bh_timesubplot.set_ylabel('% BOLD')
            bh_timesubplot.axes.get_xaxis().set_ticks([])
            bh_timesubplot.legend(loc=1, prop={'size': 8})

        bh_timeplot.savefig(f'{sub}_BOLD_time.png', dpi=SET_DPI)

        plt.close('all')

        # for ses in range(1, LAST_SES):
        #     bh_timesesplot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
        #     bh_timesesplot.suptitle(f'BreathHold (BH) response, subject {sub},'
        #                             f'session {ses:02g}')
        #     gs = bh_timesesplot.add_gridspec(nrows=(len(ftypes)+1), ncols=2)
        #     for col in range(2):
        #         bh_timesubplot = bh_timesesplot.add_subplot(gs[len(ftypes), col])
        #         bh_timesubplot.plot(fd_responses[8*(ses-1):8*ses, :].mean(axis=0))
        #         bh_timesubplot.set_ylabel('FD')
        #         bh_timesubplot.set_xlabel('TPs')

        #     avg = np.empty((len(ftypes), BH_LEN))
        #     std = np.empty((len(ftypes), BH_LEN))

        #     for i, ftype in enumerate(ftypes):
        #         dvars_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
        #         for ses in range(1, LAST_SES):
        #             dvars = np.genfromtxt(f'sub-{sub}/dvars_{ftype}_sub-{sub}_ses-{ses:02d}.1D')
        #             for bh in range(8):
        #                 dvars_responses[(8*(ses-1)+bh), :] = dvars[12+BH_LEN*bh:12+BH_LEN*(bh+1)]

        #         avg[i, :] = dvars_responses.mean(axis=0)
        #         std[i, :] = dvars_responses.std(axis=0)

        #     for i, ftype in enumerate(ftypes):
        #         bh_timesubplot = bh_timesesplot.add_subplot(gs[i, 0])
        #         bh_timesubplot.plot(TIME, avg[i, :],
        #                             label=FTYPE_DICT[ftype], color=COLOURS[i])
        #         bh_timesubplot.fill_between(TIME, avg[i, :] - std[i, :],
        #                                     avg[i, :] + std[i, :],
        #                                     color=COLOURS[i], alpha=0.2)

        #         bh_timesubplot.set_ylim(0, (avg + std).max()+((avg + std).max()/10))
        #         bh_timesubplot.set_ylabel('DVARS')
        #         bh_timesubplot.axes.get_xaxis().set_ticks([])

        #     for i, ftype in enumerate(ftypes):
        #         bh_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
        #         for ses in range(1, LAST_SES):
        #             avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{ftype}_sub-{sub}_ses-{ses:02g}.1D')
        #             for bh in range(8):
        #                 bh_trial = avg_gm[12+BH_LEN*bh:12+BH_LEN*(bh+1)]
        #                 bh_responses[(8*(ses-1)+bh), :] = (bh_trial - bh_trial.mean()) / bh_trial.mean()

        #         avg[i, :] = bh_responses.mean(axis=0)
        #         std[i, :] = bh_responses.std(axis=0)

        #     for i, ftype in enumerate(ftypes):
        #         bh_timesubplot = bh_timesesplot.add_subplot(gs[i, 1])
        #         bh_timesubplot.plot(TIME, avg[i, :],
        #                             label=FTYPE_DICT[ftype], color=COLOURS[i])
        #         bh_timesubplot.fill_between(TIME, avg[i, :] - std[i, :],
        #                                     avg[i, :] + std[i, :],
        #                                     color=COLOURS[i], alpha=0.2)

        #         min_y = (avg - std)[i, :].min() - 0.002
        #         bh_timesubplot.set_ylim(min_y, min_y + delta_y)
        #         bh_timesubplot.set_ylabel('% BOLD')
        #         bh_timesubplot.axes.get_xaxis().set_ticks([])
        #         bh_timesubplot.legend(loc=1, prop={'size': 8})

        #     bh_timesesplot.savefig(f'{sub}_BOLD_time_ses_{ses:02g}.png',
        #                            dpi=SET_DPI)


# 03. Make DBOLD vs FD plot
# def plot_tps_BOLD_vs_FD():
#     for sub in SUB_LIST:
#         fd_responses = np.empty((8*(LAST_SES - 1), BH_LEN))
#         for ses in range(1, LAST_SES):
#             fd = np.genfromtxt(f'sub-{sub}/fd_sub-{sub}_ses-{ses:02g}.1D')
#             for bh in range(8):
#                 fd_responses[(8*(ses-1)+bh), :] = fd[BH_LEN*bh:BH_LEN*(bh+1)]

#         bh_responses = np.empty((8*(LAST_SES - 1), BH_LEN, len(ftypes)))
#         for i in range(len(ftypes)):
#             for ses in range(1, LAST_SES):
#                 avg_gm = np.genfromtxt(f'sub-{sub}/avg_GM_{ftypes[i]}_sub-{sub}_ses-{ses:02g}.1D')
#                 for bh in range(8):
#                     bh_responses[(8*(ses-1)+bh), :, i] = avg_gm[BH_LEN*bh:BH_LEN*(bh+1)]

#         bh_delta_responses = np.empty((8*(LAST_SES - 1), BH_LEN, len(ftypes)))
#         for i in range(len(ftypes)):
#             bh_delta_responses[:, :, i] = (bh_responses[:, :, i] -
#                                            bh_responses[:, :, 0])

#         for tps in range(BH_LEN):
#             plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
#             plt.title(f'BOLD_vs_FD, sub {sub}, tp {tps:02g}')
#             for i in range(1, len(ftypes)):
#                 # plt.plot(bh_delta_responses[:, tps, i], fd_responses[:, tps],
#                 #          'o', label=f'{ftypes[i]}', color=COLOURS[i])
#                 sns.regplot(x=bh_delta_responses[:, tps, i],
#                             y=fd_responses[:, tps], fit_reg=True,
#                             label=ftypes[i], color=COLOURS[i],
#                             robust=False, ci=None)

#             plt.legend()
#             plt.ylabel('FD')
#             plt.ylim(0, 0.7)
#             plt.xlabel('BOLD post - BOLD pre')
#             plt.xlim(-3000, 0)
#             plt.savefig(f'{sub}_BOLD_vs_FD_tps_{tps:02g}', dpi=SET_DPI)
#             plt.clf()
#             plt.close()


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
