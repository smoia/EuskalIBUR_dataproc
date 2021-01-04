#!/usr/bin/env python3

import argparse
import os
import sys

import nibabel as nib
import numpy as np

SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

LAST_SES += 1


def _get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-ftype', '--ftype',
                        dest='ftype',
                        type=str,
                        help='The type of map you want to average',
                        required=True)
    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    return parser


########
# MAIN #
########
if __name__ == '__main__':
    args = _get_parser().parse_args(sys.argv[1:])
    os.chdir(args.wdr)

    # Subjects segmentations
    data = dict.fromkeys(SUB_LIST)
    mask = dict.fromkeys(SUB_LIST)

    # Read segmentation of all subjects
    for sub in SUB_LIST:
        data[sub] = {}
        for ses in range(1, LAST_SES):
            # Load data & stack in d4 (axis 3)
            img_data = nib.load(f'std_optcom_{args.ftype}_masked_{sub}_{ses:02g}.nii.gz')
            img_mask = nib.load(f'masks/std_optcom_mask_{sub}_{ses:02g}.nii.gz')
            if ses == 1:
                data[sub]['stack'] = img_data.get_data()
                mask[sub] = img_mask.get_data()
            else:
                data[sub]['stack'] = np.stack([data[sub]['stack'],
                                              img_data.get_data()], axis=3)
                mask[sub] = np.stack([mask[sub], img_mask.get_data()], axis=3)

        # Compute average & variance of masked voxels across d4
        data[sub]['avg'] = np.average(data[sub]['stack'], weights=mask[sub], axis=3)
        data[sub]['var'] = np.average((data[sub]['stack'] -
                                       data[sub]['avg'][:, :, :, np.newaxis])**2,
                                      weights=mask[sub], axis=3)

        # Stack subjects in 4d
        for val in ['avg', 'var']:
            if sub == SUB_LIST[0]:
                data[val] = data[sub][val]
            else:
                data[val] = np.stack([data[val], data[sub][val]],
                                     axis=3)

    # Invert variance & set infinites to zero (if any)
    data['invvar'] = 1 / data['var']
    data['invvar'][np.isinf(data['invvar'])] = 0

    # Finally, compute variance weighted average
    data['wavg'] = np.average(data['avg'], weights=data['invvar'], axis=3)

    # Export
    out_img = nib.Nifti1Image(data['wavg'].astype(float), img_data.affine, img_data.header)
    out_img.to_filename(f'../wavg_{args.ftype}_masked_optcom.nii.gz')