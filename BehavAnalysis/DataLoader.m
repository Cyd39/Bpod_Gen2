% data loader for Bpod experimental data
classdef DataLoader < handle
    properties
        Config
        SupportedFormats
        DefaultDataPath
    end
    
    methods
        function obj = DataLoader(config)
            obj.Config = config;
            obj.SupportedFormats = {'.mat'};
            obj.DefaultDataPath = "G:\Data\OperantConditioning\Yudi";
        end
        
        function [SessionData, Session_tbl, filePath] = loadSessionData(obj, sessionPath)
            % load Bpod session data with GUI selection
            if nargin < 2 || isempty(sessionPath)
                [SessionData, Session_tbl, filePath] = obj.loadDataWithGUI();
            else
                [SessionData, Session_tbl, filePath] = obj.loadDataFromPath(sessionPath);
            end
        end
        
        function [SessionData, Session_tbl, filePath] = loadDataWithGUI(obj)
            % GUI-based data loading (similar to DataAnalysis/LoadData.m)
            dataPath = obj.DefaultDataPath;
            
            % Create main figure
            fig = figure('Name', 'Bpod Data Loader', ...
                'Position', [100, 100, 800, 600], ...
                'MenuBar', 'none', 'ToolBar', 'none', ...
                'Resize', 'on', 'NumberTitle', 'off');
            
            % Create main panel
            mainPanel = uipanel('Parent', fig, ...
                'Position', [0.02, 0.02, 0.96, 0.96], ...
                'Title', 'Select and Load Bpod Data File', ...
                'FontSize', 12, 'FontWeight', 'bold');
            
            % File selection panel
            filePanel = uipanel('Parent', mainPanel, ...
                'Position', [0.02, 0.6, 0.96, 0.4], ...
                'Title', 'File Selection', 'FontSize', 10);
            
            % Path display
            uicontrol('Parent', filePanel, 'Style', 'text', ...
                'String', 'Data Path:', 'Position', [10, 150, 80, 20], ...
                'HorizontalAlignment', 'left', 'FontSize', 11);
            
            pathText = uicontrol('Parent', filePanel, 'Style', 'edit', ...
                'String', dataPath, 'Position', [100, 150, 500, 20], ...
                'HorizontalAlignment', 'left', 'FontSize', 11, 'Enable', 'inactive');
            
            % Browse button
            uicontrol('Parent', filePanel, 'Style', 'pushbutton', ...
                'String', 'Browse...', 'Position', [620, 150, 80, 20], ...
                'FontSize', 11, 'Callback', @browseCallback);
            
            % File list
            uicontrol('Parent', filePanel, 'Style', 'text', ...
                'String', 'Available Files:', 'Position', [10, 120, 100, 20], ...
                'HorizontalAlignment', 'left', 'FontSize', 11);
            
            fileList = uicontrol('Parent', filePanel, 'Style', 'listbox', ...
                'Position', [10, 10, 690, 110], 'FontSize', 11, ...
                'Callback', @fileListCallback);
            
            % Control panel
            controlPanel = uipanel('Parent', mainPanel, ...
                'Position', [0.02, 0.02, 0.96, 0.55], ...
                'Title', 'Controls', 'FontSize', 10);
            
            % Load button
            loadBtn = uicontrol('Parent', controlPanel, ...
                'Style', 'pushbutton', 'String', 'Load Data', ...
                'Position', [10, 10, 100, 30], 'FontSize', 10, ...
                'FontWeight', 'bold', 'Enable', 'off', 'Callback', @loadCallback);
            
            % Status text
            statusText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
                'String', 'Ready', 'Position', [120, 15, 400, 20], ...
                'HorizontalAlignment', 'left', 'FontSize', 9);
            
            % Initialize variables
            selectedFile = '';
            SessionData = [];
            Session_tbl = [];
            filePath = '';
            
            % Update file list
            updateFileList();
            
            % Callback functions
            function browseCallback(~, ~)
                newPath = uigetdir(dataPath, 'Select Data Directory');
                if newPath ~= 0
                    dataPath = newPath;
                    set(pathText, 'String', dataPath);
                    updateFileList();
                end
            end
            
            function fileListCallback(~, ~)
                if ~isempty(get(fileList, 'String'))
                    selectedIdx = get(fileList, 'Value');
                    fileNames = get(fileList, 'String');
                    if iscell(fileNames)
                        selectedFile = fileNames{selectedIdx};
                    else
                        selectedFile = fileNames;
                    end
                    set(loadBtn, 'Enable', 'on');
                end
            end
            
            function updateFileList()
                try
                    if exist(dataPath, 'dir')
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
            
            function loadCallback(~, ~)
                if ~isempty(selectedFile)
                    try
                        filePath = fullfile(dataPath, selectedFile);
                        set(statusText, 'String', 'Loading data...');
                        
                        % Load the data
                        loadedData = load(filePath);
                        
                        % Validate SessionData
                        if ~isfield(loadedData, 'SessionData')
                            set(statusText, 'String', 'Error: No SessionData found');
                            errordlg('Error: File does not contain SessionData variable.', ...
                                'Data format error', 'modal');
                            return;
                        end
                        
                        SessionData = loadedData.SessionData;
                        
                        % Validate SessionData structure
                        if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
                            set(statusText, 'String', 'Error: Invalid SessionData structure');
                            errordlg('Error: SessionData structure is invalid.', ...
                                'Data structure error', 'modal');
                            return;
                        end
                        
                        if isempty(SessionData.RawEvents.Trial)
                            set(statusText, 'String', 'Error: No trials found');
                            errordlg('Error: No trials found in SessionData.', ...
                                'Empty data', 'modal');
                            return;
                        end
                        
                        % Extract timestamps
                        Session_tbl = obj.extractTimeStamps(SessionData);
                        
                        set(statusText, 'String', 'Data loaded successfully');
                        
                        % Display success message and close GUI
                        msgbox(sprintf('Data loaded successfully!\nFile: %s\nTrial count: %d', ...
                            selectedFile, length(SessionData.RawEvents.Trial)), ...
                            'Load successful', 'modal');
                        
                        close(fig);
                        
                    catch ME
                        set(statusText, 'String', ['Error loading data: ' ME.message]);
                        errordlg(['Error loading data: ' ME.message], 'Error', 'modal');
                    end
                end
            end
            
            % Wait for user to close the figure
            if ishandle(fig)
                waitfor(fig);
            end
        end
        
        function [SessionData, Session_tbl, filePath] = loadDataFromPath(obj, sessionPath)
            % Load data from specific path
            try
                loadedData = load(sessionPath);
                
                if ~isfield(loadedData, 'SessionData')
                    error('File does not contain SessionData variable');
                end
                
                SessionData = loadedData.SessionData;
                Session_tbl = obj.extractTimeStamps(SessionData);
                filePath = sessionPath;
                
            catch ME
                error('Failed to load data from %s: %s', sessionPath, ME.message);
            end
        end
        
        function Session_tbl = extractTimeStamps(obj, SessionData)
            % Extract timestamps from SessionData (similar to DataAnalysis/ExtractTimeStamps.m)
            Session_struct = [SessionData.RawEvents.Trial{:}];
            
            % States 
            Session_states = [Session_struct.States];
            Session_state_tbl = struct2table(Session_states);
            
            % Events to extract
            events_to_store = {'BNC1High','BNC1Low'};
            event_labels = {'LickOn','LickOff'};
            
            num_C = numel(Session_struct);
            num_fields = numel(events_to_store);
            
            % Preallocate output
            out = cell(num_C, num_fields);
            
            for idx = 1:num_C
                for j = 1:num_fields
                    fname = events_to_store{j};
                    if isfield(Session_struct(idx).Events, fname)
                        out{idx, j} = Session_struct(idx).Events.(fname);
                    else
                        out{idx, j} = NaN;
                    end
                end
            end
            
            Session_tbl = [SessionData.StimTable, Session_state_tbl, cell2table(out, 'VariableNames', event_labels)];
        end
        
        function trialData = loadTrialData(obj, trialPath)
            % load single trial data (for real-time analysis)
            trialData = obj.loadSingleFile(trialPath);
        end
        
        function dataFiles = findDataFiles(obj, sessionPath)
            % Find all data files in session path
            if exist(sessionPath, 'dir')
                files = dir(fullfile(sessionPath, '*.mat'));
                dataFiles = {files.name};
            else
                dataFiles = {};
            end
        end
        
        function fileData = loadSingleFile(obj, filePath)
            % Load single file
            fileData = load(filePath);
        end
        
        function mergedData = mergeData(obj, ~, fileData)
            % Merge data from multiple files
            % For now, just return the new file data
            % Can be enhanced to merge multiple files if needed
            mergedData = fileData;
        end
    end
end