#!/usr/bin/env python3

import os
import sys
import pandas as pd

from json import load

infolder = sys.argv[1]

cwd = os.getcwd()

os.chdir(infolder)

with open('ica_decomposition.json', 'r') as f:
    comp = load(f)

del(comp['Method'])

# Prepare list of components for projections
acc = ''
rej = ''
ign = ''

for n, ic in enumerate(comp):
    if comp[ic]['classification'] == 'rejected':
        print(f'{n} rej')
        rej += f'{n},'

    if comp[ic]['classification'] == 'accepted':
        print(f'{n} acc')
        acc += f'{n},'

    if comp[ic]['classification'] == 'ignored':
        print(f'{n}')
        ign += f'{n},'

with open('rejected_list.1D', 'w+') as f:
    f.write(rej[:-1])

with open('accepted_list.1D', 'w+') as f:
    f.write(acc[:-1])

with open('ignored_list.1D', 'w+') as f:
    f.write(ign[:-1])

# Prepare same list for 4D denoise
comp_data = []

for ic in comp:
    comp_data.append([comp[ic]['normalized variance explained'],
                     comp[ic]['classification']])

dt = pd.DataFrame(comp_data, columns=['var', 'class'])

dt = dt.sort_values('var', ascending=False)
dt = dt.reset_index(drop=False)

acc = ''
rej = ''
ign = ''

for n in range(len(dt)):
    if dt['class'][n] == 'rejected':
        print(f'{n} rej')
        rej += f'{n},'

    if dt['class'][n] == 'accepted':
        print(f'{n} acc')
        acc += f'{n},'

    if dt['class'][n] == 'ignored':
        print(f'{n}')
        ign += f'{n},'

with open('rejected_list_by_variance.1D', 'w+') as f:
    f.write(rej[:-1])

with open('accepted_list_by_variance.1D', 'w+') as f:
    f.write(acc[:-1])

with open('ignored_list_by_variance.1D', 'w+') as f:
    f.write(ign[:-1])

idx = dt.drop(['var', 'class'], axis=1)
idx.to_csv('idx_map.csv', header=False)

os.chdir(cwd)
