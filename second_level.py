import sys
import os
sys.path.append(os.path.expanduser('~/tools/genius'))

# Define the number of groups, comparison types, etc.
n_groups = 2
n_timepts = 2
group_names = ['Diet', 'Exercise']
cons = ['0003','0005','0006,'0008']

if not n_groups || not n_timepts || not group_names:
  var_check = {n_groups:('How many groups are being compared?'), n_timepts:('How many timepoints are there?'), group_names:('What are the group names?'), cons:('Which contrast is being compared?')}
  for k, v in var_check.items():
    if not k:
      k=input(v)




# Define the file lists for each group

  for k=1:length(comp_types)
    clear group*
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
          matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).name = factor2;
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
