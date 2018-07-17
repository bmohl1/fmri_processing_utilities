function [] = second_level_spm12_mac(contrasts, Groups, list_suffix, comp_types, results_dir, result_suffixes, rd_base, timept_comparison)


  %% Use this to do a second level statistical analysis of the priming data.
  %% This will compare two groups, those with Condition A versus those with
  %% condition B.
  % Co-opted by Brianne Sutton, PhD
  % To be adapted for python in the future


  % Define global variables including folders/destinations
  tool_dir = fileparts(fileparts(which('second_level_spm12')));
  if isempty(which('glob'));
    addpath([tool_dir filesep 'general_utilities']);
  end
  [spm_home, template_home] = update_script_paths(tool_dir);


  if exist('contrasts','var')
    m = cell(1:length(Groups));
    m(:)= {'group'};
    list_main = {m};
    Groups = {Groups};
  else
    %% Priming setup
    comp_types = {'two_sample';'one_sample' ;'one_sample';'two_sample';'one_sample' ;'one_sample'} ;%; 'full_factorial'}'two_sample', 'two_sample'
    result_suffixes = {'','_normResp','','_placebo','_normResp_placebo','_placebo'}; %; '_stimuli_timeptDiffAll'};
    Groups = {{ 'primed','placebo'},{ 'primed','placebo'},{'primed','placebo'},{'placebo', 'placebo'},{'placebo', 'placebo'},{'placebo', 'placebo'}};
    list_main = {{'groupA','groupB'},{'groupA','groupA'},{'groupA','groupA'}, {'groupB','groupB'}, {'groupB','groupB'}, {'groupB','groupB'}};
    list_suffix = {'_all','_normResp_all','_all', '_all','_normResp_all','_all'};
    contrasts = {'con_0003'};

    %% Food pics setup
    comp_types = {'two_sample';'two_sample' ;'two_sample'}; %; 'full_factorial'}'two_sample', 'two_sample'
    result_suffixes = {'_femalesAll_active','_obese_active','_active'};%; '_stimuli_timeptDiffAll'};
    Groups = {{ 'primed_pre','primed_post'},{ 'primed_pre','primed_post'},{ 'primed_pre','primed_post'}};
    list_main = {{'groupA','groupB'},{'groupA','groupB'},{'groupA','groupB'}};
    list_suffix = {'_femaleAll','_obese','_all'};
    %contrasts = { 'con_0003_postInt_minus_preInt', 'con_0005_postInt_minus_preInt','con_0008_postInt_minus_preInt' }; % also determines the folder names for results
    contrasts = {'con_0003', 'con_0004','con_0005', 'con_0008', 'con_0009'};
    results_dir = spm_select(1,'dir','Where is the results directory?');
  end

  if ~exist('rd_base','var')
    rd_base = 'fp_resultsArt';
  end

  if ~exist('timept_comparison','var')
    timept_comparison = 'no';
  end

  % Good defaults
  task_results_dir = rd_base;
  second_task_results_dir = rd_base;
  factor1 = 'Sample factor';

  % However, sometimes, the comparisons will be time-dependent...
  if strncmpi('y',timept_comparison,1)
  %  second_task_results_dir = strcat(rd_base, "_post");
  second_task_results_dir = strcat(rd_base);
    factor1 = 'Timepoint';
  end

  rValue = strfind(results_dir, 'result');
  results_top_dir = results_dir(1:rValue-2);
  [root_dir task] = fileparts(results_top_dir);
  img_dir = glob(['/home/data/images/',task(1:4),'*']);

  %groups = {'primed_f','control_f','primed_m','control_m'};
  %groups={'primed_pre','primed_post','placebo_pre','placebo_post'};
  %groups={'primed_preCon8','primed_postCon8','primed_preCon5','primed_postCon5'};


  for k=1:length(comp_types)
    clear group*
    group_properties = cell(1:length(Groups));
    for g = 1:length(Groups);
      group_properties{g}.name = Groups{k}{g};
    end

    groupA_name = Groups{k}{1};

    groupA_def = glob([results_top_dir filesep list_main{k}{1} list_suffix{1} '*']); %added the cell ref to suffix for the python batch script
    groupA = textscan(fopen(groupA_def{1}), '%s');

    if length(Groups{k}) > 1
      groupB_name = Groups{k}{2};
      groupB_def = glob([results_top_dir filesep list_main{k}{2} list_suffix{2} '*']);
      groupB = textscan(fopen(groupB_def{1}), '%s');
    end

    if length(Groups{k}) > 2
      groupC_name = Groups{k}{3};
      groupD_name = Groups{k}{4};
      groupC_def = glob([results_top_dir filesep list_main{k}{3} list_suffix{3} '*' ]);
      groupC = textscan(fopen(groupC_def{1}), '%s');
      groupD_def = glob([results_top_dir filesep list_main{k}{4} list_suffix{4} '*' ]);
      groupD = textscan(fopen(groupD_def{1}), '%s');
    end
    fclose('all');

    %%quick switch for testing opposite groups in factorial design
    if strcmpi(timept_comparison,'y')
      groupA = groupC;
      groupB = groupD;
      groupA_name = groupC_name;
      groupB_name = groupD_name;
    end


    cwd = pwd; % for clean-up
    comp_type = comp_types{k};
    result_suffix = result_suffixes{k};
    for j=1:length(contrasts)
      results =strcat(results_dir, filesep, comp_type, '_', contrasts{j},result_suffix); %_postMinusPre_obeseArt'

      if length(glob(strcat(results,filesep,'*'))) < 4 %i.e., would only have 1 file, if the SPM.mat isn't estimated.
        % set up spm_jobman and run it
        disp('Initializing jobman')
        spm_jobman('initcfg');
        spm('defaults','fmri');

        % setup the file
        clear matlabbatch;
        clear group?_files;

        % In python, turn this into a dictionary
        for i=1:length(groupA{:})
          subj_file = glob(char(strcat( img_dir, groupA{1,1}{i}, '*', filesep, task_results_dir, filesep, contrasts{j}, '.nii')));
          groupA_files{i} = [strcat(subj_file{1},',1')];
        end

        try ~isempty(groupA_files);
          groupA_set{1,1} = groupA_files';
        catch
          disp('Did not properly locate files for analysis. Please check your list file.')
        end

        if length(Groups{k}) > 1
          for i=1:length(groupB{:})
            subj_file = glob(char(strcat( img_dir, groupB{1,1}{i}, '*', filesep, second_task_results_dir, filesep, contrasts{j}, '.nii')));
            groupB_files{i} = [strcat(subj_file{1},',1')];
            groupB_set{1,1} = groupB_files';
          end
        end

        if length(Groups{k}) > 2;
          for i=1:length(groupC{:})
            subj_file = glob(char(strcat( img_dir, groupC{1,1}{i}, '*', filesep, task_results_dir, filesep, contrasts{j}, '.nii')));
            groupC_files{i} = [strcat(subj_file{1},',1')];
          end

          for i = 1:length(groupD{:})
            subj_file = glob(char(strcat( img_dir, groupD{1,1}{i}, '*', filesep, second_task_results_dir, filesep, contrasts{j}, '.nii')));
            groupD_files{i} = [strcat(subj_file{1},',1')];
          end
          groupC_set{1,1} = groupC_files';
          groupD_set{1,1} = groupD_files';
        end

        %% Two sample
        if  strcmp(comp_type,'one_sample');
          if strncmpi('y',timept_comparison,1)
            matlabbatch{1}.spm.stats.factorial_design.des.t1.dept = 1; % not independent
          end
          matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = groupA_set{1};
          matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [groupA_name ' activation increases'];
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1];
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [groupA_name ' activation decreases'];
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1];


        elseif strcmp(comp_type,'two_sample');
            if strncmpi('y',timept_comparison,1)
              matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 1; % not independent
            end
          matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = groupA_set{1};
          matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = groupB_set{1};

          matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [groupA_name ' > ' groupB_name];
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [groupA_name ' < ' groupB_name];
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];

          %% Full factorial
        elseif strcmp(comp_type,'full_factorial')


          %Design conditions
          if strncmpi('y',timept_comparison,1)
            matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).dept = 1; %one for dependent
          end

          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).name = factor1;
          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).levels = 2;
          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).name = 'experimental manipulation';
          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).levels = 2;
          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).dept = 0;

          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).levels = [1 1];
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).scans = groupA_set{1};
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).levels = [1 2];
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).scans = groupB_set{1};
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).levels = [2 1];
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).scans = groupC_set{1};
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).levels = [2 2];
          matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).scans = groupD_set{1};

          matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [contrasts{j}, ': ', groupA_name, ' dec. rel. to ',  groupB_name,' vs. ', groupC_name, ' to ',groupD_name];
          matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1 -1 1];
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [contrasts{j}, ': ', groupA_name, ' inc. rel. to ',  groupB_name,' vs. ', groupC_name, ' to ',groupD_name]
          matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1 1 -1];
          matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = [contrasts{j}, ': ', groupA_name, ' > ', groupC_name];
          matlabbatch{3}.spm.stats.con.consess{3}.tcon.weights = [1 0 -1];
          matlabbatch{3}.spm.stats.con.consess{4}.tcon.name =  [contrasts{j}, ': ', groupB_name, ' > ', groupD_name];
          matlabbatch{3}.spm.stats.con.consess{4}.tcon.weights = [0 1 0 -1];
          matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = [contrasts{j}, ': ', groupA_name, ' < ', groupC_name];
          matlabbatch{3}.spm.stats.con.consess{5}.tcon.weights = [-1 0 1];
          matlabbatch{3}.spm.stats.con.consess{6}.tcon.name =  [contrasts{j}, ': ', groupB_name, ' < ', groupD_name];
          matlabbatch{3}.spm.stats.con.consess{6}.tcon.weights = [0 -1 0 1];
          matlabbatch{3}.spm.stats.con.consess{7}.tcon.name = [contrasts{j}, ': ', groupA_name, ' > ', groupB_name];
          matlabbatch{3}.spm.stats.con.consess{7}.tcon.weights = [1 -1];
          matlabbatch{3}.spm.stats.con.consess{8}.tcon.name =  [contrasts{j}, ': ', groupC_name, ' > ', groupD_name];
          matlabbatch{3}.spm.stats.con.consess{8}.tcon.weights = [0 0 1 -1];
          matlabbatch{3}.spm.stats.con.consess{9}.tcon.name = [contrasts{j}, ': ', groupA_name, ' < ', groupB_name];
          matlabbatch{3}.spm.stats.con.consess{9}.tcon.weights = [-1 1];
          matlabbatch{3}.spm.stats.con.consess{10}.tcon.name =  [contrasts{j}, ':', groupC_name, ' < ', groupD_name];
          matlabbatch{3}.spm.stats.con.consess{10}.tcon.weights = [0 0 -1 1];


        end

        %% Results pdf the same for any comparison type
        matlabbatch{1}.spm.stats.factorial_design.dir = { results };

        matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));

        %         matlabbatch{4}.spm.stats.results.spmmat(1) = cfg_dep('Contrast Manager: SPM.mat File', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
        %         matlabbatch{4}.spm.stats.results.conspec.titlestr = '';
        %         matlabbatch{4}.spm.stats.results.conspec.contrasts = Inf; % Here you can choose other specific contrasts if desired... 1-by-X array
        %         matlabbatch{4}.spm.stats.results.conspec.threshdesc = 'none';
        %         matlabbatch{4}.spm.stats.results.conspec.thresh = 0.01;
        %         matlabbatch{4}.spm.stats.results.conspec.extent = 25;
        %         matlabbatch{4}.spm.stats.results.conspec.mask = struct('contrasts', {}, 'thresh', {}, 'mtype', {});
        %         matlabbatch{4}.spm.stats.results.units = 1;
        %         matlabbatch{4}.spm.stats.results.print = 'pdf';
        %         matlabbatch{4}.spm.stats.results.write.none = 1;


        if ~exist(results,'dir')
          mkdir (results)
        end

        save(strcat( results, '/batch_', contrasts{j}, '.mat'), 'matlabbatch'); % save the batch instructions

        fprintf('Instructions for %s written.\n', contrasts{j});

        if ~exist([results,filesep,'SPM.mat'],'file')
          spm_jobman('run',matlabbatch);
        end

        fprintf('Completed running the analysis for %s.\n', contrasts{j});
      else
        fprintf('Already estimated %s\n', results);

      end;

    end;
  end





  %% finally, clean up
  cd(cwd);
