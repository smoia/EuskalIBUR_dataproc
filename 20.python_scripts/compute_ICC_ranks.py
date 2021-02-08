#!/usr/bin/env python3

import argparse
import os
import sys

import nibabel as nib
import numpy as np


LAST_SES = 10  # 10

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#1f77b4ff', '#2ca02cff', '#d62728ff', '#ff7f0eff', '#ff33ccff']

ATLAS_DICT = {'Mutsaerts2015': 'Mutsaerts (vascular)',
              'Mutsaerts2015-hem': 'Mutsaerts (vascular)',
              'Mutsaerts2015-sub': 'Mutsaerts (vascular + subcortical)',
              'Subcortical': 'Subcortical + cerebellum',
              'Yeo2011-7': 'Yeo (functional)',
              'Schaefer2018-100': 'Schaefer (functional)'}

#########
# Utils #
#########
def _get_parser():
    parser = argparse.ArgumentParser()

    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    parser.add_argument('-af', '--atlasfile',
                        dest='atlas_files',
                        nargs='*',
                        help='Use this atlas - fullpath and extension. Multiple allowed.',
                        default='')
    parser.add_argument('-an', '--atlasname',
                        dest='atlas_names',
                        nargs='*',
                        help='Use this name for atlas. Has to be same number as specified with -af.',
                        default='')
    return parser


def load_nifti_get_mask(fname, dim=4):
    if fname.endswith('.nii.gz'):
        fname = fname[:-7]
    img = nib.load(f'{fname}.nii.gz')
    data = img.get_fdata()
    if len(data.shape) > dim:
        for ax in range(dim, len(data.shape)):
            data = np.delete(data, np.s_[1:], axis=ax)
    data = np.squeeze(data)
    if len(data.shape) >= 4:
        mask = np.squeeze(np.any(data, axis=-1))
    else:
        mask = (data < 0) + (data > 0)
    return data, mask, img


def compute_rank(data):
    reord = np.argsort(data, axis=-1)
    rank = reord.argmax(axis=-1)
    return rank/(data.shape[-1]-1)*100


def export_nifti(data, img, fname):
    out_img = nib.Nifti1Image(data, img.affine, img.header)
    if fname.endswith('.nii.gz'):
        fname = fname[:-7]
    out_img.to_filename(f'{fname}.nii.gz')


#############
# Workflows #
#############


def compute_metric(data, atlases, mask, metric='avg'):
    # metric can be avg or iqr
    # Compute averages and store them in pandas dataframes
    # Then compute rank and store them in other pd.DataFrame

    print(f'Compute metrics: {metric}')
    comp = dict.fromkeys(atlases.keys())
    for atlas in atlases.keys():
        print(f'Working on {atlas}')
        unique = np.unique(atlases[atlas])
        unique = unique[unique > 0]
        print(f'Labels: {unique}, len: {len(unique)}, surr: {data.shape[-1]}')
        # Initialise dataframe and dictionary for series
        parcels = np.empty([len(unique), data.shape[-1]])

        # Compute averages
        for m, label in enumerate(unique):
            print(f'Metric: {metric}, Label: {label} ({m})')
            if metric == 'avg':
                parcels[m, :] = data[atlases[atlas] == label].mean(axis=0)
            elif metric == 'iqr':
                dist = data[atlases[atlas] == label]
                parcels[m, :] = (np.percentile(dist, 75, axis=0) -
                                 np.percentile(dist, 25, axis=0))

        rank = compute_rank(parcels)
        if metric == 'iqr':
            print('Invert iqr rank')
            rank = 100 - rank

        comp[atlas] = atlases[atlas].copy()

        print(f'Recompose atlas {atlas}')
        for m, label in enumerate(unique):
            comp[atlas][atlases[atlas] == label] = rank[m]

    return comp


########
# MAIN #
########
if __name__ == '__main__':
    args = _get_parser().parse_args(sys.argv[1:])

    if not args.atlas_files:
        atlas_files = ['/scripts/90.template/ATTbasedFlowTerritories_resamp_2.5mm_hem.nii.gz',
                       '/scripts/90.template/subcortical_cerebellum_2.5mm.nii.gz',
                       '/scripts/90.template/Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2.5mm.nii.gz']
        atlas_names = ['Mutsaerts2015-hem',
                       'Subcortical',
                       'Schaefer2018-100']

    elif len(args.atlas_files) != len(args.atlas_names):
        raise Exception(f'Got {len(args.atlas_names)} names for {len(args.atlas_files)} atlas files!')
    else:
        atlas_files = args.atlas_files
        atlas_names = args.atlas_names

    os.chdir(args.wdr)
    for fmap in ['cvr', 'lag']:
        print(f'Loading {fmap}')
        data, mask, img = load_nifti_get_mask(f'ICC_{fmap}')

        print(f'Reordering {fmap} and finding ranks')
        rank = compute_rank(data)

        print(f'Exporting {fmap}')
        export_nifti(rank*mask, img, f'ICC_{fmap}_rank')

        print('Read atlases')
        atlases = dict.fromkeys(atlas_names)

        for n, atlas in enumerate(atlas_names):
            atlases[atlas], _, _ = load_nifti_get_mask(f'{atlas_files[n]}')
            atlases[atlas] = atlases[atlas]*mask

        comp = dict.fromkeys(['avg', 'iqr'])
        for metric in ['avg', 'iqr']:
            comp[metric] = compute_metric(data, atlases, mask, metric)
            for atlas in atlas_names:
                print(f'Export {metric} for {atlas}')
                export_nifti(comp[metric][atlas], img, f'ICC_{fmap}_{atlas}_{metric}_rank')
