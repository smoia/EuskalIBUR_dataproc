#!/usr/bin/env python3

import os
import pandas as pd

from numpy import savetxt

cwd = os.getcwd()

os.chdir('/media')

sub_list = ['007', '003', '002']

xl = pd.ExcelFile('MEICA_Stefano.xlsx')

for sub in sub_list:
    sub_table = pd.read_excel(xl, sub)
    sub_table.index += 1

    for ses in range(1, 10):
        col = f'ses-{ses:02d}'
        rej = sub_table.index[sub_table[col] == 'R'].tolist()
        vas = rej + sub_table.index[sub_table[col] == 'V'].tolist()
        net = vas + sub_table.index[sub_table[col] == 'N'].tolist()

        savetxt(f'sub-{sub}_{col}_rejected.1D', rej, fmt='%d')
        savetxt(f'sub-{sub}_{col}_vascular.1D', vas, fmt='%d')
        savetxt(f'sub-{sub}_{col}_networks.1D', net, fmt='%d')
