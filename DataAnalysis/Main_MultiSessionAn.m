%% 1. load behavioural data from multiple files
clearvars

% use current directory
defaultDataPath = pwd;
% Alternative: Set default path for file selection dialog
%defaultDataPath = '';  % Change this to default path

% Check if default path exists, if not use current directory
if ~exist(defaultDataPath, 'dir')
    warning(['Default path does not exist: ' defaultDataPath '. Using current directory instead.']);
    defaultDataPath = pwd;
end

% Initialize file list
selectedFiles = {};
currentPath = defaultDataPath;

% Loop to select multiple files from different directories
fprintf('=== File Selection ===\n');
fprintf('You can select multiple files at once (hold Ctrl/Cmd to select multiple)\n');

fileCount = 0;
while true
    % Select files (supports multiple selection)
    [filename, filepath, ~] = uigetfile('*.mat', ...
        sprintf('Select file(s) (Cancel to finish) - Currently %d file(s) selected', fileCount), ...
        currentPath, ...
        'MultiSelect', 'on');
    
    % Check if user canceled
    if isequal(filename, 0) || isequal(filepath, 0)
        if fileCount == 0
            fprintf('No files selected. Exiting...\n');
            return;
        else
            fprintf('\nFinished selecting files. Total: %d file(s)\n\n', fileCount);
            break;
        end
    end
    
    % Handle both single file (string) and multiple files (cell array)
    if ischar(filename)
        % Single file selected - convert to cell array for uniform processing
        filenames = {filename};
    else
        % Multiple files selected - filename is already a cell array
        filenames = filename;
    end
    
    % Add all selected files to list
    for i = 1:length(filenames)
        fileCount = fileCount + 1;
        fullPath = fullfile(filepath, filenames{i});
        selectedFiles{fileCount} = fullPath;
        fprintf('File %d: %s\n', fileCount, fullPath);
    end
    currentPath = filepath; % Remember last directory for next selection
    
    % Ask if user wants to select more files
    if isscalar(filenames)
        msg = sprintf('File %d selected:\n%s\n\nDo you want to select more files?', ...
            fileCount, fullPath);
    else
        msg = sprintf('%d files selected (total: %d)\n\nDo you want to select more files?', ...
            length(filenames), fileCount);
    end
    
    choice = questdlg(msg, ...
        'File Selection', ...
        'Yes', 'No', 'Yes');
    
    if strcmp(choice, 'No')
        fprintf('\nFinished selecting files. Total: %d file(s)\n\n', fileCount);
        break;
    end
end

% Get number of files
numFiles = length(selectedFiles);
disp(['Selected ' num2str(numFiles) ' file(s) to process']);

%% Analysis of each session 
% Initialize table


for fileIdx = 1:numFiles
    absolute_path = selectedFiles{fileIdx};
    
    % Get filepath and filename from full path
    [filepath, filename, ~] = fileparts(absolute_path);
    filename = [filename, '.mat'];  % Add extension back for display
    
    % Get filename without extension
    [~, name_only, ~] = fileparts(absolute_path);
    
    % Display file information
    disp('========================================');
    disp(['Processing file ' num2str(fileIdx) ' of ' num2str(numFiles) ': ' filename]);
    disp(['File path: ' absolute_path]);
    
    % Load file based on file type
    [~, ~, extension] = fileparts(filename);
    
    switch lower(extension)
        case {'.mat'}
            % Load MAT file
            load(absolute_path);
            disp('MAT file loaded successfully');
        otherwise
            % For other file types
            warning(['Unsupported file type: ' extension '. Skipping this file.']);
            continue;  % Skip to next file
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp(['File size: ' num2str(file_info.bytes) ' bytes']);
    disp('Behavior Data loaded');

end


%% Store session list and analysis results into a table
% store as csv


% Store as table in .mat


%% Analysis functions
%