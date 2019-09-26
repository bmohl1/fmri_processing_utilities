def _comparisons(self, model_specs_csv, con_level=2):
    """Create inputs for first- and second-level analyses using a csv definition file.
    Expected column titles are 'con_level' (1 or 2), con_name' ('low_greaterThan_baseline'),'type' ('T'),'conditions' (['high', 'low', 'crazy', 'baseline']),'matrix' ([0 1 0 -1].
    The returned list is appropriate for nipype contrast estimate inputs."""
    self.model_file = model_specs_csv
    self.model_spec_df = pd.DataFrame(pd.readcsv(self.model_file))
    try:
        self.model_spec_df = self.model_spec_df.loc[df['con_level'] == con_level, :]
        contrasts = []
        for row in df[['con_name', 'type', 'conditions', 'matrix']]:
            contrasts.append(row.to_list())
    except:
        # TODO test for the common exceptions and add useful error messages.
        print('Trouble in contrast info gathering')
    return contrasts
