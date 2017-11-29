function [subjs] = segmentation_spm8(subjs, child_templates)
% Purpose: Run the DARTEL-based new segmentation from SPM.  The forward
% deformations are saved so that the co-registered EPIs can be transformed
% into standard space with relative few issues
%
% Future part of modular preprocessing pipeline
% Author: Brianne Mohl,PhD
% Date: March 2016


%%
set_spm 8;
spm_home=which('spm');
template_home = '/Volumes/Data_2/Brianne/tools/templates';
addpath('/Volumes/Data_2/Brianne/tools');
%% Grab the files
switch nargin
    case 1
        [cwd,pth_subjdirs] = file_selector(subjs);
    case 0
        [cwd,pth_subjdirs] = file_selector;
end

switch nargin
    case 2
        fprintf('Child templates? %s\n',child_templates);
    otherwise
        prompt = 'Use child templates?';
        title = 'Templates';
        x = questdlg(prompt, title ,'Yes', 'No', 'No'); %order of arguments matters
        if strncmpi(x,'y',1)
            child_templates = 'yes';
        end
end
cd (cwd);

for nSubj = 1:length(pth_subjdirs)
    subj_pth = pth_subjdirs{nSubj};
    [proj_dir subj ~] = fileparts(subj_pth(1,1:end-1));
    subj_prefix = (subj(1:end-1)); %Need to back off one character to accomodate finding the T1
    
    fprintf('Running segmentation_spm8 on %s \n', subj)
    
    cd(subj_pth)
    
    %% T1 Coregistration
    [subj_t1_dir, subj_t1_file, t1_ext] = locate_t1(subj_pth);
    
    y_img = dir(strcat(subj_t1_dir,'y_*',subj,'*nii'));
    
    if isempty(y_img) && exist('subj_t1_file');
        
        display('Initiating new segmentation.')
        
        %%
        clear matlabbatch
        spm_jobman('initcfg');
        t1_raw_input = []; %Don't know why, but batch req's cell with the file name (t1_name) as one of potentially many cells. Follow this template to get the array/cell structure correct.bmm
        t1_name = [strcat(subj_t1_dir,filesep,subj_t1_file,',1')];
        t1_raw_input{1,1} = t1_name;
        
        templates = {};
        if exist ('child_templates')
            for i = 1:6;
                templates{1,i} = {strcat(template_home,filesep,'genR_Template_',int2str(i),'_IXI550_MNI152.nii')};
            end
        else
            for i = 1:6;
                templates{1,i} = {strcat(template_home,filesep,'Template_',int2str(i),'_IXI550_MNI152.nii')};
            end
        end
        disp('Entering batch variables')
        %insert the matlabbatch variables for the new segment
        matlabbatch{1}.spm.tools.preproc8.channel.vols = t1_raw_input;
        matlabbatch{1}.spm.tools.preproc8.channel.biasreg = 0.0001;
        matlabbatch{1}.spm.tools.preproc8.channel.biasfwhm = 60;
        matlabbatch{1}.spm.tools.preproc8.channel.write = [0 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(1).tpm = templates{1,1};
        matlabbatch{1}.spm.tools.preproc8.tissue(1).ngaus = 2;
        matlabbatch{1}.spm.tools.preproc8.tissue(1).native = [1 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(1).warped = [0 1];
        matlabbatch{1}.spm.tools.preproc8.tissue(2).tpm = templates{1,2};
        matlabbatch{1}.spm.tools.preproc8.tissue(2).ngaus = 2;
        matlabbatch{1}.spm.tools.preproc8.tissue(2).native = [1 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(2).warped = [0 1];
        matlabbatch{1}.spm.tools.preproc8.tissue(3).tpm = templates{1,3};
        matlabbatch{1}.spm.tools.preproc8.tissue(3).ngaus = 2;
        matlabbatch{1}.spm.tools.preproc8.tissue(3).native = [1 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(3).warped = [0 1];
        matlabbatch{1}.spm.tools.preproc8.tissue(4).tpm = templates{1,4};
        matlabbatch{1}.spm.tools.preproc8.tissue(4).ngaus = 3;
        matlabbatch{1}.spm.tools.preproc8.tissue(4).native = [1 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(4).warped = [0 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(5).tpm = templates{1,5};
        matlabbatch{1}.spm.tools.preproc8.tissue(5).ngaus = 4;
        matlabbatch{1}.spm.tools.preproc8.tissue(5).native = [1 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(5).warped = [0 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(6).tpm = templates{1,6};
        matlabbatch{1}.spm.tools.preproc8.tissue(6).ngaus = 2;
        matlabbatch{1}.spm.tools.preproc8.tissue(6).native = [0 0];
        matlabbatch{1}.spm.tools.preproc8.tissue(6).warped = [0 0];
        matlabbatch{1}.spm.tools.preproc8.warp.reg = 4;
        matlabbatch{1}.spm.tools.preproc8.warp.affreg = 'mni';
        matlabbatch{1}.spm.tools.preproc8.warp.samp = 3;
        matlabbatch{1}.spm.tools.preproc8.warp.write = [1 1];
        
        
        savefile = strcat(subj_pth,filesep,'unifiedSegmentation_',subj);
        save(savefile,'matlabbatch');
        % run batch
        spm_jobman('run',matlabbatch)
        disp('Completed unified segmentation')
    else
        display('unified segmentation already done. Moving along.')
        continue
    end
end
return
end
