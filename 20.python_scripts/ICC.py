#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt


SET_DPI = 100
FIGSIZE = (18, 10)


def compute_MS(table):
    """
    Computes MSs necessary for ICC
    """
    n, k = table.shape
    SS_tot = table.var(ddof=1) * (n * k - 1)
    MS_r = np.var(table.mean(axis=1), ddof=1) * k
    MS_w = np.sum(np.var(table, axis=1, ddof=1)) / n
    MS_c = np.var(np.mean(table, axis=0), ddof=1) * n
    MS_e = (SS_tot - MS_r * (n - 1) - MS_c * (k - 1)) / ((n - 1) * (k - 1))
    return n, k, MS_r, MS_w, MS_c, MS_e

def compute_ICC_1(table):
    """
    Computes standard ICC(1,1)
    """
    n, k, MS_r, MS_w, MS_c, MS_e = compute_MS(table)
    ICC_1 = (MS_r - MS_w) / (MS_r + (k - 1) * MS_w)

    return ICC_1


def compute_ICC_C_1(table):
    """
    Computes standard ICC(2,1)
    """
    n, k, MS_r, MS_w, MS_c, MS_e = compute_MS(table)
    ICC_C_1 = (MS_r - MS_e) / (MS_r + (k - 1) * MS_e)

    return ICC_C_1

def compute_ICC_A_1(table):
    """
    Computes standard ICC(3,1)
    """
    n, k, MS_r, MS_w, MS_c, MS_e = compute_MS(table)
    ICC_A_1 = (MS_r - MS_e) / (MS_r + (k - 1) * MS_e
                               + k * (MS_c - MS_e) / n)

    return ICC_A_1

def compute_spatial_ICC_1(val, sub_list=['002', '003', '007'], k=9, spatial_ICC=True):
    """
    Computes standard ICC(1,1) for the average of a table,
    and a spatial ICC(1,1) for each subject
    """
    tables = []

    for sub in sub_list:
        tables.append(np.genfromtxt(f'sub-{sub}_{val}.csv',
                                    delimiter=',', skip_header=1))

    n_subs = len(sub_list)
    meanvals = np.zeros((n_subs, k))
    if spatial_ICC:
        s_ICC = []
    else:
        s_ICC = None

    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    legtext = []

    for sub in range(0, n_subs):
        meanvals[sub, :] = tables[sub].mean(0)
        plt.plot(meanvals[sub, :])

        if spatial_ICC:
            sub_s_ICC = compute_ICC_1(tables[sub])
            s_ICC.append(sub_s_ICC)
        else:
            sub_s_ICC = ''

        legtext.append(f'{sub_list[sub]} {val} ICC: {sub_s_ICC}')

    legtext.append('')
    plt.legend(tuple(legtext))
    ICC_1 = compute_ICC_1(meanvals)
    plt.title(f'ICC = {ICC_1}')

    plt.savefig(val + '_ICC.png', dpi=SET_DPI)
    plt.close()

    return ICC_1, s_ICC

