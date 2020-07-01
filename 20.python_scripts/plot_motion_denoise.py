#!/usr/bin/env python3
import os
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

SET_DPI = 100
FIGSIZE = (9, 5)
BH_LEN = 39

FTYPE_LIST = ['pre', 'echo-2', 'optcom', 'meica-aggr', 'meica-orth',
              'meica-cons', 'all-orth']
COLOURS = ['#d62728ff', '#07ad95ff', '#ff7f0eff', '#2ca02cff', '#ff33ccff',
           '#1f77b4ff', '#663300ff']  # , '#003300ff', '#000066ff', '#b3b300ff', '#000000ff']
FTYPE_DICT = {'pre': 'pre', 'echo-2': 'echo-2', 'optcom': 'optcom',
              'meica-aggr': 'meica-agg', 'meica-orth': 'meica-ort',
              'meica-cons': 'meica-con'}
              # , 'all-orth': 'all-ort'}
              # 'meica-aggr-twosteps': 'me-agg-2s',
              # 'meica-orth-twosteps': 'me-ort-2s',
              # 'all-orth-twosteps': 'allort-2s',
              # 'meica-cons-twosteps': 'me-con-2s'}

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
        plt.xlim(-.01, 0.85)
        plot_ylabel = 'DVARS'
        plt.ylabel(plot_ylabel)
        plt.ylim(28, 450)
        plt.tight_layout()
        fig_name = f'/data/plots/{sub}_DVARS_vs_FD.png'
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
    plt.xlim(0, 0.85)
    plot_ylabel = 'DVARS'
    plt.ylabel(plot_ylabel)
    plt.ylim(60, 600)
    plt.tight_layout()
    fig_name = '/data/plots/allsubs_DVARS_vs_FD.png'
    plt.savefig(fig_name, dpi=SET_DPI)
    plt.clf()
    plt.close()


# 02. Helping function for the next one
def read_and_shape(filename, ftypes=FTYPE_LIST):
    # responses is ftype*ses*trials*BH_LEN
    responses = np.empty((len(ftypes), (LAST_SES - 1), 8, BH_LEN))
    for n, ftype in enumerate(ftypes):
        for ses in range(1, LAST_SES):
            data = np.genfromtxt(filename.format(ftype=ftype, ses=f'{ses:02g}'))
            for bh in range(8):
                responses[n, ses-1, bh, :] = data[12+BH_LEN*bh:12+BH_LEN*(bh+1)]

    return responses.reshape((len(ftypes), (LAST_SES - 1)*8, BH_LEN), order='C')


# 02. Make timeseries plots
def plot_timeseries_and_BOLD_vs_FD(sub, ftypes=FTYPE_LIST):
    # Read and prepare files
    fd_response = read_and_shape(f'sub-{sub}/{{ftype}}_sub-{sub}_'
                                 f'ses-{{ses}}.1D', ['fd', ])
    dvars_responses = read_and_shape(f'sub-{sub}/dvars_{{ftype}}_sub-'
                                     f'{sub}_ses-{{ses}}.1D')
    bold_responses = read_and_shape(f'sub-{sub}/avg_GM_SPC_{{ftype}}_sub-'
                                    f'{sub}_ses-{{ses}}.1D')
    # Compute averages
    avg_d = dvars_responses.mean(axis=1)
    std_d = dvars_responses.std(axis=1)
    avg_b = bold_responses.mean(axis=1)
    std_b = bold_responses.std(axis=1)
    # Compute plot data width for bold as max between distance of each ftype
    delta_y = ((avg_b.max(axis=1)-(avg_b.min(axis=1)).max()
               + 0.004)

    # Compute trial distance from average
    dist_avg = np.empty(bold_responses.shape[:2])
    for n in range(bold_responses.shape[1]):
        dist_avg[:, n] = np.abs(avg_b -
                                np.squeeze(bold_responses[:, :(n+1),
                                           :].mean(axis=1))).mean(axis=1)

    # Create response plot
    bh_plot = plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    bh_plot.suptitle(f'BreathHold response, subject {sub}')

    gs = bh_plot.add_gridspec(nrows=(len(ftypes)+1), ncols=3)

    # Add FD on both columns
    for col in range(2):
        bh_subplot = bh_plot.add_subplot(gs[len(ftypes), col])

        bh_subplot.plot(TIME, fd_response.mean(axis=(0, 1)))
        bh_subplot.grid(True, axis='x', markevery='5')

        bh_subplot.set_ylabel('FD')
        bh_subplot.set_xlabel('TPs')

    for i, ftype in enumerate(ftypes):
        # Add DVARS plots in first column
        bh_subplot = bh_plot.add_subplot(gs[i, 0])

        bh_subplot.plot(TIME, avg_d[i, :],
                        label=FTYPE_DICT[ftype], color=COLOURS[i])
        bh_subplot.fill_between(TIME, avg_d[i, :] - std_d[i, :],
                                avg_d[i, :] + std_d[i, :],
                                color=COLOURS[i], alpha=0.2)

        bh_subplot.set_ylim(0, (avg_d + std_d).max()*11/10)
        bh_subplot.set_ylabel('DVARS')
        bh_subplot.axes.get_xaxis().set_ticks([])

        # Add BOLD plots in second column
        bh_subplot = bh_plot.add_subplot(gs[i, 1])
        bh_subplot.plot(TIME, avg_b[i, :],
                        label=FTYPE_DICT[ftype], color=COLOURS[i])
        bh_subplot.fill_between(TIME, avg_b[i, :] - std_b[i, :],
                                avg_b[i, :] + std_b[i, :],
                                color=COLOURS[i], alpha=0.2)

        min_y = (avg_b - std_b)[i, :].min() - 0.002
        bh_subplot.set_ylim(min_y, min_y + delta_y)
        bh_subplot.set_ylabel('% BOLD')
        bh_subplot.axes.get_xaxis().set_ticks([])

        # Add distance to average plot
        bh_subplot = bh_plot.add_subplot(gs[i, 2])
        bh_subplot.plot(dist_avg[i, :],
                        label=FTYPE_DICT[ftype], color=COLOURS[i])

        bh_subplot.set_ylim(0, dist_avg.max())
        bh_subplot.set_ylabel('avg dist')
        bh_subplot.axes.get_xaxis().set_ticks([])
        bh_subplot.legend(loc=1, prop={'size': 8})

    # bh_plot.savefig(f'/data/plots/{sub}_BOLD_time.png', dpi=SET_DPI)

    # plt.close('all')


if __name__ == '__main__':
    cwd = os.getcwd()

    os.chdir('/data/ME_Denoising')

    data = pd.read_csv('sub_table.csv')

    plot_DVARS_vs_FD(data)
    for sub in SUB_LIST:
        plot_timeseries_and_BOLD_vs_FD(sub)
    # os.makedirs('tps')
    # os.chdir('tps')
    # plot_tps_BOLD_vs_FD()

    os.chdir(cwd)
