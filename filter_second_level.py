import os
import numpy as np
import pandas as pd
import glob
import filter_study as fs

# import qgrid  #For future, interactive filters that can be built out for non-coders?

# import qgrid  #For future, interactive filters that can be built out for non-coders?
full_desc = 'no'  # Toggle to "debug" new study entries
home = r'/Users/bmohl/Documents'
project = 'priming'

#var_dict = {'project' : '', 'task' : '', 'analysis_type' : '', 'cons_incl' : (), 'groups' : ('all'), 'obese' : ('all'), 'gender' : ('all'), 'tx' : ('all'), 'normal_responder' : ('all')}
# print(var_dict)
study_filters = ('tx', 'gender', 'normal_responder', 'obese')

img_dir = glob.glob(os.path.join(home, r'data/images', (project + '*')))
analysis_dir = glob.glob(os.path.join(
    home, 'data/analysis/', (project + '*')))[0]
#results_dir = glob.glob(os.path.join(home, 'data/analysis/brianne',(project +'*'), 'results/food_pics'))[0]
results_dir = 'dummy_file'

# Load the dataframe from which we can filter
demo_file = glob.glob(os.path.join(analysis_dir, '*demo*xlsx'))
########################################################################
###  Should not require changes to the hard coding from here         ###
########################################################################
if len(demo_file) > 1:
    print('Detected multiple versions of the study demographics.\nAssuming the first is the correct sheet: {}'.format(
        demo_file[0]))
df = pd.DataFrame(pd.read_excel(demo_file[0])).astype(
    str).sort_values(by=['subject_id'])
# to attempt to normalize names for ensuing functions
df.columns = [x.lower() for x in df.columns]
if 'y' in full_desc:
    print(df.columns.tolist())
    print(df.shape)
    print(fs.define_filter_list())


# this will enable multiple filters to be setup with full brain power and traceable record
setup_file = glob.glob(os.path.join(analysis_dir, '*setup*xlsx'))
if len(setup_file) > 1:
    print('Detected multiple versions of the study demographics.\nAssuming the first is the correct sheet: {}'.format(
        setup_file[0]))
setup_df = pd.DataFrame(pd.read_excel(setup_file[0])).dropna(how='all')
# to attempt to normalize names for ensuing functions
setup_df.columns = [x.lower() for x in setup_df.columns]


if 'y' in full_desc:
    print(setup_df.head(5))


for r in range(setup_df.shape[0]):
    err = 'False'  # flag for incomplete variable loading
    # Find the conditions that must be satisfied to be part of the analysis
    # since each analysis might have different columns that are empty, do the col drop here.
    analysis_dict = setup_df.iloc[r].dropna().to_dict()
    groups = [x.strip() for x in analysis_dict['groups'].split(',')]
    print(len(groups))
    conditions = list(
        [k for k, v in analysis_dict.items() if k in study_filters])
    # apply the filters to pare down the groups and corresponding df's

    for p in range(len(groups)):
        print('ROw {}: Group {} of {} is up'.format(r, p + 1, len(groups)))
        input_dict = {}
        for cond in conditions:
            input_dict[cond] = analysis_dict[cond].strip().split(',')[p]
        [filter_dict, filters, result_suffix] = fs.define_filter_list(
            **input_dict)  # normal_responder = responder[k])
        # By setting this new variable before defining the object, we can sneakily avoid truly dynamic variable naming and duplicating an object.
        name = analysis_dict['groups'].split(',')[p].strip()
        print('Loading {} for {}'.format(filter_dict, name))
        groups[p] = fs.GroupDef(filter_dict, filters, df)
        groups[p].filter_subjs()
        groups[p].get_members()
        while len(groups[p].members) < 5:
            print('Sampling size problem with {}'.format(groups[p].filter))
            err = 'True'
            break
        if len(groups[p].members) > 5:
            groups[p].name = name
            with open(os.path.join(analysis_dir, groups[p].txt_file), 'w+') as fp:
                fp.write('{}'.format('\n'.join(groups[p].members)))

    if err == 'False':
            # Set up for the matlab commands
        group_names = [groups[0].name, groups[1].name]
        list_suffixes = [groups[0].filter, groups[1].filter]
        # print(list_suffixes)
        list_suffixes = (
            '\'' + '\', \''.join(map(str, list_suffixes)) + '\'')
        # print(list_suffixes)
        cons_incl = [x.strip()
                     for x in analysis_dict['cons_incl'].split(',')]
        analysis_type = [x.strip()
                         for x in analysis_dict['analysis_type'].split(',')]
        # Make the options for MATLAB function = second_level_spm12(contrasts, Groups, list_suffixes, comp_type, results_dir, result_suffixes)
        opts = ("{\'" + '\', \''.join(cons_incl) + "\'}, {\'" + '\', \''.join(group_names) + "\'}, {" +
                str(list_suffixes) + "}, {" + str(analysis_type) + "}, \'" + results_dir + "\', {\'" + result_suffix + "\'}")

        cmd = ('matlab -nosplash -nodesktop -r "addpath(\'/home/brianne/tools/fmri_processing_utilities\'); second_level_spm12(' + opts + '); quit()"')
        print(cmd)
        os.system(cmd)
