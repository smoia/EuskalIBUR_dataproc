#!/usr/bin/env python3

import sys
import os
import biopac_preproc as bio
import matplotlib.pyplot as plt

from shutil import copyfile

wdir = sys.argv[1]
SET_DPI = 100

cwd = os.getcwd()

os.chdir(wdir)

for sub in range(1, 11):
    for ses in range(1, 12):
        if ses >= 7:
            ch = 5
        else:
            ch = 4

        for task in ['breathhold', 'motor', 'simon', 'pinel', 'rest']:
            os.chdir(wdir)
            path = f'sub-{sub:03g}/ses-{ses:02g}/func'
            filename = f'sub-{sub:03g}_ses-{ses:02g}_task-{task}_physio'
            try:
                os.chdir(path)
                if not os.path.exists('../func_phys'):
                    os.mkdir('../func_phys')

                os.chdir('../func_phys')
                print(f'Copying file {filename}')
                copyfile(f'../func/{filename}.tsv.gz', f'./{filename}.tsv.gz')
                print(f'Decimating {filename}')
                co, pidx = bio.partone(filename, ch)

                plt.figure(figsize=(18, 10), dpi=SET_DPI)
                plt.plot(co)
                plt.title(f'sub {sub:03g} ses {ses:02g}')
                plt.savefig(f'{filename}.png', dpi=SET_DPI)
                plt.close('all')
            except Exception:
                pass

os.chdir(cwd)
