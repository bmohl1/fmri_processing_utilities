home_dir = '/data/images/priming_2017';

cd(home_dir)
task = 'fp';
%ppi = 'PPI_LpPut_cond'; %may turn this option off by commenting.

if exist('ppi')
  spm_files = {ls(strcat(home_dir,filesep,'*',filesep,task,filesep,'results_art',filesep,ppi, filesep,'SPM.mat'))};
else
  spm_files = {ls(strcat(home_dir,filesep,'I*',filesep,task,'*results*',filesep,'SPM.mat'))};
end
spm_files = strrep(spm_files{1},'mat','mat#');
spm_files = strtrim(transpose(regexp(spm_files,'#','split')));

for i = 1:length(spm_files)
  spm_mat = {(spm_files{i})};
  clear matlabbatch

  fprintf('Running: %s \n',spm_mat{1})
  matlabbatch{1}.spm.stats.con.spmmat = spm_mat;
  matlabbatch{1}.spm.stats.con.consess{1}.tcon.name = 'avg visual cue - baseline';
  matlabbatch{1}.spm.stats.con.consess{1}.tcon.convec = [-1 0.3 0.3 0.3 ];
  matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'repl';
  matlabbatch{1}.spm.stats.con.delete = 0;
  spm_jobman('run',matlabbatch)
  cd(home_dir)
  disp('Done.')
end
