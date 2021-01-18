#!/usr/bin/env python3

import argparse
import os
import sys

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
import pandas as pd
from brainsmash.workbench.geo import volume
from brainsmash.mapgen.eval import sampled_fit
from brainsmash.mapgen.sampled import Sampled


LAST_SES = 10  # 10
ATLAS_LIST = ['Mutsaerts2015-hem', 'Schaefer2018-100', 'Yeo2011-7', 'Subcortical']  # 'Mutsaerts2015-sub', 'Mutsaerts2015', 'Schaefer2018-100',

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#1f77b4ff', '#2ca02cff', '#d62728ff', '#ff7f0eff', '#ff33ccff']

ATLAS_FILE = {'Mutsaerts2015': 'ATTbasedFlowTerritories_resamp_2.5mm',
              'Mutsaerts2015-hem': 'ATTbasedFlowTerritories_resamp_2.5mm_hem',
              'Mutsaerts2015-sub': 'ATTbasedFlowTerritories_resamp_2.5mm_sub_ceb',
              'Subcortical': 'subcortical_cerebellum_2.5mm',
              'Yeo2011-7': 'Yeo2011-7_2.5mm',
              'Schaefer2018-100': 'Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2.5mm'}
ATLAS_DICT = {'Mutsaerts2015': 'Mutsaerts (vascular)',
              'Mutsaerts2015-hem': 'Mutsaerts (vascular)',
              'Mutsaerts2015-sub': 'Mutsaerts (vascular + subcortical)',
              'Subcortical': 'Subcortical + cerebellum',
              'Yeo2011-7': 'Yeo (functional)',
              'Schaefer2018-100': 'Schaefer (functional)'}

ATLAS_FOLDER = os.path.join('CVR_reliability', 'Atlas_comparison')
LAST_SES += 1

CKEYS = ['avg', 'relvar']

DISTMAP = '/home/nemo/Scrivania/Test_workbench/CVR_reliability/Atlas_comparison/mmdist/distmat.npy'
INDEX = '/home/nemo/Scrivania/Test_workbench/CVR_reliability/Atlas_comparison/mmdist/index.npy'
SURROGATES_PR = '/home/nemo/Scrivania/Test_workbench/CVR_reliability/Atlas_comparison/surrogates_'

#########
# Utils #
#########
def _get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-in', '--input-file',
                        dest='data_fname',
                        type=str,
                        help='The map you want to scramble',
                        required=True)
    parser.add_argument('-type', '--input-type',
                        dest='data_content',
                        type=str,
                        help='The type of data represented in the map you want '
                             'to scramble',
                        default='')
    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    parser.add_argument('-sdr', '--scriptdir',
                        dest='scriptdir',
                        type=str,
                        help='Script directory.',
                        default='/scripts')
    parser.add_argument('-ow', '--overwrite',
                        dest='overwrite',
                        action='store_true',
                        help='Overwrite previously computed distances.',
                        default=False)
    parser.add_argument('-nm', '--num-null-maps',
                        dest='n_maps',
                        type=int,
                        help='Number of surrogate maps to generate. '
                             'Default is 1000.',
                        default=1000)
    parser.add_argument('-pn', '--plotname',
                        dest='plot_name',
                        type=str,
                        help='Plot name. Default: plots/plot.',
                        default='')
    parser.add_argument('-en', '--exportname',
                        dest='export_name',
                        type=str,
                        help='Name of nifti quantile export. Default: empty.',
                        default='')
    parser.add_argument('-sn', '--surrogate-name',
                        dest='surrogate_fname',
                        type=str,
                        help='Surrogates to import, folder+file basename. Default: empty.',
                        default='')
    parser.add_argument('-sen', '--surrogate-export-name',
                        dest='surrogate_export',
                        type=str,
                        help='Name of imported surrogates file export. Default: empty.',
                        default='')
    parser.add_argument('-nj', '--jobnumber',
                        dest='n_jobs',
                        type=int,
                        help='Number of jobs to use to parallelise computation. Default: 1.',
                        default=1)
    # Workflows
    parser.add_argument('-ga', '--genatlas',
                        dest='genatlas',
                        action='store_true',
                        help='Generate atlas dictionary.',
                        default=False)
    parser.add_argument('-cd', '--compdist',
                        dest='compdist',
                        action='store_true',
                        help='Compute distance and create memory-mapped file.',
                        default=False)
    parser.add_argument('-ev', '--evalvars',
                        dest='evalvars',
                        action='store_true',
                        help='Evaluate variograms.',
                        default=False)
    parser.add_argument('-gs', '--gensurr',
                        dest='gensurr',
                        action='store_true',
                        help='Generate surrogates and plots.',
                        default=False)
    parser.add_argument('-is', '--importsurr',
                        dest='importsurr',
                        action='store_true',
                        help='Import surrogates computed externally.',
                        default=False)
    parser.add_argument('-pa', '--computestats',
                        dest='computestats',
                        action='store_true',
                        help='Compute averages & relvars.',
                        default=False)
    parser.add_argument('-pp', '--plotparc',
                        dest='plotparc',
                        action='store_true',
                        help='Generate plots.',
                        default=False)
    parser.add_argument('-eq', '--exportrank',
                        dest='exportqnt',
                        action='store_true',
                        help='Generate rank niftis.',
                        default=False)
    return parser


def export_file(wdr, fname, ex_object):
    ex_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    os.makedirs(os.path.join(wdr, ATLAS_FOLDER), exist_ok=True)
    np.savez_compressed(ex_file, ex_object)


def check_file(wdr, fname):
    in_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    return os.path.isfile(in_file)


def load_file(wdr, fname):
    in_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    read_in = np.load(in_file, allow_pickle=True)['arr_0']
    if read_in.shape == ():
        return read_in[..., np.newaxis][0]
    else:
        return read_in


def load_and_mask_nifti(data_fname, atlases):
    data_img = nib.load(f'{data_fname}.nii.gz')
    data = data_img.get_fdata()
    if len(data.shape) == 5:
        data = data[:, :, :, 0, 0]
    elif len(data.shape) == 4:
        data = data[:, :, :, 0]
    elif len(data.shape) > 5:
        raise Exception('Something is wrong with the nifti dimensions')
    return data[atlases['intersect'] > 0]


#############
# Workflows #
#############
def generate_atlas_dictionary(wdr, scriptdir, overwrite=False):
    # Check that you really need to do this
    if overwrite is True or check_file(wdr, 'atlases.npz') is False:
        # Create data dictionary
        atlases = dict.fromkeys(ATLAS_LIST)

        print('Read and intersect atlases')
        # Read atlases
        for atlas in ATLAS_LIST:
            atlas_img = nib.load(os.path.join(scriptdir, '90.template',
                                              f'{ATLAS_FILE[atlas]}.nii.gz'))
            atlases[atlas] = atlas_img.get_fdata()

        # Create intersection of atlases
        atlases['intersect'] = atlases[ATLAS_LIST[0]].copy()

        for atlas in ATLAS_LIST[1:]:
            atlases['intersect'] = atlases['intersect'] + atlases[atlas]

        # Export atlases
        export_file(wdr, 'atlases', atlases)
    else:
        print(f'Found existing atlases dictionary in {wdr}, '
              'loading instead of generating.')
        atlases = load_file(wdr, 'atlases.npz')

    return atlases


def compute_distances(wdr, atlases, overwrite=False):
    # Check that you really need to do this
    # distmap = os.path.join('mmdist', 'distmap.npy')
    distmap = DISTMAP
    # if overwrite is True or check_file(wdr, distmap) is False:
    if overwrite is True or os.path.isfile(distmap) is False:
        coord_dir = os.path.join(wdr, ATLAS_FOLDER, 'mmdist')
        # Create folders
        os.makedirs(coord_dir, exist_ok=True)
        print('Computing volume distance')
        # Get position of the voxels in the atlas intersection
        coordinates = np.asarray(np.where(atlases['intersect'] > 0)).transpose()
        dist_fname = volume(coordinates, coord_dir)
    else:
        # distmap = os.path.join(wdr, ATLAS_FOLDER, distmap)
        # index = os.path.join(wdr, ATLAS_FOLDER, 'mmdist', 'index.npy')
        index = INDEX
        print('Distance memory mapped file already exists. Skip computation!')
        dist_fname = {'D': distmap, 'index': index}

    return dist_fname


def evaluate_variograms(data_fname, atlases, dist_fname, wdr, **kwargs):
    # Read data and feed surrogate maps
    data_masked = load_and_mask_nifti(data_fname, atlases)
    print(f'Evaluating variogram for {data_fname}')
    sampled_fit(x=data_masked, D=dist_fname['D'], index=dist_fname['index'],
                nsurr=50, **kwargs)

    ex_file = os.path.join(wdr, ATLAS_FOLDER, f'{data_fname}_variogram.png')
    plt.savefig(ex_file)
    plt.close('all')


def generate_surrogates(data_fname, atlases, dist_fname, n_jobs, n_maps, wdr, overwrite=False):
    data_masked = load_and_mask_nifti(data_fname, atlases)
    # Check that data_fname doesn't contain folders.
    data_fname = os.path.basename(data_fname)

    surrogate_fname = f'surrogates_{data_fname}'

    # if overwrite is True or os.path.isfile(f'{surrogate_fname}.npz') is False:
    if overwrite is True or check_file(wdr, f'{surrogate_fname}.npz') is False:
        # Read data and feed surrogate maps
        print(f'Start surrogates for {data_fname}')

        gen = Sampled(x=data_masked, D=dist_fname['D'],
                      index=dist_fname['index'], seed=42, n_jobs=n_jobs)
        surrogate_maps = gen(n=n_maps)

        # Export atlases
        export_file(wdr, surrogate_fname, surrogate_maps)

        print('Resample surrogates')

        sorted_map = np.sort(data_masked)
        ii = np.argsort(surrogate_maps)
        surrogate_resamp = sorted_map[ii]

        export_file(wdr, f'{surrogate_fname}_resamp', surrogate_resamp)
    else:
        print(f'Surrogates found at {surrogate_fname}_resamp.npz. Loading.')
        surrogate_resamp = load_file(wdr, f'{surrogate_fname}_resamp.npz')

    return surrogate_resamp, data_masked


def import_surrogates(data_fname, n_maps, surrogate_basename, surrogate_export, wdr):
    print(f'Importing surrogates from {surrogate_basename}')
    data_masked = load_and_mask_nifti(data_fname, atlases)
    surrogate_maps = []
    for n in range(n_maps):
        surrogate_fname = f'{surrogate_basename}_{n:03g}'
        print(f'Import surrogate {os.path.basename(surrogate_fname)}')
        surrogate_maps = surrogate_maps + [load_and_mask_nifti(surrogate_fname, atlases)]

    surrogate_maps = np.stack(surrogate_maps, axis=0)

    print(f'Export new surrogates to surrogates_import_{surrogate_export}.npz')
    export_file(wdr, f'surrogates_import_{surrogate_export}', surrogate_maps)

    return surrogate_maps, data_masked


def compute_relvars(wdr, data_fname, n_maps, atlases, surrogate_maps, data_masked, overwrite=False):
    # Compute relative variances and store them in pandas dataframes
    # Then compute rank and store them in other pd.DataFrame

    # if overwrite is True or os.path.isfile(f'{surrogate_fname}.npz') is False:
    if overwrite is True or check_file(wdr, f'{data_fname}_relvar.npz') is False:
        # Setup pandas df
        print('Computing relative variances')
        df_dict = dict.fromkeys(ATLAS_LIST)
        rank_dict = dict.fromkeys(ATLAS_LIST)

        for atlas in ATLAS_LIST:
            # Mask atlas to match data_masked
            atlas_masked = atlases[atlas][atlases['intersect'] > 0]
            # Find unique values (labels) and remove zero
            unique, _ = np.unique(atlas_masked, return_counts=True)
            unique = unique[unique > 0]
            # Initialise dataframe and dictionary for series
            df_dict[atlas] = pd.DataFrame(index=unique)
            label_dict = dict.fromkeys(unique)

            # Compute relative variances
            for label in unique:
                # Start with real maps
                label_dict[label] = (data_masked[atlas_masked == label].var() /
                                     data_masked.var())

            df_dict[atlas]['real'] = pd.Series(label_dict)

            for n in range(n_maps):
                # Continue with all surrogates
                for label in unique:
                    label_dict[label] = (surrogate_maps[n][atlas_masked == label].var() /
                                         surrogate_maps[n].var())

                df_dict[atlas][f'surrogate_{n}'] = pd.Series(label_dict)

            # Take the argmin of argsort of the dataframe to find the position of the real data
            rank = np.argsort(df_dict[atlas].to_numpy(), axis=-1)
            rank_dict[atlas] = rank.argmin(axis=-1)
            # Dividing it by (n_maps+1)/100 will give rank (percentages)
            rank_dict[atlas] = (n_maps - rank_dict[atlas]) / (n_maps/100)

        # Export files
        export_file(wdr, f'{data_fname}_relvar', df_dict)
        export_file(wdr, f'{data_fname}_relvar_rank', rank_dict)
    else:
        print(f'Relative variances found at {data_fname}_relvar.npz. Loading.')
        df_dict = load_file(wdr, f'{data_fname}_relvar.npz')
        rank_dict = load_file(wdr, f'{data_fname}_relvar_rank.npz')

    return df_dict, rank_dict


def compute_averages(wdr, data_fname, n_maps, atlases, surrogate_maps, data_masked, overwrite=False):
    # Compute averages and store them in pandas dataframes
    # Then compute rank and store them in other pd.DataFrame

    # if overwrite is True or os.path.isfile(f'{surrogate_fname}.npz') is False:
    if overwrite is True or check_file(wdr, f'{data_fname}_avg.npz') is False:
        # Setup pandas df
        print('Computing averages')
        df_dict = dict.fromkeys(ATLAS_LIST)
        rank_dict = dict.fromkeys(ATLAS_LIST)

        for atlas in ATLAS_LIST:
            # Mask atlas to match data_masked
            atlas_masked = atlases[atlas][atlases['intersect'] > 0]
            # Find unique values (labels) and remove zero
            unique, _ = np.unique(atlas_masked, return_counts=True)
            unique = unique[unique > 0]
            # Initialise dataframe and dictionary for series
            df_dict[atlas] = pd.DataFrame(index=unique)
            label_dict = dict.fromkeys(unique)

            # Compute averages
            for label in unique:
                # Start with real maps
                label_dict[label] = data_masked[atlas_masked == label].mean()

            df_dict[atlas]['real'] = pd.Series(label_dict)

            for n in range(n_maps):
                # Continue with all surrogates
                for label in unique:
                    label_dict[label] = surrogate_maps[n][atlas_masked == label].mean()

                df_dict[atlas][f'surrogate_{n}'] = pd.Series(label_dict)

            # Take the argmin of argsort of the dataframe to find the position of the real data
            rank = np.argsort(df_dict[atlas].to_numpy(), axis=-1)
            rank_dict[atlas] = rank.argmin(axis=-1)
            # Dividing it by (n_maps+1)/100 will give rank (percentages)
            rank_dict[atlas] = rank_dict[atlas] / (n_maps/100)

        # Export files
        export_file(wdr, f'{data_fname}_avg', df_dict)
        export_file(wdr, f'{data_fname}_avg_rank', rank_dict)
    else:
        print(f'Averages found at {data_fname}_avg.npz. Loading.')
        df_dict = load_file(wdr, f'{data_fname}_avg.npz')
        rank_dict = load_file(wdr, f'{data_fname}_avg_rank.npz')

    return df_dict, rank_dict


def plot_parcels(data_content, atlases, data_avg, plot_name=''):
    # Plot parcel value against voxel size
    # Setup plot
    print('Plot some values')
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.xlabel('Number of voxels in MNI')

    # #!# ylabel has to reflect data
    plt.ylabel(data_content)
    # plt.ylim(0, 1)
    patch = []

    for atlas in ATLAS_LIST:
        # Mask atlas to match data_masked
        atlas_masked = atlases[atlas][atlases['intersect'] > 0]
        # Find unique values (labels) and occurrencies (label size)
        unique, occurrencies = np.unique(atlas_masked, return_counts=True)

        # Plot everything
        plt.plot(occurrencies[1:], data_avg[atlas], '.', color='#bbbbbbff')

    # Repeat loop to plot real data on top of the rest.
    for j, atlas in enumerate(ATLAS_LIST):
        # Mask atlas to match data_masked
        atlas_masked = atlases[atlas][atlases['intersect'] > 0]
        # Find unique values (labels) and occurrencies (label size)
        unique, occurrencies = np.unique(atlas_masked, return_counts=True)

        # Replot "real" data to superimpose it
        plt.plot(occurrencies[1:], data_avg[atlas]['real'], '.', color=COLOURS[j])

        # Add a patch for the current atlas
        patch = patch + [mpatches.Patch(color=COLOURS[j], label=ATLAS_DICT[atlas])]

    # Adjust legend and layout
    patch = patch + [mpatches.Patch(color='#bbbbbbff', label='Surrogates')]
    plt.legend(handles=patch)
    plt.tight_layout()

    # Save plot
    print(f'Saving plot as: {plot_name}_by_voxel.png')
    os.makedirs(os.path.dirname(plot_name), exist_ok=True)
    plt.savefig(f'{plot_name}_by_voxel.png', dpi=SET_DPI)
    plt.close('all')


def rank_to_nifti(scriptdir, rank_dict, wdr, export_fname, overwrite=False):
    # Export rank in nifti format
    print('Export rank analysis to nifti')
    os.makedirs(os.path.dirname(export_fname), exist_ok=True)
    # Read atlases
    for atlas in ATLAS_LIST:
        atlas_img = nib.load(os.path.join(scriptdir, '90.template',
                                          f'{ATLAS_FILE[atlas]}.nii.gz'))
        data = atlas_img.get_fdata()

        unique = np.unique(data)
        unique = unique[unique > 0]

        for n, label in enumerate(unique):
            data[data == label] = rank_dict[atlas][n]

        out_img = nib.Nifti1Image(data, atlas_img.affine, atlas_img.header)
        out_img.to_filename(f'{export_fname}_{atlas}.nii.gz')


########
# MAIN #
########
if __name__ == '__main__':
    args = _get_parser().parse_args(sys.argv[1:])

    # Check that data_fname doesn't end for nii.gz
    data_fname = args.data_fname

    if data_fname.endswith('.nii.gz'):
        data_fname = data_fname[:-7]
    elif data_fname.endswith('.nii'):
        data_fname = data_fname[:-4]

    # Check plot_name or export_name is empty
    plot_name = args.plot_name
    export_name = args.export_name
    if plot_name == '':
        plot_name = f'{os.path.basename(data_fname)}_plot'
        plot_name = os.path.join(args.wdr, ATLAS_FOLDER, 'plots', plot_name)
    if export_name == '':
        export_name = f'{os.path.basename(data_fname)}_rank'
        export_name = os.path.join(args.wdr, ATLAS_FOLDER, 'vols', export_name)

    # Start the desired workflow
    if args.genatlas is True:
        # Check if atlases was already computed
        if args.overwrite is True or check_file(args.wdr, 'atlases.npz') is False:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir, args.overwrite)
        else:
            print('Atlas already exists')

    elif args.compdist is True:

        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)

    elif args.evalvars is True:
        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)
        # kwargs = {'ns': 500,
        #   'knn': 1500,
        #   'pv': 70
        #   }
        evaluate_variograms(data_fname,
                            atlases,
                            dist_fname,
                            args.wdr)

    elif args.gensurr is True:
        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)
        surrogate_maps, data_masked = generate_surrogates(data_fname,
                                                          atlases,
                                                          dist_fname,
                                                          args.n_jobs,
                                                          args.n_maps,
                                                          args.wdr,
                                                          args.overwrite)

        data_parsed = dict.fromkeys(CKEYS)
        data_qnt = dict.fromkeys(CKEYS)

        for key, compute in zip(CKEYS, [compute_averages, compute_relvars]):
            data_parsed[key], data_qnt[key] = compute(args.wdr,
                                                      os.path.basename(data_fname),
                                                      args.n_maps,
                                                      atlases,
                                                      surrogate_maps,
                                                      data_masked,
                                                      args.overwrite)
            plot_parcels(args.data_content,
                         atlases,
                         data_parsed[key],
                         f'{plot_name}_plot_{key}')
            rank_to_nifti(args.scriptdir,
                          data_qnt[key],
                          args.wdr,
                          f'{export_name}_{key}')

    elif args.importsurr is True:
        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)
        surrogate_maps, data_masked = import_surrogates(data_fname,
                                                        args.n_maps,
                                                        args.surrogate_fname,
                                                        args.surrogate_export,
                                                        args.wdr)

        data_parsed = dict.fromkeys(CKEYS)
        data_qnt = dict.fromkeys(CKEYS)

        for key, compute in zip(CKEYS, [compute_averages, compute_relvars]):
            print(f'Compute {key} using {compute}')
            data_parsed[key], data_qnt[key] = compute(args.wdr,
                                                      os.path.basename(data_fname),
                                                      args.n_maps,
                                                      atlases,
                                                      surrogate_maps,
                                                      data_masked,
                                                      args.overwrite)
            print(f'Plot {key}')
            plot_parcels(args.data_content,
                         atlases,
                         data_parsed[key],
                         f'{plot_name}_{key}')
            print(f'Export rank {key}')
            rank_to_nifti(args.scriptdir,
                          data_qnt[key],
                          args.wdr,
                          f'{export_name}_{key}')

    elif args.computestats is True:
        # Check if surrogates exists, otherwise stop
        surrogate_fname = f'surrogates_{os.path.basename(data_fname)}.npz'
        # surrogate_fname = f'surrogates_{os.path.basename(data_fname)}_resamp.npz'
        if check_file(args.wdr, surrogate_fname) is False:
            raise Exception('Cannot find surrogate maps: '
                            f'{surrogate_fname} in '
                            f'{os.path.join(args.wdr, ATLAS_FOLDER)}')
        else:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
            surrogate_maps = load_file(args.wdr, surrogate_fname)
            # Read and extract data
            data_masked = load_and_mask_nifti(data_fname, atlases)

            data_parsed = dict.fromkeys(CKEYS)
            data_qnt = dict.fromkeys(CKEYS)

            for key, compute in zip(CKEYS, [compute_averages, compute_relvars]):
                data_parsed[key], data_qnt[key] = compute(args.wdr,
                                                          os.path.basename(data_fname),
                                                          args.n_maps,
                                                          atlases,
                                                          surrogate_maps,
                                                          data_masked,
                                                          args.overwrite)
                plot_parcels(args.data_content,
                             atlases,
                             data_parsed[key],
                             f'{plot_name}_plot_{key}')
                rank_to_nifti(args.scriptdir,
                              data_qnt[key],
                              args.wdr,
                              f'{export_name}_{key}')

    elif args.plotparc is True:
        # Check if surrogates exist, otherwise stop
        surrogate_fname = f'surrogates_{os.path.basename(data_fname)}.npz'
        # surrogate_fname = f'surrogates_{os.path.basename(data_fname)}_resamp.npz'
        if check_file(args.wdr, surrogate_fname) is False:
            raise Exception('Cannot find surrogate maps: '
                            f'{surrogate_fname} in '
                            f'{os.path.join(args.wdr, ATLAS_FOLDER)}')
        else:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
            surrogate_maps = load_file(args.wdr, surrogate_fname)
            # Read and extract data
            data_masked = load_and_mask_nifti(data_fname, atlases)

            # Parse averages
            data_parsed = dict.fromkeys(CKEYS)

            for key, compute in zip(CKEYS, [compute_averages, compute_relvars]):
                data_parsed[key], _ = compute(args.wdr,
                                              os.path.basename(data_fname),
                                              args.n_maps,
                                              atlases,
                                              surrogate_maps,
                                              data_masked,
                                              args.overwrite)
                plot_parcels(args.data_content,
                             atlases,
                             data_parsed[key],
                             f'{plot_name}_plot_{key}')

    elif args.exportqnt is True:
        # Check if surrogates exist, otherwise stop
        surrogate_fname = f'surrogates_{os.path.basename(data_fname)}.npz'
        # surrogate_fname = f'surrogates_{os.path.basename(data_fname)}_resamp.npz'
        if check_file(args.wdr, surrogate_fname) is False:
            raise Exception('Cannot find surrogate maps: '
                            f'{surrogate_fname} in '
                            f'{os.path.join(args.wdr, ATLAS_FOLDER)}')
        else:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
            surrogate_maps = load_file(args.wdr, surrogate_fname)
            # Read and extract data
            data_masked = load_and_mask_nifti(data_fname, atlases)

            data_qnt = dict.fromkeys(CKEYS)

            for key, compute in zip(CKEYS, [compute_averages, compute_relvars]):
                _, data_qnt[key] = compute(args.wdr,
                                           os.path.basename(data_fname),
                                           args.n_maps,
                                           atlases,
                                           surrogate_maps,
                                           data_masked,
                                           args.overwrite)

                rank_to_nifti(args.scriptdir,
                              data_qnt[key],
                              args.wdr,
                              f'{export_name}_{key}')

    else:
        raise Exception('No workflow flag specified!')
