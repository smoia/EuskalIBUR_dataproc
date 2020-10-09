#!/usr/bin/env python3

import sys
import os

import numpy as np

stats_dir = sys.argv[1]
step = int(sys.argv[2])
lag = int(sys.argv[3])
freq = int(sys.argv[4])
t_thr = float(sys.argv[5])
prefix = sys.argv[6]
out_dir = sys.argv[7]
atlas_nvx = sys.argv[8]
atlas_labels = int(sys.argv[9])
# atlas_labels=''

print(f'stats_dir=\'{stats_dir}\'')
print(f'step={step}')
print(f'lag={lag}')
print(f'freq={freq}')
print(f't_thr={t_thr}')
print(f'prefix=\'{prefix}\'')
print(f'out_dir=\'{out_dir}\'')
print(f'atlas_nvx=\'{atlas_nvx}\'')
print(f'atlas_labels=\'{atlas_labels}\'')

lag_samples = lag * freq
n_iter = lag_samples * 2

dout = dict.fromkeys(['cvr_idx', 'cvr_lag', 'cvr_masked_physio_only', 'tmap',
                     'cvr_masked'])

data = dict.fromkeys(range(0, n_iter, step))
for i in data.keys():
    # Read last three columns of stats files
    # This is possible only in optcom because first and last columns are the same
    data[i] = np.genfromtxt(os.path.join(stats_dir, f'stats_{i:04d}.1D'),
                            skip_header=9)[:, 2:]  # check axis

# Concatenate and find index of max value and max value
# - data_3d[:, :, 0] = coefficient (spc over volts)
# - data_3d[:, :, 1] = t stat
# - data_3d[:, :, 2] = R^2
data_3d = np.stack([data[i] for i in data.keys()], 0)

# Get idx of max R^2, then transform them into lags
dout['cvr_idx'] = data_3d[:, :, 2].argmax(axis=0)
dout['cvr_lag'] = (dout['cvr_idx'] * step - lag_samples) * (1/freq)

# Correct the lag by the median of the GM
if atlas_nvx:
    nvx = np.genfromtxt(f'{atlas_nvx}_vx.1D')[:, 0]
    tot_lag = []
    for n, i in enumerate(nvx):
        print(i)
        tot_lag = tot_lag + [dout['cvr_lag'][n]] * int(i)

    dout['cvr_lag'] = dout['cvr_lag'] - np.median(tot_lag)

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
    dout[k] = dout[k] * mask_l

dout['cvr_masked'] = dout['cvr_masked_physio_only'] * mask_t

# If this info is provided, also "complete" the atlas by inserting missing parcels.
if atlas_nvx and atlas_labels:
    sub_labels = np.genfromtxt(f'{atlas_nvx}_labels.1D')
    tot_labels = atlas_labels

    for n in range(tot_labels):
        if sub_labels[n] > n+1:
            sub_labels = np.insert(sub_labels, n, n+1)
            for k in dout.keys():
                dout[k] = np.insert(dout[k], n, 0)

# Check that all dout have the same size (why not?) and that it's > 20
# Then export
try:
    os.makedirs(out_dir)
except:
    print('Folder exists')

tot_size = 0
for k in dout.keys():
    if dout[k].size > tot_size:
        tot_size = dout[k].size
for k in dout.keys():
    if dout[k].size != tot_size:
        raise Exception('CVR maps don\'t have same size. Why?!?')
    else:
        if tot_size < 20:
            dout[k] = np.append(dout[k], [0]*(20-tot_size))

        np.savetxt(os.path.join(out_dir, f'{prefix}_{k}.1D'), dout[k],
                   fmt="%0.6f")
