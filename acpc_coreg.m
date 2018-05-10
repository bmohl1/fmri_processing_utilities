function acpc_coreg(images)
% Purpose: Find the rough estimate of AC-PC, en batch
% Purpose2: Specifically crafted to try with the ABCD dataset
% Date: 03.22.18
% Author: Brianne Sutton, PhD
% This script tries to set AC-PC with 2 steps.
% 1. Set origin to center (utilizing a script by F. Yamashita)
% 2. Use spm_affreg per Carlton Chu's adaptation of Ashburner's spm8
% scripts.

set_spm % custom script, which cleans up the path to include spm12b calls only
spmDir=fileparts(which('spm'));
if isempty(which('cfg_getfile'))
    disp('Updating path')
    addpath([spmDir,filesep, 'matlabbatch']);
    addpath([spmDir,filesep,'toolbox/OldNorm']);
end

%scan_type = 'fmri';
if exist('scan_type')
    template=[spmDir filesep 'toolbox/OldNorm/EPI.nii'];
else
    template=[spmDir filesep 'canonical/avg152T1.nii'];
end
standardTemplate=spm_vol(template);
flags.regtype='mni';
trial = 'acpcmni_';
%% Select images
if ~exist('images','var')
    imglist=spm_select(Inf,'image','Choose MRI you want to set AC-PC');
else
    imglist = cellstr(images);
end

%% Set the origin to the center of the image
% This part is written by Fumio Yamashita.
for i=1:size(imglist,1)
    img = char(strrep(deblank(imglist(i,:)),",1",""));
    [subjDir subjImg ext] = fileparts(img);
    touchFile = [subjDir, filesep, 'touch_acpc.txt'];
    
    if ~exist (touchFile, 'file')
        cd (subjDir)
        copyfile(img, [trial,subjImg, ext]);
        cImg = [subjDir, filesep, trial,subjImg, ext];
        inputImg = spm_vol(cImg); %load parameters
        vs = inputImg.mat\eye(4); %throw away line just to define vs?
        vs(1:3,4) = (inputImg.dim+1)/2;
        %vs(2,4) = vs(2,4)-15;
        %vs(3,4) = vs(3,4)+5; %the origin was too low
        spm_get_space(inputImg.fname,inv(vs)); %inv has to be there or the neg values leave the coreg with no mutual information
        
        fprintf('Smoothing %s\n',cImg);
        spm_smooth(cImg,'temp.nii',[12 12 12]);
        vol2manipulate=spm_vol('temp.nii');
        [M,scal] = spm_affreg(standardTemplate,vol2manipulate(1),flags);
        
        %% Chu's original. Definitely needed if flag is mni; may not be needed if flag is rigid
        M3=M(1:3,1:3);
        [u s v]=svd(M3);
        M3=u*v';
        M(1:3,1:3)=M3;

        N=nifti(cImg);
        N.mat0 =N.mat; %adapting the nii convention of method 2 and method 3, so that N.mat is the "method 3 -Aligned to sform, standard space". This mat0 is just the original, but it was too difficult to adapt to a different fieldname... the object isn't actually a structure
        N.mat=M*N.mat; 
        fprintf('Creating shifted matrix:%s\n\n', cImg);
        create(N); %should overwrite header
        delete('temp.nii');
        fclose(fopen('touch_acpc.txt', 'w'));
    else
        fprintf('%s was aligned\n', subjImg);
    end
    
end
