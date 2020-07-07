function set_spm(ver, link)
%set_spm X OR set_spm(X), where X is spm version (8 or 12)
%sets up path for the specified spm version
%Copyleft 2016, eugene.kronberg@ucdenver.edu
%Revised 2017, brianne
% Revised summer 2019, brianne.sutton@cuanschutz.edu

% The optional link variable allows the attempt to use BK matlab paths and
% utilities from a remote computer.

%convert ver to double if called as set_spm X
if ~exist('ver','var')
    ver = '12';
elseif isnumeric(ver)
    ver = num2str(ver)
end

%% Get presets
old_path = fileparts(which('spm'));
home_dir = regexp(userpath, filesep, 'split');
if any(strcmp(home_dir,'home'))
    home_dir = '/usr/local/MATLAB/tools';
elseif exist('link','var')
    home_dir = '/Volumes/bk/usr/local/MATLAB//tools';  % symbolic link to BK's /usr/local/MATLAB/tools
else
    home_dir = '/opt';
end
%% Determine new SPM paths    
switch ver
    case '8'        
        new_path=fullfile(home_dir, 'spm8');
    case '12'
        new_path=fullfile(home_dir, 'spm12');
    otherwise
        error('SPM version must be 8, 12')
end

%% Complete the switch
if ~strcmp(old_path, new_path)
    rm_spm_path(old_path);
    addpath(new_path);
end

function rm_spm_path(p)
% remove all directories from the path which start with the old path
n = length(p);
z = path;
while true
    [t,r] = strtok(z,':');
    if length(t) >= n && strcmp(t(1:n),p)
        rmpath(t);
    end
    if isempty(r)
        break
    else
        %skip first ':'
        z = r(2:end);
    end
end
