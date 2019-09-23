#!/usr/bin/env python3

import os
import matplotlib
import pandas

from numpy import genfromtxt

cwd = os.getcwd()

os.chdir('/media')
# os.chdir('/media/nemo/ANVILData/gdrive/PJMASK')

sub_list = ['007', '003', '002']

# #!# PSEUDOCODE
sub_table = pd. genemptydf

for sub in sub_list:
    for ses in range(1, 10):
        for mottype in ['dvars_pre', 'fd', 'dvars']:
            if mottype == 'dvars':
                for ftype in ['echo-2', 'optcom', 'meica']:
                    colname = f'{sub}_{ses:02d}_{mottype}_{ftype}'
                    filename = f'{mottype}_{ftype}_sub-{sub}_ses-{ses}.1D'
                    sub_table[colname] = np.genfromtxt(filename)

            else:
                colname = f'{sub}_{ses:02d}_{mottype}'
                filename = f'{mottype}_sub-{sub}_ses-{ses}.1D'
                sub_table[colname] = np.genfromtxt(filename)



os.chdir(cwd)