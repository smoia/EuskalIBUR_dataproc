import numpy as np


def compute_spatial_ICC_1(table):
    """
    Computes standard ICC(1,1)
    """
    n_vxs, n_sess = table.shape

    MS_r = np.var(table.mean(0), ddof=1) * n_sess
    MS_w = np.sum(table.var(0, ddof=1)) / n_vxs

    spatial_ICC_1 = (MS_r - MS_w) / (MS_r + (n_sess - 1) * MS_w)

    return spatial_ICC_1


def compute_ICC_1(val, sub_list=['002', '003', '007'], n_sess=9, spatial_ICC=True):
    """
    Computes standard ICC(1,1) for the average of a table,
    and a spatial ICC(1,1) for each subject
    """
    tables = []

    for sub in sub_list:
        tables.append(np.genfromtxt('sub-' + sub + '_' + val + '.csv',
                                    delimiter=',', skip_header=1))

    n_subs = len(sub_list)
    meanvals = np.zeros((n_subs, n_sess))
    if spatial_ICC:
        s_ICC = []
    else:
        s_ICC = None

    for sub in range(0, n_subs):
        meanvals[sub, :] = tables[sub].mean(0)
        if spatial_ICC:
            s_ICC.append(compute_spatial_ICC_1(tables[sub]))

    ICC_1 = compute_spatial_ICC_1(meanvals)

    # MS_r = np.var(meanvals.mean(0), ddof=1) * n_sess
    # MS_w = np.sum(meanvals.var(0, ddof=1)) / n_subs

    # ICC_1 = (MS_r - MS_w) / (MS_r + (n_sess - 1) * MS_w)

    return ICC_1, s_ICC

