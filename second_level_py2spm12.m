function [msg] = second_level_py2spm12(comparison_type, independence, output_dir, group_names, file_lists, factors, path_to_covariate_file)

%% Use this to do a second level statistical analysis of the priming data.
%% This will compare two groups, those with Condition A versus those with
%% condition B.
% Co-opted by Brianne Sutton, PhD
% To be adapted for python in the future


% Define global variables including folders/destinations
tool_dir = fileparts(fileparts(which('second_level_py2spm12')));
if isempty(which('glob'))
addpath([tool_dir filesep 'general_utilities']);
end
[spm_home, template_home] = update_script_paths(tool_dir);

if length(glob(strcat(output_dir,filesep,'*'))) < 4 %i.e., would only have 1 file, if the SPM.mat isn't estimated.
    
    % set up spm_jobman and run it
    disp('Initializing jobman')
    spm_jobman('initcfg');
    spm('defaults','fmri');

    % setup the file
    clear matlabbatch;
    clear group?_files;

    %% Statistical comparisons
    if  strcmp(comparison_type,'one_sample')
      matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = file_lists{1}(:);
      matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [group_names{1} ' activation increases'];
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1];
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [group_names{1} ' activation decreases'];
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1];


    elseif strcmp(comparison_type,'two_sample')

      matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = file_lists{1}(:);
      matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = file_lists{2}(:);

      matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [group_names{1} ' > ' group_names{2}];
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [group_names{1} ' < ' group_names{2}];
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
      matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = ['Average effect of condition'];
      matlabbatch{3}.spm.stats.con.consess{3}.tcon.weights = [0.5 0.5];

      %% Full factorial
    elseif strcmp(comparison_type,'full_factorial')


      %Design conditions

      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).name = factors{1};
      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).dept = independence{1}; %one for dependent

      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).levels = 2;

      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).name = factors{2};
      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).levels = 2;
      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).dept = independence{2};
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).levels = [1 1];
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).scans = file_lists{1}(:);
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).levels = [1 2];
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).scans = file_lists{2}(:);
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).levels = [2 1];
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).scans = file_lists{3}(:);
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).levels = [2 2];
      matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).scans = file_lists{4}(:);

      
      matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [ group_names{1}, ' dec. rel. to ',  group_names{2},' vs. ', group_names{3}, ' to ',group_names{4}];
      matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1 -1 1];
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [ group_names{1}, ' inc. rel. to ',  group_names{2},' vs. ', group_names{3}, ' to ',group_names{4}]
      matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1 1 -1];
      matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = [ group_names{1}, ' > ', group_names{2}];
      matlabbatch{3}.spm.stats.con.consess{3}.tcon.weights = [1 -1];
      matlabbatch{3}.spm.stats.con.consess{4}.tcon.name =  [ group_names{3}, ' > ', group_names{4}];
      matlabbatch{3}.spm.stats.con.consess{4}.tcon.weights = [0 0 1 -1];
      matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = [ group_names{1}, ' < ', group_names{2}];
      matlabbatch{3}.spm.stats.con.consess{5}.tcon.weights = [-1 1];
      matlabbatch{3}.spm.stats.con.consess{6}.tcon.name =  [ group_names{3}, ' < ', group_names{4}];
      matlabbatch{3}.spm.stats.con.consess{6}.tcon.weights = [0 0 -1 1];
      matlabbatch{3}.spm.stats.con.consess{7}.tcon.name = [ group_names{1}, ' > ', group_names{3}];
      matlabbatch{3}.spm.stats.con.consess{7}.tcon.weights = [1 0 -1];
      matlabbatch{3}.spm.stats.con.consess{8}.tcon.name =  [ group_names{2}, ' > ', group_names{4}];
      matlabbatch{3}.spm.stats.con.consess{8}.tcon.weights = [0  1 0 -1];
      matlabbatch{3}.spm.stats.con.consess{9}.tcon.name = [ group_names{1}, ' < ', group_names{3}];
      matlabbatch{3}.spm.stats.con.consess{9}.tcon.weights = [-1 0 1];
      matlabbatch{3}.spm.stats.con.consess{10}.tcon.name =  [ group_names{2}, ' < ', group_names{4}];
      matlabbatch{3}.spm.stats.con.consess{10}.tcon.weights = [0 -1 0 1];


    end

    %% output_dir pdf the same for any comparison type
    if exist('path_to_covariate_file','var')
        % Add the covariates to the model/
        matlabbatch{1}.spm.stats.factorial_design.multi_cov.files = {path_to_covariate_file};
        
        % Create the new contrast to check the regressor effects (fx)
        new_consess = length(matlabbatch{3}.spm.stats.con.consess)+1;
        % Number of effects
        num_fx = length(matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights);
        % Number of regressors
        r=load(path_to_covariate_file);
        num_regs = size(r,2);
        % Add regressor contrast
        matlabbatch{3}.spm.stats.con.consess{new_consess}.tcon.name = ['Regressor effect'];
        basic_array = [0 (1/num_regs)]; % 0 for main effects, 1 for regressors
        matlabbatch{3}.spm.stats.con.consess{new_consess}.tcon.weights = repelem(basic_array,[num_fx num_regs]);       
    end
    matlabbatch{1}.spm.stats.factorial_design.dir = { output_dir };

    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));

%         matlabbatch{4}.spm.stats.output_dir.spmmat(1) = cfg_dep('Contrast Manager: SPM.mat File', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
%         matlabbatch{4}.spm.stats.output_dir.conspec.titlestr = '';
%         matlabbatch{4}.spm.stats.output_dir.conspec.contrasts = Inf; % Here you can choose other specific contrasts if desired... 1-by-X array
%         matlabbatch{4}.spm.stats.output_dir.conspec.threshdesc = 'none';
%         matlabbatch{4}.spm.stats.output_dir.conspec.thresh = 0.01;
%         matlabbatch{4}.spm.stats.output_dir.conspec.extent = 25;
%         matlabbatch{4}.spm.stats.output_dir.conspec.mask = struct('contrasts', {}, 'thresh', {}, 'mtype', {});
%         matlabbatch{4}.spm.stats.output_dir.units = 1;
%         matlabbatch{4}.spm.stats.output_dir.print = 'pdf';
%         matlabbatch{4}.spm.stats.output_dir.write.none = 1;


    if ~exist(output_dir,'dir')
      mkdir (output_dir)
    end

    save(fullfile( output_dir, strcat('batch_', comparison_type, '.mat')), 'matlabbatch'); % save the batch instructions


    if ~exist([output_dir,filesep,'SPM.mat'],'file')
      spm_jobman('run',matlabbatch);
      msg = sprintf('\nRan second-level %s\n', output_dir);
    end
  else
    msg = sprintf('\n***Already estimated %s*** \n', output_dir);
end
