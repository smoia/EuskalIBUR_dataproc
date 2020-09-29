#!/usr/bin/env python3

import sys
import os
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sgn
import scipy.interpolate as spint

from shutil import copyfile

SET_DPI = 100
FIGSIZE = (18, 10)


def decimate_data(filename, newfreq=40):
    data = np.genfromtxt(filename + '.tsv.gz')
    f = spint.interp1d(data[:, 0], data[:, ], axis=0, fill_value='extrapolate')
    data_tdec = np.arange(data[0, 0], data[-1, 0], 1/newfreq)
    data_dec = f(data_tdec)
    del data
    np.savetxt(filename + '_dec.tsv.gz', data_dec)
    return data_dec


def filter_signal(data_dec):
    ba = sgn.butter(7, 2/20, 'lowpass')
    data_filt = np.empty(data_dec.shape)
    data_filt[:, 0] = data_dec[:, 0]
    for ch in range(1, data_filt.shape[1]):
        data_filt[:, ch] = sgn.filtfilt(ba[0], ba[1], data_dec[:, ch])

    np.savetxt(filename + '_filt.tsv.gz', data_filt)
    return data_filt


def plot_all(data, filename, start=100, end=500, dpi=SET_DPI, size=FIGSIZE):
    ch_num = data.shape[1]  # get number of channels:
    fig, ax = plt.subplots(ch_num - 1, 1, figsize=size, sharex=True)
    time = data[:, 0]  # assume time is first channel
    fig.suptitle(os.path.basename(filename))
    for ch in range(1, ch_num):
        ax[ch - 1].plot(time[start:end], data[start:end, ch])
        ax[ch - 1].set_title(f' Channel {ch}')
        ax[ch - 1].grid()
    ax[ch - 1].set_xlabel('seconds')
    fig.savefig(f'{filename}.png', dpi=dpi, figsize=size, bbox_inches='tight')


wdir = sys.argv[1]
sub = sys.argv[2]

cwd = os.getcwd()

os.chdir(wdir)

for ses in range(1, 12):

    for task in ['motor', 'simon', 'pinel', 'rest_run-01',
                 'rest_run-02', 'rest_run-03', 'rest_run-04']:
        os.chdir(wdir)
        path = f'sub-{sub}/ses-{ses:02g}/func'
        filename = f'sub-{sub}_ses-{ses:02g}_task-{task}_physio'
        try:
            os.chdir(path)
            try:
                os.mkdir('../func_phys')
            except:
                print('Folder func_phys already exists')

            os.chdir('../func_phys')
            try:
                print(f'Copying file {filename}')
                copyfile(f'../func/{filename}.tsv.gz', f'./{filename}.tsv.gz')
            except:
                print('Cannot copy file')

            print(f'Decimating {filename}')

            data_dec = decimate_data(f'./{filename}')
            data_filt = filter_signal(data_dec)

            plot_all(data_filt, f'./{filename}_filt', 100, 500)
            plot_all(data_dec, f'./{filename}_dec', 100, 500)
            plt.close('all')
        except Exception:
            print(f'Something went awry. Check {sub} {ses:02g} {task}.')

os.chdir(cwd)
