from __future__ import division

import os
import argparse

import numpy as np
import peakutils as pk

import matplotlib.pyplot as plt
import scipy.signal as sgn
import scipy.interpolate as spint
import scipy.stats as sct

# matplotlib.use("TkAgg")
# matplotlib.interactive(True)
reject_list = np.array([])


def _get_parser():
    """
    Parses command line inputs for this function

    Returns
    -------
    parser.parse_args() : argparse dict

    """
    parser = argparse.ArgumentParser()
    # Argument parser follow template provided by RalphyZ, also used by tedana.
    # https://stackoverflow.com/a/43456577
    optional = parser._action_groups.pop()
    required = parser.add_argument_group('required arguments')
    required.add_argument('-f', '--file',
                          dest='filename',
                          type=str,
                          help=('Name of the file to input, '
                                'possibly with fullpath'),
                          required=True)
    required.add_argument('-gm', '--gmfile',
                          dest='GM_name',
                          type=str,
                          help=('Name of the average GM, '
                                'possibly with fullpath'),
                          required=True)
    optional.add_argument('-tr', '--tr',
                          dest='tr',
                          type=float,
                          help='TR of the GM data',
                          default=1.5)
    optional.add_argument('-nf', '--newfreq',
                          dest='newfreq',
                          type=float,
                          help='Desired frequency of the biopac files',
                          default=40)
    optional.add_argument('-itr', '--ign_tr',
                          dest='ign_tr',
                          type=float,
                          help='Number of timepoints to discard',
                          default=400)
    parser._action_groups.append(optional)
    return parser


def create_hrf(newfreq=40):
    # Create HRF
    RT = 1/newfreq
    fMRI_T = 16
    p = [6, 16, 1, 1, 6, 0, 32]

    # Modelled hemodynamic response function - {mixture of Gammas}
    dt = RT / fMRI_T
    u = np.arange(0, p[6]/dt+1, 1) - p[5]/dt
    a1 = p[0] / p[2]
    b1 = 1 / p[3]
    a2 = p[1] / p[3]
    b2 = 1 / p[3]
    hrf = (sct.gamma.pdf(u*dt, a1, scale=b1) - sct.gamma.pdf(u*dt, a2, scale=b2)/p[4])/dt
    time_axis = np.arange(0, int(p[6]/RT+1), 1) * fMRI_T
    hrf = hrf[time_axis]
    min_hrf = 1e-9*min(hrf[hrf > 10*np.finfo(float).eps])

    if min_hrf < 10*np.finfo(float).eps:
        min_hrf = 10*np.finfo(float).eps

    hrf[hrf == 0] = min_hrf
    hrf = hrf/max(hrf)

    plt.figure()
    plt.plot(hrf)

    return hrf


def decimate_data(filename, newfreq=40):
    data = np.genfromtxt(filename + '.tsv.gz')
    idz = (data[:, 0]>=0).argmax()
    data = data[idz:, ]
    f = spint.interp1d(data[:, 0], data[:, ], axis=0, fill_value='extrapolate')
    data_tdec = np.arange(0, data[-1, 0], 1/newfreq)
    data_dec = f(data_tdec)

    del data, idz

    np.savetxt(filename + '_dec.tsv.gz', data_dec)

    return data_dec


def filter_signal(data_dec, channel=4):
    ba = sgn.butter(7, 2/20, 'lowpass')
    resp_filt = sgn.filtfilt(ba[0], ba[1], data_dec[:, channel])
    plt.figure()
    plt.plot(resp_filt)

    return resp_filt


def get_peaks(resp_filt):
    # Finding peaks
    co = sgn.detrend(resp_filt, type='linear', bp=0)
    #!#
    pidx = pk.peak.indexes(co, thres=0.5, min_dist=120).tolist()
    plt.figure()
    plt.plot(co)
    plt.plot(co, 'm*', markevery=pidx)
    # pidx = np.delete(pidx,[56])
    return co, pidx


def get_petco2(co, pidx, hrf, filename, ign_tr=400, newfreq=40):
    # Extract PETco2
    coln = len(co)
    nx = np.linspace(0, coln, coln)
    f = spint.interp1d(pidx, co[pidx], fill_value='extrapolate')
    co_int = f(nx)
    co_int = co_int - co_int.mean()
    plt.figure()
    plt.plot(co_int)
    np.savetxt(filename + '_co_int.1D',co_int,fmt='%.18f')

    co_conv = np.convolve(co_int, hrf)
    # also ignore last 2 seconds for shape adjustement
    coln = coln - 2*newfreq
    co_conv = co_conv[ign_tr:coln]
    plt.figure()
    plt.plot(co_conv, '-', co_int*100, '-')

    np.savetxt(filename + '_co_conv.1D', co_conv, fmt='%.18f')

    return co_conv


def get_regr(GM_name, co_conv, tr=1.5, newfreq=40, ign_tr=400):
    GM = np.genfromtxt(GM_name + '.1D')

    # Interpolate GMOC at 40 Hz
    atps = len(GM)
    f = spint.interp1d(np.linspace(0, atps*tr, atps), GM, fill_value='extrapolate')
    nGMx = np.arange(0, atps*tr, 1/newfreq)
    GM_40 = f(nGMx)
    GMln_40 = len(nGMx)
    # Getting rid of first and last breathhold (and part after)
    BH_len = 2319
    GM_40_cut = GM_40[BH_len:16241]
    GM_40_len = len(GM_40_cut)

    # Detrend GM # Molly hinted it might be better not to
    # GM_dt = sgn.detrend(GM_40_cut, type='linear', bp=0)
    GM_dt = GM_40_cut
    plt.figure()
    plt.plot(GM_dt)

    gmnrep = len(co_conv) - GMln_40 + BH_len
    GM_r = np.zeros((gmnrep - BH_len))
    for k in range(BH_len, gmnrep):
        GM_r[k-BH_len] = np.corrcoef(GM_dt, co_conv[0+k:GM_40_len+k].T)[1, 0]

    tax = np.arange(0, (gmnrep-BH_len)/newfreq, 1/newfreq)
    set_dpi = 100
    plt.figure(figsize=(18,10), dpi=set_dpi)
    plt.plot(tax, GM_r)
    plt.title('optshift')
    plt.savefig(GM_name + '_optshift.png', dpi=set_dpi)
    plt.close()
    optshift = int(GM_r.argmax(0))
    co_shift = co_conv[optshift:optshift+GMln_40]

    set_dpi = 100
    plt.figure(figsize=(18,10), dpi=set_dpi)
    plt.plot(sct.zscore(GM_40))
    plt.plot(sct.zscore(co_shift))
    plt.title('GM and shift')
    plt.savefig(GM_name + '_co_regr.png', dpi=set_dpi)
    plt.close()


    # Interpolate CO_SHIFT at TR and exporting it.
    f = spint.interp1d(np.linspace(0, GMln_40, GMln_40), co_shift, fill_value='extrapolate')
    trx = np.linspace(0, GMln_40, round(GMln_40/newfreq/tr))
    co_tr = f(trx)
    plt.figure()
    plt.plot(co_tr)
    co_dm = co_tr - co_tr.mean()
    textname = GM_name + '_co_regr.1D'
    np.savetxt(textname, co_dm, fmt='%.18f')

    # Prepare number of repetitions
    rnrep = int(newfreq*tr*10)
    #!# For some arcane reason I don't fully understand yet, add ign_tr to optshift
    # optshift=optshift+ign_tr
    # Extending co_conv on the right with just a bunch of zeroes
    # Thought about doing a sort of moving average, doesn't really make sense.
    co_conv = np.pad(co_conv,(0,optshift+rnrep),'mean')

    if optshift < rnrep:
        extrapad = rnrep-optshift
        co_conv = np.pad(co_conv,(extrapad,0),'mean')
    else:
        extrapad = 0

    repmin = -rnrep

    # Possibly useless but it's on the side that is not a problem.
    if optshift+rnrep+GMln_40 > len(co_conv):
        repmax = len(co_conv)-optshift-GMln_40
    else:
        repmax = rnrep

    # Save regressors
    GM_dir = GM_name + '_regr_shift'
    if not os.path.exists('regr'):
        os.makedirs('regr')

    for k in range(repmin, repmax+1):
        co_shift = co_conv[optshift+extrapad+k:optshift+extrapad+GMln_40+k]
        f = spint.interp1d(np.linspace(0, GMln_40, GMln_40), co_shift, fill_value='extrapolate')
        co_tr = f(trx)
        co_dm = co_tr - co_tr.mean()
        txtname = GM_dir + '/shift_' + '%04d' % (k + rnrep) + '.1D'
        np.savetxt(txtname, co_dm, fmt='%.18f')


def onpick_manualedit(event):
    thisline = event.artist
    xdata = thisline.get_xdata()
    ind = event.ind
    xdataind = xdata[ind]
    print('onpick xind:',xdataind)

    global reject_list
    reject_list = np.append(reject_list,xdataind)


def partone(filename, channel=4, tr=1.5, newfreq=40):
    data_dec = decimate_data(filename, newfreq)
    # data_dec = np.genfromtxt(filename + '_dec.tsv.gz')
    resp_filt = filter_signal(data_dec, channel)
    [co, pidx] = get_peaks(resp_filt)
    # export original peaks
    textname = filename + '_autopeaks.1D'
    np.savetxt(textname, pidx)
    textname = filename + '_co_orig.1D'
    np.savetxt(textname, co)
    return co, pidx


def manualchange(filename, pidx, reject_list):
    # masking pidx and saving manual selection
    pidx = np.array(pidx)
    pmask = np.in1d(pidx, reject_list)
    npidx = list(pidx[~pmask])
    textname = filename + '_manualpeaks.1D'
    np.savetxt(textname, npidx)
    return npidx


# def parttwo(filename):
def parttwo(co, pidx, filename, GM_name, tr=1.5, newfreq=40, ign_tr=400):
    hrf = create_hrf(newfreq)
    co_conv = get_petco2(co, pidx, hrf, filename, ign_tr, newfreq)
    if not os.path.exists('regr'):
        os.makedirs('regr')

    # co_conv = np.genfromtxt('regr/' + filename + '_co_conv.1D')
    #!#
    get_regr(GM_name, co_conv, tr, newfreq, ign_tr)


def _main(argv=None):
    options = _get_parser().parse_args(argv)
    # Reading first data
    # newfreq = 40
    # nrep = 2000
    # tr = 1.5
    # tps=340
    filename = options.filename
    GM_name = options.GM_name
    newfreq = options.newfreq
    tr = options.tr
    channel = options.channel
    ign_tr = options.ign_tr

    co, pidx = partone(filename, channel, tr, newfreq)
    parttwo(co, pidx, filename, GM_name, tr, newfreq, ign_tr)


if __name__ == '__main__':
    _main()