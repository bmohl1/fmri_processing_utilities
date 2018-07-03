addpath('/home/brianne/tools'); % need glob
% Purpose: In testing pipelines, sometimes one needs to know how the residuals are affected by pipeline choices. This script aims to quantify the mean residuals from four of our top pipeline choices.


'ResMS.nii'
'spmT_0005.nii'
'con_0003.nii'

topDir = ('/data/analysis/brianne/priming_2017/mICA_test')
savefile = [topDir,filesep,'variability.csv']
fid = fopen(savefile, 'w+');
comps = {'fp_results','fp_resultsArt','fp_results_agg_dn_pre','fp_results_nonagg_dn_pre'}
M = [];
for c = 1 : length(comps)
  cmp = comps{c};
  res = glob([topDir,filesep,'*', filesep, cmp, filesep,'con_0005.nii'])
  sprintf('%s',cmp);
  for r =1: length(res)
    file = spm_vol(res{r});
    mat = spm_read_vols(file);
    val = mean2(mat(~isnan(mat)));
    %mx = sum(mat(~isnan(mat)));
    m = {res{r}, val};
    M = [M; m];
  end
end
M
save(savefile, 'M');
