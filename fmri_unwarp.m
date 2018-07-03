function [subj] = fmri_unwarp (all_proc_files,subj, discard_dummies, ver)
% Purpose: subroutine of preproc_fmri that handles requests for geometric distortion unwarping
% Author: Brianne Sutton, PhD
% 2017

display('Running fmri_unwarp');

global special_templates subj_t1_dir subj_t1_file;
raw_dir  = pwd; %the functions calling this one should have cd'd into raw_dir
parts    = textscan(raw_dir,'%s','Delimiter','/');
subjIx   = strfind(parts{:},subj);
ix       = find(~cellfun(@isempty,subjIx)); %locates the first match for the subj name
subj_dir = fullfile(parts{1,1}{1:ix});
subj_dir = [filesep, subj_dir];
%define the length of the experiment (should come up with the
%same number either way)
trs = length(all_proc_files); %If no STC, this will have 4 extra volumes
selected_proc_files = {};
if trs == 0
    disp('Hmmm... not finding the necessary files. Check search criteria in preproc_fmri')
elseif trs < 2; %need to split out nii file with ",number_of_volume"
    trs = length(spm_vol(all_proc_files{1,1})); % accommodates the conventional naming, even though the first four volumes are empty
    all_proc_files = char(all_proc_files{1,1});
    if eq('discard_dummies',1)
        for x = 5:(trs);
            selected_proc_files{x} = [strcat(all_proc_files,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
        end
        selected_proc_files = selected_proc_files(5:end); %discards the first four scans
    end
    mean_img = rdir(strcat('mean*',',5')); %so the image isn't empty

else %individual files for the volumes exist and need to be loaded sequentially
    selected_proc_files = all_proc_files';
    mean_img = rdir(strcat('mean*')); %so the image isn't empty
end

if ~isempty(selected_proc_files)
    fprintf('Found %d images to unwarp.\n', length(selected_proc_files))
else
    fprintf('Not locating files for %s\nfmri_unwarp: ',all_proc_files);
    return
end

scan_set = [];
scan_set{1,1}= selected_proc_files; % since it is going by single subj
cd(subj_dir);

clear matlabbatch
spm_jobman('initcfg');
save_folder = [];
save_folder{1,1} = [raw_dir];
unwarp_check = rdir(strcat(raw_dir,filesep,'u*nii'));


if length(unwarp_check) < 1;
    savefile = [subj_dir,filesep,'unwarp_' subj '.mat'];
    matlabbatch{1}.spm.spatial.realignunwarp.data.scans = scan_set{1,1};
%%
matlabbatch{1}.spm.spatial.realignunwarp.data.pmscan = '';
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.quality = 0.9;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.sep = 4;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.fwhm = 5;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.rtm = 0;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.einterp = 2;
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.ewrap = [0 0 0];
matlabbatch{1}.spm.spatial.realignunwarp.eoptions.weight = '';
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.basfcn = [12 12];
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.regorder = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.lambda = 100000;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.jm = 0;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.fot = [4 5];
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.sot = [];
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.uwfwhm = 4;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.rem = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.noi = 5;
matlabbatch{1}.spm.spatial.realignunwarp.uweoptions.expround = 'Average';
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.uwwhich = [2 1];
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.rinterp = 4;
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.mask = 1;
matlabbatch{1}.spm.spatial.realignunwarp.uwroptions.prefix = 'u';
     save(savefile, 'matlabbatch');

%% Run the batch
spm_jobman('run',matlabbatch)
disp('unwarping complete')
end
