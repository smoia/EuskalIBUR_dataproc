import os
import numpy as np
import pandas as pd


def correct_localizer_trial(trial_type, arg):
    """[summary]

    Parameters
    ----------
    trial_type : [type]
        [description]
    arg : [type]
        [description]

    Returns
    -------
    [type]
        [description]
    """
    for idx, trial in enumerate(trial_type):
        if trial == 'amot':
            if 'motci' in arg[idx]:
                trial_type.loc[idx] = 'amot_left'
            elif 'motcd' in arg[idx]:
                trial_type.loc[idx] = 'amot_right'

        if trial == 'vmot':
            if 'izquierdo' in arg[idx]:
                trial_type.loc[idx] = 'vmot_left'
            elif 'derecho' in arg[idx]:
                trial_type.loc[idx] = 'vmot_right'

    return trial_type


def bidsify_motor(main_path):
    """[summary]

    Parameters
    ----------
    main_path : [type]
        [description]
    """
    prj_dir = '/bcbl/data/MRI/PJ_MASK/DATA/Motor/data/'

    for subdirs, dirs, files in os.walk(prj_dir):
        for file in files:
            if file.endswith('.csv') and file[0] == '0':

                print(f'Reading {file}')

                try:
                    # Read csv file
                    file_df = pd.read_csv(os.path.join(prj_dir, file))

                    # Read participant number
                    participant = file[:3]

                    # Read session number
                    session = '00' + str(file_df['session'][0])
                    session = session[-2:]

                    # Read onset times (we don't remove the fist 15 seconds)
                    onset = file_df['move_onset']

                    # Add duration of 15 seconds
                    duration = np.ones(onset.shape) * 15

                    # Remove extension to trial_type
                    trial_type = file_df['image'].str.replace('.png', '')

                    # Create dictionary to populate new dataframe
                    bids_dict = {'onset': onset.values, 'duration': duration,
                                 'trial_type': trial_type.values}

                    # Create new dataframe with necessary columns
                    new_df = pd.DataFrame(data=bids_dict)

                    # Save new dataframe into BIDS compatible tsv file
                    new_df_path = f'{main_path}/sub-{participant}/ses-{session}/func/'
                    new_df.to_csv(os.path.join(new_df_path,
                                               f'sub-{participant}_ses-{session}_task-motor_events.tsv'), index=False, sep='\t')

                except:
                    print(f'There was an error with {file}')


def bidsify_localizer(main_path, localizer_dir):
    """[summary]

    Parameters
    ----------
    main_path : [type]
        [description]
    localizer_dir : [type]
        [description]
    """
    prj_dir = f'/bcbl/data/MRI/PJ_MASK/DATA/{localizer_dir}/data/'

    for subdirs, dirs, files in os.walk(prj_dir):
        for file in files:
            if file.endswith('.csv') and file[0] == '0':

                print(f'Reading {file}')

                try:
                    # Read csv file
                    file_df = pd.read_csv(os.path.join(prj_dir, file))

                    # Read participant number
                    participant = file[:3]

                    # Read session number
                    session = '00' + str(file_df['session'][0])
                    session = session[-2:]

                    # Read onset times (we don't remove the fist 15 seconds)
                    onset = file_df['localizer_onset']

                    # Add duration of 15 seconds
                    duration = file_df['ISI']

                    # Correct trial_type
                    trial_type = file_df['condition']
                    trial_type = correct_localizer_trial(trial_type, file_df['arg1'])

                    # Create dictionary to populate new dataframe
                    bids_dict = {'onset': onset.values,
                                 'duration': duration.values,
                                 'trial_type': trial_type.values}

                    # Create new dataframe with necessary columns
                    new_df = pd.DataFrame(data=bids_dict)

                    # Save new dataframe into BIDS compatible tsv file
                    new_df_path = f'{main_path}/sub-{participant}/ses-{session}/func/'
                    new_df.to_csv(os.path.join(new_df_path, f'sub-{participant}_ses-{session}_task-pinel_events.tsv'), index=False, sep='\t')

                except:
                    print(f'There was an error with {file}')


def bidsify_simon(main_path):
    """[summary]

    Parameters
    ----------
    main_path : [type]
        [description]
    """
    prj_dir = '/bcbl/data/MRI/PJ_MASK/DATA/Simon/data/'

    for file in os.listdir(prj_dir):
        # Get filename
        filename = os.fsdecode(file)

        if filename.endswith('.csv') and filename[0] == '0':

            print(f'Reading {file}')

            try:
                # Read csv file
                file_df = pd.read_csv(os.path.join(prj_dir, filename))

                # Read participant number
                participant = file[:3]

                # Read session number
                session = '00' + str(file_df['session'][0])
                session = session[-2:]

                # Read onset times (we don't remove the fist 15 seconds)
                onset = file_df['square_onset']
                relative_onset = file_df['onset']

                # Read duration
                duration = file_df['ISI']

                # Read trial_type and remove extension
                trial_type = file_df['pic'].str.replace('.png', '')

                # Read value
                value = file_df['coded']

                # Read response, wrong response (1==wrong, 0==correct) and response time
                response = file_df['text_resp.keys']
                response_is_wrong = file_df['text_resp.corr']
                response_time = file_df['text_resp.rt']

                # Create dictionary to populate new dataframe
                bids_dict = {'onset': onset.values,
                                'relative_onset': relative_onset.values,
                                'duration': duration.values,
                                'trial_type': trial_type.values,
                                'value': value.values,
                                'response': response.values,
                                'response_is_wrong': response_is_wrong.values,
                                'response_time': response_time.values}

                # Create new dataframe with necessary columns
                new_df = pd.DataFrame(data=bids_dict)

                # Save new dataframe into BIDS compatible tsv file
                new_df_path = f'{main_path}/sub-{participant}/ses-{session}/func/'
                new_df.to_csv(os.path.join(new_df_path, f'sub-{participant}_ses-{session}_task-simon_events.tsv'), index=False, sep='\t')

            except:
                print(f'There was an error with {file}')


def main():
    """[summary]
    """
    main_path = '/bcbl/home/public/PJMASK_2/preproc'

    # BIDSify motor task
    bidsify_motor(main_path)

    # BIDSify localizer task
    bidsify_localizer(main_path, 'Localizer_v5')
    bidsify_localizer(main_path, 'Localizer_v6')

    # BIDSify Simon task
    bidsify_simon(main_path)


if __name__ == '__main__':
    main()
