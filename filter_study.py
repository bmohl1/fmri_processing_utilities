"""Often, there are last minute requests to filter treatment groups differently and re-run a spatial analysis. The spatial analysis (MATLAB extension) requires updated cell arrays of filepaths and nuisance regressors that only apply to the included participants and their files.

This script imports the study-wide, demographic spreadsheet and allows the user to generate the new cell arrays and naming labels automatically for each analysis, saving a lot of brain power, time to manually filter and create lists in text files, and reducing mistakes."""
import os.path as op

def define_filter_list(**kwargs):
    """Choose filters based on who you want to include in an analysis"""
    filter_dict = {'gender':'all', #all, m, f
                    'obese' : 'all', #all, obese
                    'tx' : 'all', # a, b
                    'imaging' : 'avlbl', #default to limit the people to successful scans
                    'normal_responder' :'all'}
    if len(kwargs) == 0:
        keys = ', '.join(filter_dict.keys())
        print('Available args are: {}'.format(keys))

    #Update the default dictionary with any new filter values
    else:
        for kw,kwval in kwargs.items():
            filter_dict[kw] = kwval.strip()

    #Create a string to add to the end of files to keep the analyses straight
    filters = list()
    suffix = list()
    if filter_dict['tx'] != 'all':
        filters.append((filter_dict['tx'].strip()[0].upper()+'_')) #Special condition, so that Tx will always be before other filters

    for k,v in filter_dict.items():
        if k != 'tx' and v not in ('all', 'avlbl'):
            filters.append(v[0].lower()) #to get the first letter of the filter
            suffix.append(k[0].lower())

    if len(filters) < 2:
        filters = ('inclusive'); #Edge case, where you want the entire population for a one-sample t-test
        suffix  = ('inclusive');

    filters = ''.join(map(str,filters))
    suffix = ''.join(map(str,suffix))
    return (filter_dict, filters, suffix)

class GroupDef:
    def __init__(self, filter_dict, filters, df, covars = 'none'):
        self.filter = filters
        self.filter_dict = filter_dict
        self.covar_list = covars
        self.df = df

    def __repr__(self):
        return self.dir

    def filter_subjs(self):
        """Whittle the DF to only the people that fit the filter"""
        print ('Adding {} to the end of file names'.format(self.filter))
        for k,v in self.filter_dict.items():
            if v != 'all':
                name = [col for col in self.df.columns if k in col ] #Get flexible column name
                n = self.df.shape
                self.df = self.df[self.df[name].values==v] #Create boolean that matches filter
                print("Ran {} filter: from {} to {}".format(v, n, self.df.shape))

    def get_members(self):
        """Find the participant IDs and print to a text file (readable by matlab)"""
        self.members = self.df['subject_id'].tolist()
        self.txt_file = ('group' + self.filter + '.txt')

    def get_covars(self):
        """Find covariates corresponding to the participant IDs and print to a text file (readable by matlab)"""
        if self.covar_list != 'none':
            self.tx_val = [v for k,v in self.filter_dict.items() if k == 'tx']
            temp_df = self.df[self.df['tx'] == self.tx_val]
            self.covars = temp_df[[covar_list]] #should have the same order as members
            self.covars_file = ('group' + str(self.tx_val) + self.filter + 'cvs.txt')

#Note for other learners - The next section will only be executed if you are running this module, as opposed to calling it. So all "study-specfic" instructions can be written below the if statement.

if __name__ == "__main__":
    print('Will take user input, make a filter, and pare down df to the appropriate data points')
    print('Typically, run GroupDef, then filter_subj, and then, get_members')
