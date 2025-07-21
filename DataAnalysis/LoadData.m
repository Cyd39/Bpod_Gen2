function [SessionData, Session_tbl, filePath] = LoadData(varargin)
% LOADDATA - GUI for selecting and loading experimental data files
% 
% Usage:
%   [SessionData, Session_tbl, filePath] = LoadData()
%   [SessionData, Session_tbl, filePath] = LoadData('default_path', path)
%
% Outputs:
%   SessionData - Raw session data structure
%   Session_tbl - Processed session table with timestamps
%   filePath - Path to the loaded file
%
% Example:
%   [SessionData, Session_tbl, filePath] = LoadData();
%   % Then use ExtractTimeStamps to process the data
%   Session_tbl = ExtractTimeStamps(SessionData);

% Parse input arguments
p = inputParser;
addParameter(p, 'default_path', '', @ischar);
parse(p, varargin{:});

defaultPath = "G:\Data\OperantConditioning\Yudi";

% Set default data path
if isempty(defaultPath)
    dataPath = pwd;
else
    dataPath = defaultPath;
end

% If default path is provided, use it
if ~isempty(defaultPath)
    dataPath = defaultPath;
end

% Create main figure
fig = figure('Name', 'Experimental Data Loader', ...
    'Position', [100, 100, 800, 600], ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Resize', 'on', ...
    'NumberTitle', 'off');

% Create main panel
mainPanel = uipanel('Parent', fig, ...
    'Position', [0.02, 0.02, 0.96, 0.96], ...
    'Title', 'Select and Load Data File', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

% File selection panel
filePanel = uipanel('Parent', mainPanel, ...
    'Position', [0.02, 0.6, 0.96, 0.4], ...
    'Title', 'File Selection', ...
    'FontSize', 10);

% Path display
uicontrol('Parent', filePanel, ...
    'Style', 'text', ...
    'String', 'Data Path:', ...
    'Position', [10, 150, 80, 20], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11);

pathText = uicontrol('Parent', filePanel, ...
    'Style', 'edit', ...
    'String', dataPath, ...
    'Position', [100, 150, 500, 20], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11, ...
    'Enable', 'inactive');

% Browse button
uicontrol('Parent', filePanel, ...
    'Style', 'pushbutton', ...
    'String', 'Browse...', ...
    'Position', [620, 150, 80, 20], ...
    'FontSize', 11, ...
    'Callback', @browseCallback);

% File list
uicontrol('Parent', filePanel, ...
    'Style', 'text', ...
    'String', 'Available Files:', ...
    'Position', [10, 120, 100, 20], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11);

fileList = uicontrol('Parent', filePanel, ...
    'Style', 'listbox', ...
    'Position', [10, 10, 690, 110], ...
    'FontSize', 11, ...
    'Callback', @fileListCallback);

% Data preview panel
previewPanel = uipanel('Parent', mainPanel, ...
    'Position', [0.02, 0.35, 0.96, 0.25], ...
    'Title', 'Data Preview', ...
    'FontSize', 10);

% Preview text area
previewText = uicontrol('Parent', previewPanel, ...
    'Style', 'text', ...
    'String', 'Select a file to preview data...', ...
    'Position', [10, 10, 690, 80], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11, ...
    'BackgroundColor', [0.95, 0.95, 0.95]);

% Control panel
controlPanel = uipanel('Parent', mainPanel, ...
    'Position', [0.02, 0.02, 0.96, 0.31], ...
    'Title', 'Controls', ...
    'FontSize', 10);

% Load button
loadBtn = uicontrol('Parent', controlPanel, ...
    'Style', 'pushbutton', ...
    'String', 'Load Data', ...
    'Position', [10, 10, 100, 30], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'Enable', 'off', ...
    'Callback', @loadCallback);

% Status text
statusText = uicontrol('Parent', controlPanel, ...
    'Style', 'text', ...
    'String', 'Ready', ...
    'Position', [120, 15, 400, 20], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 9);

% Progress bar
progressBar = uicontrol('Parent', controlPanel, ...
    'Style', 'text', ...
    'String', '', ...
    'Position', [120, 5, 400, 8], ...
    'BackgroundColor', [0.8, 0.8, 0.8]);

% Initialize variables
selectedFile = '';
SessionData = [];
Session_tbl = [];
filePath = '';

% Update file list
updateFileList();

% Callback functions
function browseCallback(~, ~)
    % Browse for data directory
    newPath = uigetdir(dataPath, 'Select Data Directory');
    if newPath ~= 0
        dataPath = newPath;
        set(pathText, 'String', dataPath);
        updateFileList();
    end
end

function fileListCallback(~, ~)
    % Handle file selection
    if ~isempty(get(fileList, 'String'))
        selectedIdx = get(fileList, 'Value');
        fileNames = get(fileList, 'String');
        if iscell(fileNames)
            selectedFile = fileNames{selectedIdx};
        else
            selectedFile = fileNames;
        end
        previewData();
        set(loadBtn, 'Enable', 'on');
    end
end

function updateFileList()
    % Update the file list with .mat files
    try
        if exist(dataPath, 'dir')
            % Get all .mat files in the directory
            files = dir(fullfile(dataPath, '*.mat'));
            fileNames = {files.name};
            
            if isempty(fileNames)
                set(fileList, 'String', 'No .mat files found');
                set(fileList, 'Value', 1);
            else
                set(fileList, 'String', fileNames);
                set(fileList, 'Value', 1);
                if ~isempty(fileNames)
                    selectedFile = fileNames{1};
                    previewData();
                    set(loadBtn, 'Enable', 'on');
                end
            end
        else
            set(fileList, 'String', 'Directory not found');
            set(fileList, 'Value', 1);
        end
    catch ME
        set(fileList, 'String', ['Error: ' ME.message]);
        set(fileList, 'Value', 1);
    end
end

function previewData()
    % Preview the selected data file
    if ~isempty(selectedFile)
        try
            filePath = fullfile(dataPath, selectedFile);
            set(statusText, 'String', 'Loading preview...');
            
            % Load file info without loading the entire file
            fileInfo = whos('-file', filePath);
            
            % Create preview text
            previewStr = sprintf('File: %s\n', selectedFile);
            previewStr = [previewStr sprintf('Size: %s\n', formatBytes(getfield(dir(filePath), 'bytes')))];
            previewStr = [previewStr sprintf('Variables in file:\n')];
            
            for i = 1:length(fileInfo)
                previewStr = [previewStr sprintf('  %s: %s\n', fileInfo(i).name, formatBytes(fileInfo(i).bytes))];
            end
            
            set(previewText, 'String', previewStr);
            set(statusText, 'String', 'Preview loaded');
            
        catch ME
            set(previewText, 'String', ['Error loading preview: ' ME.message]);
            set(statusText, 'String', 'Error loading preview');
        end
    end
end

function loadCallback(~, ~)
    % Load the selected data file
    if ~isempty(selectedFile)
        try
            filePath = fullfile(dataPath, selectedFile);
            set(statusText, 'String', 'Loading data...');
            set(progressBar, 'BackgroundColor', [0.2, 0.6, 1]);
            
            % Load the data
            loadedData = load(filePath);
            
            % Check if SessionData exists - STRICT CHECK
            if ~isfield(loadedData, 'SessionData')
                % Reset progress bar to error state
                set(progressBar, 'BackgroundColor', [0.8, 0.2, 0.2]);
                set(statusText, 'String', 'Error: No SessionData found in file');
                
                % Show error dialog
                errordlg(sprintf('Error: File "%s" does not contain SessionData variable.\n\nPlease ensure this is a valid experimental data file.', selectedFile), ...
                    'Data format error', 'modal');
                return;
            end
            
            % Validate SessionData structure
            SessionData = loadedData.SessionData;
            
            % Check if SessionData has required fields
            if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
                set(progressBar, 'BackgroundColor', [0.8, 0.2, 0.2]);
                set(statusText, 'String', 'Error: Invalid SessionData structure');
                errordlg(sprintf('Error: SessionData structure is invalid.\n\nFile "%s" does not contain the required fields.', selectedFile), ...
                    'Data structure error', 'modal');
                return;
            end
            
            % Check if there are any trials
            if isempty(SessionData.RawEvents.Trial)
                set(progressBar, 'BackgroundColor', [0.8, 0.2, 0.2]);
                set(statusText, 'String', 'Error: No trials found in SessionData');
                errordlg(sprintf('Error: No trials found in SessionData.\n\nFile "%s" may be empty or corrupted.', selectedFile), ...
                    'Empty data', 'modal');
                return;
            end
            
            % Data is valid, proceed with loading
            set(statusText, 'String', 'Data loaded successfully');
            set(progressBar, 'BackgroundColor', [0.2, 0.8, 0.2]);
            
            % Extract timestamps if ExtractTimeStamps function exists
            if exist('ExtractTimeStamps', 'file') == 2
                try
                    Session_tbl = ExtractTimeStamps(SessionData);
                    set(statusText, 'String', 'Data loaded and timestamps extracted');
                catch ME
                    warning('%s', ['Could not extract timestamps: ', ME.message]);
                    Session_tbl = [];
                end
            else
                Session_tbl = [];
            end
            
            % Display success message and close GUI
            msgbox(sprintf('Data loaded successfully!\nFile: %s\nTrial count: %d', ...
                selectedFile, length(SessionData.RawEvents.Trial)), ...
                'Load successful', 'modal');
            
            % Close the GUI after successful load
            close(fig);
            
        catch ME
            set(statusText, 'String', ['Error loading data: ' ME.message]);
            set(progressBar, 'BackgroundColor', [0.8, 0.2, 0.2]);
            errordlg(['Error loading data: ' ME.message], 'Error', 'modal');
        end
    end
end

function bytes = formatBytes(bytes)
    % Format bytes into human readable string
    if bytes < 1024
        bytes = sprintf('%d B', bytes);
    elseif bytes < 1024^2
        bytes = sprintf('%.1f KB', bytes/1024);
    elseif bytes < 1024^3
        bytes = sprintf('%.1f MB', bytes/1024^2);
    else
        bytes = sprintf('%.1f GB', bytes/1024^3);
    end
end

% Wait for user to close the figure (only if not closed by successful load)
if ishandle(fig)
    waitfor(fig);
end

end
