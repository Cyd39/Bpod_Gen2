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
% Initialize table for results 
numFiles = length(selectedFiles);
resultsTable = table();

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
            currentSessionData = load(absolute_path);
            disp('MAT file loaded successfully');
        otherwise
            % For other file types
            warning(['Unsupported file type: ' extension '. Skipping this file.']);
            continue;  % Skip to next file
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp('Behavior Data loaded');
    
    sessionTable  = analyzeSingleSession(currentSessionData, filename);
    resultsTable = [resultsTable; sessionTable];
    disp('Current Session Analysed successfully');
end
%% Store session list and analysis results into a table
% store as csv

% Store as table in .mat


%% Analysis functions
% Main per-session analysis function.
% Returns a struct with overall session summary and a per-stimulus table.
function sessionTable = analyzeSingleSession(currentSessionData, filename)
    % ---- 1. Extract SessionData from loaded .mat struct ----
    if isstruct(currentSessionData) && isfield(currentSessionData, 'SessionData')
        SessionData = currentSessionData.SessionData;
    else        
        error('Could not find SessionData structure in loaded file.');
    end

    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        error('SessionData.RawEvents.Trial not found.');
    end

    % ---- 2. Basic session info ----
    nTrials = length(SessionData.RawEvents.Trial);

    % Parse AnimalID / protocol / datetime from filename
    [~, fileNameNoExt, ~] = fileparts(filename);
    parts = strsplit(fileNameNoExt, '_');
    if numel(parts) >= 4
        animalID = parts{1};
        protocol = parts{2};
        dateStr = parts{3};
        timeStr = parts{4};
        datetimeStr = [dateStr '_' timeStr];
    else
        animalID = fileNameNoExt;
        protocol = '';
        datetimeStr = '';
    end

    % ---- 3. Ensure StimTable exists and matches nTrials ----
    % Extract trial information
    if ~isfield(SessionData, 'StimTable')
        % Rebuild StimTable from LeftRightSeq / CurrentSide if needed
        currentSideArray = SessionData.CurrentSide;
        T1 = SessionData.LeftRightSeq.LowFreqTable;  
        T2 = SessionData.LeftRightSeq.HighFreqTable;
        % counter
        t1_row = 1;
        t2_row = 1;
    
        StimTable = table();
        
        for i = 1:length(currentSideArray)
            if currentSideArray(i) == 1
                StimTable(i, :) = T1(t1_row, :);
                t1_row = t1_row + 1;  
            elseif currentSideArray(i) == 2
                StimTable(i, :) = T2(t2_row, :);
                t2_row = t2_row + 1;  
            end
        end
    elseif nTrials ~= height(SessionData.StimTable)
        % meaning session wasn't fully finished
        StimTable = SessionData.StimTable(1:nTrials, :);
    else
        StimTable = SessionData.StimTable;
    end

    if ~all(ismember({'VibFreq', 'VibAmp'}, StimTable.Properties.VariableNames))
        error('StimTable must contain VibFreq and VibAmp columns.');
    end

    vibFreqs = StimTable.VibFreq(:);
    vibAmps  = StimTable.VibAmp(:);

    % ---- 4. Build per-stimulus table  ----
    tol = 1e-6;
    allCombos = [vibFreqs, vibAmps];
    uniqueCombos = unique(allCombos, 'rows');
    [~, sortIdx] = sortrows(uniqueCombos, [1 2]);
    uniqueCombos = uniqueCombos(sortIdx, :);
    nCombos = size(uniqueCombos, 1);

    condCounts = zeros(nCombos, 3); % [NTrials, LeftRes, RightRes]
    allRTsByCondition = cell(nCombos, 1);  % collect Reaction Time for each stimulus

    for t = 1:nTrials
        curFreq = vibFreqs(t);
        curAmp  = vibAmps(t);

        if isnan(curFreq) || isnan(curAmp)
            continue;
        end

        % Determine first response side (1=left, 2=right, NaN=no response)
        [firstSide, response_latency] = getFirstResponseSide(SessionData, t);
        idx = find( abs(uniqueCombos(:,1) - curFreq) < tol & ...
                    abs(uniqueCombos(:,2) - curAmp)  < tol, 1 );
        if isempty(idx)
            continue;
        end
        condCounts(idx,1) = condCounts(idx,1) + 1;

        if firstSide == 1
            condCounts(idx,2) = condCounts(idx,2) + 1;
        elseif firstSide == 2
            condCounts(idx,3) = condCounts(idx,3) + 1;
        end
        if ~isnan(response_latency)
            allRTsByCondition{idx} = [allRTsByCondition{idx}, response_latency];
        end
    end


    % ---- 5. Create the main session table ----
    sessionTable = table();

    sessionTable.VibFreq = zeros(nCombos, 1);
    sessionTable.VibAmp = zeros(nCombos, 1);
    sessionTable.NTrials = zeros(nCombos, 1);
    sessionTable.LeftRes = zeros(nCombos, 1);
    sessionTable.RightRes = zeros(nCombos, 1);
    sessionTable.RT_Median = nan(nCombos, 1);
    sessionTable.N_ValidRT = zeros(nCombos, 1); 
    
    % Calculation for each stimulus
    for i = 1:nCombos
        sessionTable.VibFreq(i) = uniqueCombos(i,1);
        sessionTable.VibAmp(i) = uniqueCombos(i,2);
        sessionTable.NTrials(i) = condCounts(i,1);
        sessionTable.LeftRes(i) = condCounts(i,2);
        sessionTable.RightRes(i) = condCounts(i,3);

        validRTs = allRTsByCondition{i};
        nValidRTs = length(validRTs);
        sessionTable.N_ValidRT(i) = nValidRTs;
        
        if nValidRTs > 0
            sessionTable.RT_Median(i) = median(validRTs);
        end
    end

    % sessionTable.Response = sessionTable.LeftRes + sessionTable.RightRes;    
    % HitRate  = zeros(size(Response));
    % LeftRate = nan(size(Response));
    % 
    % validMask = NTrials > 0;
    % HitRate(validMask) = Response(validMask) ./ NTrials(validMask);
    % 
    % respMask = Response > 0;
    % LeftRate(respMask) = LeftRes(respMask) ./ Response(respMask);
    % 
    % 
    % % Overall response rate across non-catch trials
    % nonCatchMask = ~(abs(VibFreq) < tol & abs(VibAmp) < tol);
    % totalTrialsNonCatch = sum(NTrials(nonCatchMask));
    % totalRespNonCatch   = sum(Response(nonCatchMask));
    % if totalTrialsNonCatch > 0
    %     overallResponseRate = totalRespNonCatch / totalTrialsNonCatch;
    % else
    %     overallResponseRate = NaN;
    % end
    % 
    % % Overall left response rate among responses (non-catch)
    % totalLeftNonCatch  = sum(LeftRes(nonCatchMask));
    % if totalRespNonCatch > 0
    %     overallLeftRate = totalLeftNonCatch / totalRespNonCatch;
    % else
    %     overallLeftRate = NaN;
    % end
    % 
    % % Simple detection d' using all non-catch as "signal" vs catch as "noise"
    % hits      = totalRespNonCatch;
    % hitTrials = totalTrialsNonCatch;
    % fas       = Response(~nonCatchMask); % responses in catch conditions
    % faTrials  = NTrials(~nonCatchMask);
    % fasTotal      = sum(fas);
    % faTrialsTotal = sum(faTrials);
    % 
    % if hitTrials > 0 && faTrialsTotal > 0
    %     [hitRateAdj, faRateAdj] = computeRatesWithCorrection(hits, hitTrials, fasTotal, faTrialsTotal);
    %     dprimeDetection = zFromP(hitRateAdj) - zFromP(faRateAdj);
    % else
    %     dprimeDetection = NaN;
    % end
    % 
    % % For now, LR d' left/right is not defined -> NaN
    % dprimeLR = NaN;
    % 
    % % Placeholder RT median (requires explicit RT extraction)
    % rtMedian = NaN;

    % ---- 6. Add in sessioninfo ----
    sessionTable.FileName = repmat({filename}, nCombos, 1);
    sessionTable.AnimalID = repmat({animalID}, nCombos, 1);
    sessionTable.Protocol = repmat({protocol}, nCombos, 1);
    sessionTable.Time = repmat({datetimeStr}, nCombos, 1);
    sessionTable.Session_nTrials = repmat(nTrials, nCombos, 1);
end

% Helper: determine first response side for a trial (1=left, 2=right, NaN=no response)
function [firstSide, response_latency] = getFirstResponseSide(SessionData, trialIdx)
    firstSide = NaN;
    response_latency = NaN;
    tr = SessionData.RawEvents.Trial{trialIdx};
    if isfield(SessionData,"ResWin")
        resWin = SessionData.ResWin(trialIdx);
    else
        resWin = 5;
    end
    
    leftTimes  = [];
    rightTimes = [];
    leftFirst = [];
    rightFirst = [];
    if isfield(tr,"HiFi1_1")
        stimOn = tr.Events.HiFi1_1;
    else
        stimOn = tr.Events.GlobalTimer2_Start;
    end

    if isfield(tr, 'Events')
        if isfield(tr.Events, 'BNC1High') && ~isempty(tr.Events.BNC1High)
            leftLicksAfterStim = tr.Events.BNC1High(:)-stimOn;
            leftFirst = min(leftLicksAfterStim(leftLicksAfterStim > 0 & leftLicksAfterStim < resWin));
        end
        if isfield(tr.Events, 'BNC2High') && ~isempty(tr.Events.BNC2High)
            rightLicksAfterStim = tr.Events.BNC2High(:)-stimOn;
            rightFirst = min(rightLicksAfterStim(rightLicksAfterStim >0 & rightLicksAfterStim < resWin));
        end
    end

    if ~isempty(leftFirst) && ~isempty(rightFirst)
        if min(leftTimes >0 ) <= min(rightTimes >0)
            firstSide = 1;
            response_latency = leftFirst;
        else
            firstSide = 2;
            response_latency = rightFirst;
        end
    elseif ~isempty(leftFirst)
        firstSide = 1;
        response_latency = leftFirst;
    elseif ~isempty(rightFirst)
        firstSide = 2;
        response_latency = rightFirst;
    end
end

% Helper: apply log-linear correction to rates and compute adjusted hit/FA rates
function [hitRateAdj, faRateAdj] = computeRatesWithCorrection(hits, hitTrials, fas, faTrials)
    hitRateAdj = (hits + 0.5) / (hitTrials + 1);
    faRateAdj  = (fas  + 0.5) / (faTrials  + 1);
end

% Helper: inverse normal CDF using base MATLAB (no Statistics Toolbox)
function z = zFromP(p)
    % Clamp probabilities to (0,1)
    p = max(min(p, 1 - eps), eps);
    % norminv(p) = -sqrt(2) * erfcinv(2p)
    z = -sqrt(2) * erfcinv(2 * p);
end

