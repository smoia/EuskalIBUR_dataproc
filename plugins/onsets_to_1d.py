import glob
import io
import numpy as np
import os
import pandas as pd
from os.path import join as opj


def save_onsets(func_path, onset_path, to_remove):
    """[summary]

    Parameters
    ----------
    func_path : [type]
        [description]
    onset_path : [type]
        [description]
    to_remove : [type]
        [description]
    """
    # Get tsv files with onsets
    for file in glob.glob(func_path + '/*.tsv'):

        if 'pinel' in file or 'simon' in file or 'motor' in file:
            df = pd.read_csv(file, sep='\t')
            onset = df['onset']
            duration = df['duration']
            trial_type = df['trial_type']
            trial_unique = np.unique(trial_type)

            basename = file[file.rfind('/')+1:]
            basename = basename[:basename.rfind('_')]

            if 'simon' in file:
                response_wrong = df['response_is_wrong'].values

                correct_filename = opj(onset_path, f'{basename}_correct_onset.1D')
                incorrect_filename = opj(onset_path, f'{basename}_incorrect_onset.1D')

                # Extract onsets and substract initial seconds
                onsets = np.round(onset - to_remove, decimals=2)

                # Save correct and incorrect onsets
                onsets[response_wrong == 0].to_csv(correct_filename, index=False)
                onsets[response_wrong == 1].to_csv(incorrect_filename, index=False)

            # Loop through trials
            for trial in trial_unique:

                # Mask to only use this trial
                keep = trial_type == trial

                # Prepare output filename for onsets and duration
                onsets_filename = opj(onset_path,
                                      f'{basename}_{trial}_onset.1D')
                duration_filename = opj(onset_path,
                                        f'{basename}_{trial}_duration.1D')

                # Extract onsets and substract initial seconds
                onsets = np.round(onset[keep] - to_remove, decimals=2)

                if 'pinel' in file or 'motor' in file:
                    # Save onsets file
                    onsets.to_csv(onsets_filename, index=False)

                # Save durations
                durations = duration[keep]
                durations.to_csv(duration_filename, index=False)

                if 'simon' in file:
                    onsets_duration = []
                    for i in range(len(onsets)):
                        onsets_duration.append(f'{onsets.values[i]}:{durations.values[i]}')

                    onsets_duration_df = pd.read_csv(io.StringIO('\n'.join(onsets_duration)),
                                                     delim_whitespace=True)

                    onsets_duration_df.to_csv(onsets_filename, index=False)



def main():
    """[summary]
    """
    prj_dir = '/home/eurunuela/public/PJMASK_2/preproc'
    to_remove = 15

    # Get subject directories
    sbj_dirs = [dirname for dirname in os.listdir(prj_dir) if 'sub' in dirname]

    # Loop through all subject directories
    for sbj_dir in sbj_dirs:

        sbj_path = opj(prj_dir, sbj_dir)

        if os.path.isdir(sbj_path):

            # Get session directories
            ses_dirs = os.listdir(sbj_path)

            # Loop through all session directories
            for ses_dir in ses_dirs:

                print(f'Extracting onsets of {sbj_dir} and {ses_dir}...')

                ses_path = opj(sbj_path, ses_dir)
                func_path = opj(ses_path, 'func')
                onset_path = opj(ses_path, 'func_preproc/onsets')

                try:
                    # Create onset directory if it doesn't exist
                    if not os.path.isdir(onset_path):
                        os.mkdir(onset_path)

                    # Save onsets of all three tasks
                    save_onsets(func_path, onset_path, to_remove)
                except:
                    print(f'Could not extract onsets of {sbj_dir}/{ses_dir}')

    print('Onsets of all subjects and sessions correctly extracted!')


if __name__ == '__main__':
    main()
