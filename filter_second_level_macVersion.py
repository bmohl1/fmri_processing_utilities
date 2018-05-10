import os.path as op
import numpy as np
import pandas as pd
import glob
import filter_study as fs
#import qgrid  #For future, interactive filters that can be built out for non-coders?

#Change the values here to adapt the analysis
full_desc = 'yes' #Toggle to "debug" new study entries
project = 'priming'
task = 'food_pics'

home = r'/Users/bmohl/Documents'
img_dir = glob.glob(op.join(home, r'data/images',(project +'*')))
analysis_dir = glob.glob(op.join(home, 'data/analysis',(project +'*')))[0]

#Load the dataframe from which we can filter
xl_file = glob.glob(op.join(analysis_dir, '*demo*xlsx'))
########################################################################
###  Should not require changes to the hard coding from here         ###
########################################################################
if len(xl_file) > 1:
    print('Detected multiple versions of the study demographics.\nAssuming the first is the correct sheet: {}'.format(xl_file))
df = pd.DataFrame(pd.read_excel(xl_file[0])).astype(str).sort_values(by=['subject_id'])
df.columns = [x.lower() for x in df.columns] #to attempt to normalize names for ensuing functions
if 'y' in full_desc:
    print(df.columns.tolist())
    print(df.shape)
    print(fs.define_filters())

#set up analysis groups = ['females','males']
#Note that *IF* you change one of these parameters, you need to re-run the df import
groups = ['femaleResponders','maleResponders']
bmi = []
genders = ['F','M']
responder = ['y','y']
txts = ['B','A']


for k in range(len(groups)):
    [filter_dict, filters, result_suffix] = fs.define_filters(tx = txts[k], gender = genders[k],normal_responder = responder[k])
    name = groups[k] #By setting this new variable before defining the object, we can sneakily avoid truly dynamic variable naming and duplicating an object.
    print(name)
    groups[k] = fs.GroupDef(filter_dict, filters, df)
    groups[k].filter_subjs()
    groups[k].get_members()
    groups[k].name = name
    with open(op.join(analysis_dir,groups[k].txt_file),'w+') as fp:
        fp.write('{}'.format(groups[k].members))

#Set up for the matlab commands
analysis_type = 'two_sample' #one_sample, two_sample, full_factorial
cons_incl = ('con_0003')
group_names = [groups[0].name, groups[1].name]
list_suffixes = [groups[0].filter, groups[1].filter]
#print(list_suffixes)
list_suffixes = '\', \''.join(map(str,list_suffixes))
#print(list_suffixes)

opts = ("{\'" + '\', \''.join(map(str,cons_incl)) + "}, {\'" + '\', \''.join(map(str,group_names)) + "}, {\'" + list_suffixes + "}, " + analysis_dir + "}, {\'" + result_suffix + "\'}")
print(opts)
