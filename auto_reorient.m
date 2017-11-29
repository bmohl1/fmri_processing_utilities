function auto_reorient(p, scan_type)
set_spm_bmm('8');
spmDir=which('spm');
spmDir=spmDir(1:end-5);
%scan_type = 'fmri';
if exist('scan_type')
    tmpl=[spmDir 'canonical/EPI.nii'];
else
    tmpl=[spmDir 'canonical/avg152T1.nii'];

end
vg=spm_vol(tmpl);
flags.regtype='rigid';
if ~exist('p','var')
    input=spm_select(inf,'image');
    input = cellstr(input);
else
    input = cellstr(p);
end

for j = 1:length(input)
    p = input{j};
[subjDir subj] = fileparts(p);
touchFile = [subjDir, filesep, 'touch_acpc.txt'];
if ~exist (touchFile, 'file')
    cd (subjDir)
    for i=1:size(p,1)
        f=strtrim(p(i,:));
        spm_smooth(f,'temp.nii',[12 12 12]);
        vf=spm_vol('temp.nii');
        [M,scal] = spm_affreg(vg,vf(1),flags); %BMM added vf(1), because was loading with duplicates of the image.
        M3=M(1:3,1:3);
        [u s v]=svd(M3);
        M3=u*v';
        M(1:3,1:3)=M3;
        N=nifti(f);
        N.mat=M*N.mat;
        fprintf('Creating shifted matrix:%s\n', subj);
        create(N);
    end
        delete('temp.nii');
        fclose(fopen('touch_acpc.txt', 'w'));
else
    fprintf('%s was aligned\n', subj);
end
end

