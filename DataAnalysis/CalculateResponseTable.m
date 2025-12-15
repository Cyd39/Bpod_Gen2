function responseTable = CalculateResponseTable()
    % Calculate response rate for each stimuli(including catch trials)
    % Output:
    %   responseTable - Table with stimuli and corresponding response rates
    % Hit rate is calculated as: (Number of trials with Reward=1) / (Total trials for that stimuli)

    %% load data from multiple files (can be from different directories)
    
    % Set default path
    defaultPath = "G:\Data\OperantConditioning\Yudi";
    if ~exist(defaultPath, 'dir')
        defaultPath = pwd;
    end
    
    % Initialize file list
    selectedFiles = {};
    currentPath = defaultPath;
    
    % Loop to select multiple files from different directories
    fprintf('=== File Selection ===\n');

    fileCount = 0;
    while true
        % Select a single file
        [filename, filepath, ~] = uigetfile('*.mat', ...
            sprintf('Select file %d (Cancel to finish)', fileCount + 1), ...
            currentPath);
        
        % Check if user canceled
        if isequal(filename, 0) || isequal(filepath, 0)
            if fileCount == 0
                fprintf('No files selected. Exiting...\n');
                responseTable = table();
                return;
            else
                fprintf('\nFinished selecting files. Total: %d file(s)\n\n', fileCount);
                break;
            end
        end
        
        % Add file to list
        fileCount = fileCount + 1;
        fullPath = fullfile(filepath, filename);
        selectedFiles{fileCount} = fullPath;
        currentPath = filepath; % Remember last directory for next selection
        
        fprintf('File %d: %s\n', fileCount, fullPath);
        
        % Ask if user wants to select more files
        choice = questdlg(sprintf('File %d selected:\n%s\n\nDo you want to select another file?', ...
            fileCount, fullPath), ...
            'File Selection', ...
            'Yes', 'No', 'Yes');
        
        if strcmp(choice, 'No')
            fprintf('\nFinished selecting files. Total: %d file(s)\n\n', fileCount);
            break;
        end
    end
    
    %% Load SessionData from all selected files
    fprintf('=== Loading Data ===\n');
    allSessionData = {};
    allFileNames = {};
    allSubjectIDs = {}; % Store subject IDs extracted from file names
    
    for i = 1:length(selectedFiles)
        filePath = selectedFiles{i};
        fprintf('Loading file %d/%d: %s\n', i, length(selectedFiles), filePath);
        
        try
            % Load the file
            loadedData = load(filePath);
            
            % Handle two cases:
            % 1. File contains SessionData field: loadedData.SessionData
            % 2. File itself is SessionData: loadedData is the SessionData structure
            if isfield(loadedData, 'SessionData')
                % Case 1: File contains SessionData field
                SessionData = loadedData.SessionData;
            elseif isstruct(loadedData) && isfield(loadedData, 'RawEvents')
                % Case 2: File itself is SessionData (check if it has RawEvents field)
                SessionData = loadedData;
            else
                % Try to find SessionData in the loaded structure
                % Sometimes the structure might have different field names
                fieldNames = fieldnames(loadedData);
                if length(fieldNames) == 1 && isstruct(loadedData.(fieldNames{1}))
                    % If there's only one field and it's a struct, try using it
                    potentialSessionData = loadedData.(fieldNames{1});
                    if isfield(potentialSessionData, 'RawEvents')
                        SessionData = potentialSessionData;
                    else
                        warning('File %s does not contain SessionData in expected format. Skipping...', filePath);
                        continue;
                    end
                else
                    warning('File %s does not contain SessionData. Skipping...', filePath);
                    continue;
                end
            end
            
            % Validate SessionData structure
            if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
                warning('File %s has invalid SessionData structure. Skipping...', filePath);
                continue;
            end
            
            % Check if there are any trials
            if isempty(SessionData.RawEvents.Trial)
                warning('File %s has no trials. Skipping...', filePath);
                continue;
            end
            
            % Extract subject ID from file name (first 4 characters)
            [~, fileName, ~] = fileparts(filePath);
            if length(fileName) >= 4
                subjectID = fileName(1:4);
            else
                subjectID = fileName; % Use full name if shorter than 4 characters
                warning('File name "%s" is shorter than 4 characters, using full name as subject ID', fileName);
            end
            
            % Store SessionData
            allSessionData{end+1} = SessionData;
            allFileNames{end+1} = fileName;
            allSubjectIDs{end+1} = subjectID;
            
            fprintf('  Subject ID: %s, Successfully loaded %d trials\n', subjectID, length(SessionData.RawEvents.Trial));
            
        catch ME
            warning('Error loading file %s: %s', filePath, ME.message);
            continue;
        end
    end
    
    if isempty(allSessionData)
        error('No valid data was loaded from the selected files.');
    end
    
    % Get unique subject IDs
    uniqueSubjectIDs = unique(allSubjectIDs);
    fprintf('\nFound %d unique subject(s): %s\n', length(uniqueSubjectIDs), strjoin(uniqueSubjectIDs, ', '));
    
    totalTrials = 0;
    for i = 1:length(allSessionData)
        totalTrials = totalTrials + length(allSessionData{i}.RawEvents.Trial);
    end
    fprintf('Total trials loaded: %d from %d file(s)\n\n', totalTrials, length(allSessionData));
    
    %% Calculate response table for each file separately, then aggregate by SubjectID and Stimulus
    fprintf('=== Calculating Response Table ===\n');
    fprintf('Processing each file separately, then aggregating by SubjectID and Stimulus...\n\n');
    
    % Tolerance for floating point comparison
    tol = 1e-6;
    
    % Initialize output table for all files
    allFileTables = {};
    
    % Process each file separately
    for fileIdx = 1:length(allSessionData)
        SessionData = allSessionData{fileIdx};
        subjectID = allSubjectIDs{fileIdx};
        fileName = allFileNames{fileIdx};
        
        fprintf('Processing file %d/%d: %s (Subject: %s)\n', fileIdx, length(allSessionData), fileName, subjectID);
        
        nTrials = length(SessionData.StimTable.VibFreq);
        
        % Get vibration frequencies and amplitudes from StimTable
        if isfield(SessionData, 'StimTable')
            vibFreqs = SessionData.StimTable.VibFreq(:);
            vibAmps = SessionData.StimTable.VibAmp(:);
        else
            vibFreqs = [];
            vibAmps = [];
        end
        
        % Collect unique stimulus conditions for this file
        fileCombinations = [vibFreqs, vibAmps];
        
        if isempty(fileCombinations)
            warning('File %s: No valid VibFreq and VibAmp combinations found!', fileName);
            continue;
        end
        
        uniqueCombinations = unique(fileCombinations, 'rows');
        % Sort by frequency first, then by amplitude
        [~, sortIdx] = sortrows(uniqueCombinations, [1, 2]);
        uniqueCombinations = uniqueCombinations(sortIdx, :);
        
        % Identify catch trials: VibFreq == 0 & VibAmp == 0
        isCatchCondition = abs(uniqueCombinations(:, 1)) < tol & abs(uniqueCombinations(:, 2)) < tol;
        stimulusCombinations = uniqueCombinations(~isCatchCondition, :);
        
        nConditions = size(stimulusCombinations, 1);
        hasCatch = any(isCatchCondition);
        
        % Initialize counters for this file: [total trials, left responses, right responses]
        conditionCounters = zeros(nConditions, 3); % [total, left, right]
        catchCounter = [0, 0, 0]; % [total, left, right]
        
        % Process each trial
        for trialNum = 1:nTrials
            if trialNum > length(SessionData.RawEvents.Trial)
                continue;
            end
            
            % Get trial data
            trialData = SessionData.RawEvents.Trial{trialNum};
            
            % Get response window duration for this trial
            if isfield(SessionData, 'ResWin') && length(SessionData.ResWin) >= trialNum
                ResWin = SessionData.ResWin(trialNum);
            else
                ResWin = 1; % Default response window if not available
            end
            
            % Get stimulus start time
            if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus') && ~isempty(trialData.States.Stimulus)
                stimulusStart = trialData.States.Stimulus(1);
                responseWindowEnd = stimulusStart + ResWin;
            else
                continue; % Skip trials without stimulus state
            end
            
            % Check for left-side lick (BNC1High) in response window
            hasLeftLick = false;
            leftLickTimes = [];
            if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                leftLickTimes = trialData.Events.BNC1High(trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd);
                hasLeftLick = ~isempty(leftLickTimes);
            end
            
            % Check for right-side lick (BNC2High) in response window
            hasRightLick = false;
            rightLickTimes = [];
            if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                rightLickTimes = trialData.Events.BNC2High(trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd);
                hasRightLick = ~isempty(rightLickTimes);
            end
            
            % Get current trial's VibFreq and VibAmp first
            currentVibFreq = vibFreqs(trialNum);
            currentVibAmp = vibAmps(trialNum);
            
            % Skip if NaN (invalid trial)
            if isnan(currentVibFreq) || isnan(currentVibAmp)
                continue;
            end
            
            % Determine first response side (same logic as PlotBarResponse.m)
            firstResponseSide = NaN; % 1 = left, 2 = right, NaN = no response
            if hasLeftLick && hasRightLick
                % Both sides have licks, find which came first
                firstLeftLick = min(leftLickTimes);
                firstRightLick = min(rightLickTimes);
                if firstLeftLick <= firstRightLick
                    firstResponseSide = 1; % Left first
                else
                    firstResponseSide = 2; % Right first
                end
            elseif hasLeftLick
                firstResponseSide = 1; % Left only
            elseif hasRightLick
                firstResponseSide = 2; % Right only
            end
            
            % Check if this is a catch trial (VibFreq == 0 & VibAmp == 0)
            isCatch = abs(currentVibFreq) < tol && abs(currentVibAmp) < tol;
            
            if isCatch
                % Catch trial - count all trials regardless of response
                catchCounter(1) = catchCounter(1) + 1; % Total catch trials
                if firstResponseSide == 1
                    catchCounter(2) = catchCounter(2) + 1; % Left responses
                elseif firstResponseSide == 2
                    catchCounter(3) = catchCounter(3) + 1; % Right responses
                end
            else
                % Classify by VibFreq and VibAmp combination
                conditionIdx = find(abs(stimulusCombinations(:, 1) - currentVibFreq) < tol & ...
                                    abs(stimulusCombinations(:, 2) - currentVibAmp) < tol);
                
                if ~isempty(conditionIdx)
                    % Count all trials regardless of response
                    conditionCounters(conditionIdx, 1) = conditionCounters(conditionIdx, 1) + 1; % Total trials
                    if firstResponseSide == 1
                        conditionCounters(conditionIdx, 2) = conditionCounters(conditionIdx, 2) + 1; % Left responses
                    elseif firstResponseSide == 2
                        conditionCounters(conditionIdx, 3) = conditionCounters(conditionIdx, 3) + 1; % Right responses
                    end
                end
            end
        end
        
        % Create table for this file
        fileVibFreqs = [];
        fileVibAmps = [];
        fileTotalTrials = [];
        fileLeftResponses = [];
        fileRightResponses = [];
        fileMouseIDs = {};
        
        % Add stimulus conditions
        for i = 1:nConditions
            freq = stimulusCombinations(i, 1);
            amp = stimulusCombinations(i, 2);
            fileVibFreqs(end+1) = freq;
            fileVibAmps(end+1) = amp;
            fileTotalTrials(end+1) = conditionCounters(i, 1);
            fileLeftResponses(end+1) = conditionCounters(i, 2);
            fileRightResponses(end+1) = conditionCounters(i, 3);
            fileMouseIDs{end+1} = subjectID;
        end
        
        % Add catch trial if present
        if hasCatch && catchCounter(1) > 0
            fileVibFreqs(end+1) = 0;
            fileVibAmps(end+1) = 0;
            fileTotalTrials(end+1) = catchCounter(1);
            fileLeftResponses(end+1) = catchCounter(2);
            fileRightResponses(end+1) = catchCounter(3);
            fileMouseIDs{end+1} = subjectID;
        end
        
        % Create table for this file
        if ~isempty(fileVibFreqs)
            % Ensure all variables are column vectors
            fileTable = table(fileMouseIDs(:), fileVibFreqs(:), fileVibAmps(:), ...
                fileTotalTrials(:), fileLeftResponses(:), fileRightResponses(:), ...
                'VariableNames', {'MouseID', 'VibFreq', 'VibAmp', 'NTrials', 'LeftRes', 'RightRes'});
            allFileTables{end+1} = fileTable;
            fprintf('  File %s: Processed %d conditions\n', fileName, length(fileVibFreqs));
        end
    end
    
    fprintf('\n');
    
    % Combine all file tables
    if isempty(allFileTables)
        error('No valid data was processed for any file.');
    end
    
    combinedTable = vertcat(allFileTables{:});
    
    % Aggregate by MouseID and (VibFreq, VibAmp) combination
    % Same VibFreq and VibAmp combination is considered as the same stimulus
    fprintf('=== Aggregating by MouseID and (VibFreq, VibAmp) ===\n');
    
    % Get unique combinations of MouseID, VibFreq, and VibAmp
    [uniqueGroups, ~, groupIdx] = unique(combinedTable(:, {'MouseID', 'VibFreq', 'VibAmp'}), 'rows');
    
    % Initialize aggregated table
    nGroups = height(uniqueGroups);
    aggMouseIDs = cell(nGroups, 1);
    aggVibFreqs = zeros(nGroups, 1);
    aggVibAmps = zeros(nGroups, 1);
    aggNTrials = zeros(nGroups, 1);
    aggLeftRes = zeros(nGroups, 1);
    aggRightRes = zeros(nGroups, 1);
    
    % Aggregate each group
    for i = 1:nGroups
        groupRows = groupIdx == i;
        groupData = combinedTable(groupRows, :);
        
        aggMouseIDs{i} = uniqueGroups.MouseID{i};
        aggVibFreqs(i) = uniqueGroups.VibFreq(i);
        aggVibAmps(i) = uniqueGroups.VibAmp(i);
        
        % Sum the counts
        aggNTrials(i) = sum(groupData.NTrials);
        aggLeftRes(i) = sum(groupData.LeftRes);
        aggRightRes(i) = sum(groupData.RightRes);
    end
    
    % Calculate Response (total responses = LeftRes + RightRes)
    aggResponse = aggLeftRes + aggRightRes;
    
    % Create final aggregated table with required column names
    responseTable = table(aggMouseIDs, aggVibFreqs, aggVibAmps, aggNTrials, ...
        aggResponse, aggLeftRes, aggRightRes, ...
        'VariableNames', {'MouseID', 'VibFreq', 'VibAmp', 'NTrials', 'Response', 'LeftRes', 'RightRes'});
    
    % Sort by MouseID, then by VibFreq, then by VibAmp
    responseTable = sortrows(responseTable, {'MouseID', 'VibFreq', 'VibAmp'});
    
    % Display results
    fprintf('\n=== Final Aggregated Results ===\n');
    fprintf('(Aggregated by MouseID and (VibFreq, VibAmp) combination)\n\n');
    for i = 1:height(responseTable)
        fprintf('%s - VibFreq=%.2f, VibAmp=%.2f: NTrials=%d, Response=%d (Left=%d, Right=%d)\n', ...
            responseTable.MouseID{i}, ...
            responseTable.VibFreq(i), ...
            responseTable.VibAmp(i), ...
            responseTable.NTrials(i), ...
            responseTable.Response(i), ...
            responseTable.LeftRes(i), ...
            responseTable.RightRes(i));
    end
    fprintf('\n');
    
end