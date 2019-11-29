#!/usr/bin/env python3

import os
import sys

from json import load

infolder = sys.argv[1]

cwd = os.getcwd()

os.chdir(infolder)

with open('ica_decomposition.json', 'r') as f:
    comp = load(f)

del(comp['Method'])

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

os.chdir(cwd)
