#!/usr/bin/env python3

import os
import ICC
import pandas as pd
import numpy as np

FTYPE_LIST = ['echo-2', 'optcom', 'meica', 'vessels']  #, 'networks']
VALUE_LIST = ['cvrvals', 'lagvals']

cwd = os.getcwd()

os.chdir('/bcbl/home/public/PJMASK_2/preproc/CVR/00.Reliability')
# os.chdir('/home/nemo/Documenti/Archive/Data/gdrive/PJMASK/CVR/00.Reliability')
# os.chdir('/data/CVR/00.Reliability')

for val in VALUE_LIST:
    iccs = np.empty((4, 5))
    for i in range(len(FTYPE_LIST)):
        print(f'\n\n {FTYPE_LIST[i]} {val}: ')
        fname = f'{FTYPE_LIST}_{val}_alltypes_mask'
        iccs[0, i], iccs[1:, i] = ICC.compute_spatial_ICC_1(f'{FTYPE_LIST[i]}_{val}')

    df = pd.DataFrame(iccs, columns=FTYPE_LIST)
    df.to_csv(f'ICC_table_{val}')

os.chdir(cwd)