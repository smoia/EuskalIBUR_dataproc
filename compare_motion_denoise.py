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
        for 
        for ftype in ['echo-2','optcom','meica']:
            colname = f'{sub}_{ses:02d}_{ftype}'            
            sub_table[f'{sub}_']




os.chdir(cwd)