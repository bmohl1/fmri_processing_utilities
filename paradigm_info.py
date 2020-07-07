def paradigm_info(design_text_file):
    """Create the inputs for first- (or second-) level analyses based on a csv design file.
    The expected column titles for the csv are 'name' for the specific task (e.g., 'fp_run1'),'conditions' (e.g.,'highCal'), 'onsets',and 'durations'"""
    from nipype.interfaces.base import Bunch
    import pandas as pd
    try:
        df = pd.DataFrame(pd.readcsv(design_text_file))
        conditions = []
        onsets = []
        durations = []
        
        for task in sorted(set(df['name'])):
            df = df.loc[df['name']==task,:] # limiting to the applicable data
            conditions.append(df['conditions'])
            onsets.append(df['onsets'])
            durations.append(df['durations'])
        par_info = Bunch([conditions],[onsets],[durations])

    except:
        # TODO test to see what types of errors may be common (lists in the durations, no column name, etc.)
        print ('Error in paradigm info.')
        
    return par_info