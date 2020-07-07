function fix_data(fileName)
% Fix 4D Nifti data if the dimensions are corrupted

if (size(fileName, 1) > 1)
    return;
end

[outputDir, fileN, extn] = fileparts(fileName);

if ~strcmpi(extn, '.nii')
    return;
end

spm_get_defaults;

V = spm_vol(fileName);

if (length(V) == 1)
    return;
end

% Load data
data = zeros([V(1).dim(1:3), length(V)]);

for nn = 1:length(V)
    try
        data(:, :, :, nn) = spm_read_vols(V(nn));
    catch
        fileNumber = nn;
        disp(['File number ', num2str(fileNumber), ' cannot be read']);
        fprintf('\n');
        break;
    end
end
% End for loading the data


if exist('fileNumber', 'var')

    % Truncate data
    if (fileNumber > 1)
        V = V([1:fileNumber-1]);
        data = data(:, :, :, [1:fileNumber-1]);
    else
        error('Data is corrupt');
    end


    delete(fileName);

    %newFile = fullfile(outputDir, ['fix_', fileN, extn]);
    disp(['Rewriting file ', fileName]);
    fprintf('\n');

    mx   = -Inf;
    mn   = Inf;
    for i=1:numel(V),
        dat      = data(:, :, :, i);
        dat      = dat(isfinite(dat));
        mx       = max(mx,max(dat(:)));
        mn       = min(mn,min(dat(:)));
    end;

    sf         = max(mx,-mn)/32767;
    ni         = nifti;
    ni.dat     = file_array(fileName, [V(1).dim numel(V)], 'INT16-BE',0,sf,0);
    ni.mat     = V(1).mat;
    ni.mat0    = V(1).mat;
    ni.descrip = '4D image';
    create(ni);
    for i=1:length(V)
        ni.dat(:,:,:,i) = squeeze(data(:, :, :, i));
        spm_get_space([ni.dat.fname ',' num2str(i)], V(i).mat);
    end;

    clear V data;

end
