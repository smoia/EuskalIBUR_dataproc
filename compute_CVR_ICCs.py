#!/usr/bin/env python3

import os
import ICC
import pandas as pd
import numpy as np

ftype = ['echo-2', 'optcom', 'meica', 'vessels', 'networks']
val = ['cvrvals', 'lagvals']

cwd = os.getcwd()

os.chdir('/home/nemo/Documenti/Archive/Data/gdrive/PJMASK/CVR/00.Reliability')
# os.chdir('/data/CVR/00.Reliability')

for j in val:
    iccs = np.empty((4, 5))
    for i in range(len(ftype)):
        print(f'\n\n {ftype[i]} {j}: ')
        iccs[0, i], iccs[1:, i] = ICC.compute_ICC_1(f'{ftype[i]}_{j}')

    df = pd.DataFrame(iccs, columns=ftype)
    df.to_csv(f'ICC_table_{j}')


os.chdir(cwd)