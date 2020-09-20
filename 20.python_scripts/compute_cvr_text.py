#!/usr/bin/env python3

import sys
import os

import numpy as np

stats_dir = sys.argv[1]
step = sys.argv[2]
lag = sys.argv[3]
freq = sys.argv[4]
t_thr = sys.argv[5]
prefix = sys.argv[6]
out_dir = sys.argv[7]

lag_samples = lag * freq
n_iter = lag_samples * 2

dout = dict.fromkeys(['cvr_idx', 'cvr_lag', 'cvr_masked_physio_only', 'tmap',
                     'cvr_masked'])

data = dict.fromkeys(range(0, n_iter, step))
for i in data.keys():
    # Read last three columns of stats files
    # This is possible only in optcom because first and last columns are the same
    data[i] = np.genfromtxt(os.path.join(stats_dir, f'stats_{i}.1D'),
                            skip_header=9)[:, 2:]  # check axis

# Concatenate and find index of max value and max value
# - data_3d[:, :, 0] = coefficient (spc over volts)
# - data_3d[:, :, 1] = t stat
# - data_3d[:, :, 2] = R^2
data_3d = np.stack([data[i] for i in data.keys()], 0)

# Get idx of max R^2, then transform them into lags
dout['cvr_idx'] = data_3d[:, :, 2].argmax(axis=0)
dout['cvr_lag'] = (dout['cvr_idx'] * step - lag_samples) * (1/freq)

# #!# Correct the lag by the median of the GM - missing weighted average though.

data_squeeze = np.empty_like(data_3d[0])

for n, i in enumerate(dout['cvr_idx']):
    data_squeeze[n, :] = data_3d[i, n, :]

# Get cvr and tstats
dout['cvr_masked_physio_only'] = data_squeeze[:, 0] / 71.2 * 100
dout['tmap'] = data_squeeze[:, 1]

# Create mask based on lag and on tstats and express it as integers (0 or 1)
# #!# Check boolean operands
mask_l = (dout['cvr_idx'] >= 5) * (dout['cvr_idx'] <= 705) * 1
mask_t = (dout['tmap'] >= t_thr) * 1

# mask maps
for k in ['cvr_lag', 'cvr_masked_physio_only', 'tmap']:
    dout[k] = dout[k]*mask_l

dout['cvr_masked'] = dout['cvr_masked_physio_only']*mask_t

os.makedirs(out_dir)
# export everything
for k in dout.keys():
    np.savetxt(os.path.join(out_dir, f'{prefix}_{k}.1D'), dout[k], fmt="%0.6f")
