% Make sure the glob utility is available to find all files, but don't keep updating the path
if isempty(which('glob'))
  addpath('/home/brianne/tools')
end

if strfind(which('spm'),'/spm12/')
  set_spm %makes sure that SPM12b is used.
end

%% Set the specific contrasts and options
task_gp1 = 'priming';
task_gp2 = 'fp';
suffix = 'ERstyle';
con='003';
art = 'no';
projDir = ['/home/data/analysis/brianne/priming_2017'];
subjDir = ['/home/data/images/priming_2017'];
homeDir= [projDir, filesep,'results/priming_intvn/two_sample_highGRlow_duringVafter_nonAgg'];
if ~exist(homeDir,'dir')
  mkdir(homeDir);
end

  if strncmpi('y',art,1)
    res_dir_gp1 = [task_gp1, '_resultsArt'];
    res_dir_gp2 = [task_gp2, '_resultsArt'];
  else
    res_dir_gp1 = [task_gp1, '_results_nonagg'];
    res_dir_gp2 = [task_gp2, '_results_nonagg'];
  end

%% Change the file name to reflect the textfiles that have the correct grouping for your comparison
list_gp1 = textscan(fopen([projDir,filesep,'groupA']),'%s','Delimiter','\n');
list_gp2 = textscan(fopen([projDir,filesep,'groupB']),'%s','Delimiter','\n');
fclose('all');

%Use glob to put the filepath in a cell array
files_gp1_cond1 ={};
for n = 1: length(list_gp1{:})
  tmp = glob([subjDir, filesep, list_gp1{1,1}{n},filesep,res_dir_gp1,'_',suffix,filesep,'con_0',con,'.nii']);
  if ~isempty(tmp)
    files_gp1_cond1{n} = tmp{1,1};
  else
    fprintf('MISSING contrast for: %s\n',list_gp1{1,1}{n})
  end
end
files_gp2_cond1 ={};
for m = 1: length(list_gp2{:})
  tmp = glob([subjDir, filesep, list_gp2{1,1}{m},filesep,res_dir_gp2,'_post',filesep,'con_0',con,'.nii']);
  if ~isempty(tmp)
    files_gp2_cond1{m} = tmp{1,1};
  else
    fprintf('MISSING contrast for: %s\n',list_gp2{1,1}{m})
  end
end

clear matlabbatch
spm_jobman('initcfg')
matlabbatch{1}.spm.stats.factorial_design.dir = {homeDir};

%%
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = files_gp1_cond1';
%%
%%
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = files_gp2_cond1';
%%
matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0;
matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1;
matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0;
matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0;
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;
matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));

%%Change these contrasts to reflect the comparisons that you are interested in...
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'during Intvn > after Intvn';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'during Intvn < after Intvn';
matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.consess{3}.fcon.name = 'During: High > low';
matlabbatch{3}.spm.stats.con.consess{3}.fcon.weights = [1];
matlabbatch{3}.spm.stats.con.consess{3}.fcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.consess{3}.fcon.name = 'During: High > low';
matlabbatch{3}.spm.stats.con.consess{3}.fcon.weights = [1];
matlabbatch{3}.spm.stats.con.consess{3}.fcon.sessrep = 'none';
matlabbatch{3}.spm.stats.con.delete = 0;



savefile = [homeDir,filesep, 'second_level_batch.mat'];
save(savefile, 'matlabbatch');

spm_jobman('run',matlabbatch)
