function LeftRightSeq = GenLeftRightSeq(StimParams)
% GenLeftRightSeq - Generate high and low frequency stimulus sequence tables for each trial
% Each frequency table uses independent indexing and does not include catch trials
% Catch trials are handled at the trial level in the main protocol
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   LeftRightSeq - Structure containing:
%     .HighFreqTable - Table containing high frequency stimulus parameters (independent indexing)
%     .LowFreqTable - Table containing low frequency stimulus parameters (independent indexing)
%     .BoundaryFreqTable - Table containing boundary frequency stimulus parameters (independent indexing)
%     .FrequencyBoundary - Frequency boundary value
%     .HighFreqSide - Side associated with high frequency ('Left' or 'Right')
%     .LowFreqSide - Side associated with low frequency ('Left' or 'Right')    

% get general parameters
nTrials = StimParams.Behave.NumTrials;
sessionTypeName = StimParams.Session.TypeName;

% get frequency boundary and side configuration based on session type
switch sessionTypeName
    case 'Multimodal'
        % For multimodal, use vibration boundary frequency
        if isfield(StimParams.Vibration, 'BoundaryFreq')
            frequencyBoundary = StimParams.Vibration.BoundaryFreq;
        else
            error('Vibration.BoundaryFreq not found in StimParams');
        end
    case 'SoundOnly'
        % For sound only, use sound boundary frequency (AM Noise)
        if isfield(StimParams.Sound, 'AM') && isfield(StimParams.Sound.AM, 'BoundaryFreq')
            frequencyBoundary = StimParams.Sound.AM.BoundaryFreq;
        else
            error('Sound.AM.BoundaryFreq not found in StimParams');
        end
    case 'VibrationOnly'
        % For vibration only, use vibration boundary frequency
        if isfield(StimParams.Vibration, 'BoundaryFreq')
            frequencyBoundary = StimParams.Vibration.BoundaryFreq;
        else
            error('Vibration.BoundaryFreq not found in StimParams');
        end
end

% Get side configuration (these might need to be added to StimParamGui)
if isfield(StimParams, 'HighFreqSide')
    highFreqSide = StimParams.HighFreqSide;
else
    highFreqSide = 'Left';  % Default
end

if isfield(StimParams, 'LowFreqSide')
    lowFreqSide = StimParams.LowFreqSide;
else
    lowFreqSide = 'Right';  % Default
end


switch sessionTypeName
    case 'Multimodal'
        [highFreqTable, lowFreqTable] = makeMultiTable(StimParams, frequencyBoundary); 
    case 'SoundOnly'
        [highFreqTable, lowFreqTable] = makeSndTable(StimParams, frequencyBoundary);
    case 'VibrationOnly'
        [highFreqTable, lowFreqTable] = makeVibTable(StimParams, frequencyBoundary);
    otherwise
        error('Invalid session type');
end

% Generate boundary frequency table
boundaryFreqTable = makeBoundaryTable(StimParams, frequencyBoundary);

% Add MMType column to all tables
if ~isempty(highFreqTable)
    highFreqTable = addMMTypeColumn(highFreqTable);
end
if ~isempty(lowFreqTable)
    lowFreqTable = addMMTypeColumn(lowFreqTable);
end
if ~isempty(boundaryFreqTable)
    boundaryFreqTable = addMMTypeColumn(boundaryFreqTable);
end

% Add Rewarded column to all tables
if ~isempty(highFreqTable)
    highFreqTable = addRewardedColumn(highFreqTable, StimParams);
end
if ~isempty(lowFreqTable)
    lowFreqTable = addRewardedColumn(lowFreqTable, StimParams);
end
if ~isempty(boundaryFreqTable)
    boundaryFreqTable = addBoundaryRewardedColumn(boundaryFreqTable, StimParams);
end

% Add Duration and RampDur columns to all tables
if ~isempty(highFreqTable)
    highFreqTable.Duration = repmat(StimParams.Duration, height(highFreqTable), 1);
    highFreqTable.RampDur = repmat(StimParams.Ramp, height(highFreqTable), 1);
end
if ~isempty(lowFreqTable)
    lowFreqTable.Duration = repmat(StimParams.Duration, height(lowFreqTable), 1);
    lowFreqTable.RampDur = repmat(StimParams.Ramp, height(lowFreqTable), 1);
end
if ~isempty(boundaryFreqTable)
    boundaryFreqTable.Duration = repmat(StimParams.Duration, height(boundaryFreqTable), 1);
    boundaryFreqTable.RampDur = repmat(StimParams.Ramp, height(boundaryFreqTable), 1);
end

% Create output structure
LeftRightSeq = struct();
LeftRightSeq.HighFreqTable = highFreqTable;
LeftRightSeq.LowFreqTable = lowFreqTable;
LeftRightSeq.BoundaryFreqTable = boundaryFreqTable;
LeftRightSeq.FrequencyBoundary = frequencyBoundary;
LeftRightSeq.HighFreqSide = highFreqSide;
LeftRightSeq.LowFreqSide = lowFreqSide;

% save LeftRightSeq to workspace
assignin('base', 'LeftRightSeq', LeftRightSeq);
disp('LeftRightSeq has been generated and saved to workspace');

% Helper function to add MMType column
function tableWithMMType = addMMTypeColumn(inputTable)
    tableWithMMType = inputTable;
    tableWithMMType.MMType = cell(height(inputTable), 1);
    
    for j = 1:height(inputTable)
        hasSnd = ismember('AudIntensity', inputTable.Properties.VariableNames);
        hasVib = ismember('VibAmp', inputTable.Properties.VariableNames);
        
        if hasSnd && hasVib
            if inputTable.AudIntensity(j) == -inf && inputTable.VibAmp(j) == 0
                tableWithMMType.MMType{j} = 'OO';
            elseif inputTable.AudIntensity(j) == -inf
                tableWithMMType.MMType{j} = 'SO';
            elseif inputTable.VibAmp(j) == 0
                tableWithMMType.MMType{j} = 'OA';
            else
                tableWithMMType.MMType{j} = 'SA';
            end
        elseif hasSnd
            if inputTable.AudIntensity(j) == -inf
                tableWithMMType.MMType{j} = 'OO';
            else
                tableWithMMType.MMType{j} = 'OA';
            end
        elseif hasVib
            if inputTable.VibAmp(j) == 0
                tableWithMMType.MMType{j} = 'OO';
            else
                tableWithMMType.MMType{j} = 'SO';
            end
        else
            tableWithMMType.MMType{j} = 'OO';
        end
    end
end

% Helper function to generate randomized table
function randomizedTable = generateRandomizedTable(stimTableUnq, nTrials)
    % Calculate number of blocks needed
    blockSize = height(stimTableUnq);
    numBlocks = floor(nTrials / blockSize);
    remainingRows = mod(nTrials, blockSize);

    % Preallocate table
    randomizedTable = table('Size', [nTrials, width(stimTableUnq)], 'VariableTypes', varfun(@class, stimTableUnq, 'OutputFormat', 'cell'));
    randomizedTable.Properties.VariableNames = stimTableUnq.Properties.VariableNames;
    
    % Fill table with randomized blocks
    currentRow = 1;
    for i = 1:numBlocks
        randomBlock = stimTableUnq(randperm(blockSize), :);
        randomizedTable(currentRow:currentRow+blockSize-1, :) = randomBlock;
        currentRow = currentRow + blockSize;
    end

    % Add remaining rows
    if remainingRows > 0
        randomIndices = randi(blockSize, remainingRows, 1);
        remainingBlock = stimTableUnq(randomIndices, :);
        randomizedTable(currentRow:end, :) = remainingBlock;
    end
end

% Generate high and low frequency stimulus sequence tables for multimodal condition
function [highFreqTable, lowFreqTable] = makeMultiTable(StimParams, frequencyBoundary)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    soundTypeName = StimParams.Sound.TypeName;
    vibTypeName = StimParams.Vibration.TypeName;
    switch soundTypeName
        case 'Noise Burst'
            sndLevel = StimParams.Sound.Noise.Level;
            vibAmp = StimParams.Vibration.Amplitude;
            vibFreq = StimParams.Vibration.Frequency;

            % Separate high and low frequency vibrations
            highVibFreq = vibFreq(vibFreq > frequencyBoundary);
            lowVibFreq = vibFreq(vibFreq < frequencyBoundary);
            
            % Generate high frequency table
            if ~isempty(highVibFreq)
                [highSndLevel, highVibAmp, highVibFreq] = ndgrid(sndLevel, vibAmp, highVibFreq);
                highStimTableUnq = table(highSndLevel(:), highVibAmp(:), highVibFreq(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                
                % Remove invalid combinations
                invalidRows = highStimTableUnq.AudIntensity == -inf & (highStimTableUnq.VibAmp == 0 | highStimTableUnq.VibFreq == 0);
                highStimTableUnq = highStimTableUnq(~invalidRows, :);
                
                % Generate randomized sequence for high frequency
                highFreqTable = generateRandomizedTable(highStimTableUnq, nTrials);
                
                % Add other parameters
                highFreqTable.AudFreqMin = repmat(StimParams.Sound.Noise.LowFreq, height(highFreqTable), 1);
                highFreqTable.AudFreqMax = repmat(StimParams.Sound.Noise.HighFreq, height(highFreqTable), 1);
                highFreqTable.SndTypeName = repmat({soundTypeName}, height(highFreqTable), 1);
                highFreqTable.VibTypeName = repmat({vibTypeName}, height(highFreqTable), 1);
                highFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(highFreqTable), 1);
            else
                highFreqTable = table();
            end
            
            % Generate low frequency table
            if ~isempty(lowVibFreq)
                [lowSndLevel, lowVibAmp, lowVibFreq] = ndgrid(sndLevel, vibAmp, lowVibFreq);
                lowStimTableUnq = table(lowSndLevel(:), lowVibAmp(:), lowVibFreq(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                
                % Remove invalid combinations
                invalidRows = lowStimTableUnq.AudIntensity == -inf & (lowStimTableUnq.VibAmp == 0 | lowStimTableUnq.VibFreq == 0);
                lowStimTableUnq = lowStimTableUnq(~invalidRows, :);
                
                % Generate randomized sequence for low frequency
                lowFreqTable = generateRandomizedTable(lowStimTableUnq, nTrials);
                
                % Add other parameters
                lowFreqTable.AudFreqMin = repmat(StimParams.Sound.Noise.LowFreq, height(lowFreqTable), 1);
                lowFreqTable.AudFreqMax = repmat(StimParams.Sound.Noise.HighFreq, height(lowFreqTable), 1);
                lowFreqTable.SndTypeName = repmat({soundTypeName}, height(lowFreqTable), 1);
                lowFreqTable.VibTypeName = repmat({vibTypeName}, height(lowFreqTable), 1);
                lowFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(lowFreqTable), 1);
            else
                lowFreqTable = table();
            end
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
    end

end

% Generate high and low frequency stimulus sequence tables for sound only condition
function [highFreqTable, lowFreqTable] = makeSndTable(StimParams, frequencyBoundary)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    soundTypeName = StimParams.Sound.TypeName;
    switch soundTypeName
        case 'Noise Burst'
            sndLevel = StimParams.Sound.Noise.Level;
            sndFreqMin = StimParams.Sound.Noise.LowFreq;
            sndFreqMax = StimParams.Sound.Noise.HighFreq;

            % For sound only, we need to determine frequency boundary based on sound frequency range
            % If frequency boundary is within the sound range, separate accordingly
            if frequencyBoundary >= sndFreqMin && frequencyBoundary <= sndFreqMax
                % Create high frequency sound parameters (above boundary)
                highFreqMin = frequencyBoundary;
                highFreqMax = sndFreqMax;
                
                % Create low frequency sound parameters (below boundary)  
                lowFreqMin = sndFreqMin;
                lowFreqMax = frequencyBoundary;
                
                % Generate high frequency table
                [highSndLevel] = ndgrid(sndLevel);
                highStimTableUnq = table(highSndLevel(:), 'VariableNames', {'AudIntensity'});
                
                % Remove invalid rows
                invalidRows = highStimTableUnq.AudIntensity == -inf;
                highStimTableUnq = highStimTableUnq(~invalidRows, :);
                
                % Generate randomized sequence for high frequency
                highFreqTable = generateRandomizedTable(highStimTableUnq, nTrials);
                
                % Add other parameters
                highFreqTable.AudFreqMin = repmat(highFreqMin, height(highFreqTable), 1);
                highFreqTable.AudFreqMax = repmat(highFreqMax, height(highFreqTable), 1);
                highFreqTable.SndTypeName = repmat({soundTypeName}, height(highFreqTable), 1);
                highFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(highFreqTable), 1);
                
                % Generate low frequency table
                [lowSndLevel] = ndgrid(sndLevel);
                lowStimTableUnq = table(lowSndLevel(:), 'VariableNames', {'AudIntensity'});
                
                % Remove invalid rows
                invalidRows = lowStimTableUnq.AudIntensity == -inf;
                lowStimTableUnq = lowStimTableUnq(~invalidRows, :);
                
                % Generate randomized sequence for low frequency
                lowFreqTable = generateRandomizedTable(lowStimTableUnq, nTrials);
                
                % Add other parameters
                lowFreqTable.AudFreqMin = repmat(lowFreqMin, height(lowFreqTable), 1);
                lowFreqTable.AudFreqMax = repmat(lowFreqMax, height(lowFreqTable), 1);
                lowFreqTable.SndTypeName = repmat({soundTypeName}, height(lowFreqTable), 1);
                lowFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(lowFreqTable), 1);
            else
                % If frequency boundary is outside sound range, create single table
                [sndLevel] = ndgrid(sndLevel);
                stimTableUnq = table(sndLevel(:), 'VariableNames', {'AudIntensity'});
                
                % Remove invalid rows
                invalidRows = stimTableUnq.AudIntensity == -inf;
                stimTableUnq = stimTableUnq(~invalidRows, :);
                
                % Generate randomized sequence
                singleTable = generateRandomizedTable(stimTableUnq, nTrials);
                
                % Add other parameters
                singleTable.AudFreqMin = repmat(sndFreqMin, height(singleTable), 1);
                singleTable.AudFreqMax = repmat(sndFreqMax, height(singleTable), 1);
                singleTable.SndTypeName = repmat({soundTypeName}, height(singleTable), 1);
                singleTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(singleTable), 1);
                
                % Assign to both tables (same content)
                highFreqTable = singleTable;
                lowFreqTable = singleTable;
            end
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
    end

end

% Generate high and low frequency stimulus sequence tables for vibration only condition
function [highFreqTable, lowFreqTable] = makeVibTable(StimParams, frequencyBoundary)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    vibTypeName = StimParams.Vibration.TypeName;
    vibAmp = StimParams.Vibration.Amplitude;
    vibFreq = StimParams.Vibration.Frequency;

    % Separate high and low frequency vibrations
    highVibFreq = vibFreq(vibFreq > frequencyBoundary);
    lowVibFreq = vibFreq(vibFreq < frequencyBoundary);
    
    % Generate high frequency table
    if ~isempty(highVibFreq)
        [highVibAmp, highVibFreq] = ndgrid(vibAmp, highVibFreq);
        highStimTableUnq = table(highVibAmp(:), highVibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
        
        % Remove invalid rows
        invalidRows = highStimTableUnq.VibAmp == 0 | highStimTableUnq.VibFreq == 0;
        highStimTableUnq = highStimTableUnq(~invalidRows, :);
        
        % Generate randomized sequence for high frequency
        highFreqTable = generateRandomizedTable(highStimTableUnq, nTrials);
        
        % Add other parameters
        highFreqTable.VibTypeName = repmat({vibTypeName}, height(highFreqTable), 1);
    else
        highFreqTable = table();
    end
    
    % Generate low frequency table
    if ~isempty(lowVibFreq)
        [lowVibAmp, lowVibFreq] = ndgrid(vibAmp, lowVibFreq);
        lowStimTableUnq = table(lowVibAmp(:), lowVibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
        
        % Remove invalid rows
        invalidRows = lowStimTableUnq.VibAmp == 0 | lowStimTableUnq.VibFreq == 0;
        lowStimTableUnq = lowStimTableUnq(~invalidRows, :);
        
        % Generate randomized sequence for low frequency
        lowFreqTable = generateRandomizedTable(lowStimTableUnq, nTrials);
        
        % Add other parameters
        lowFreqTable.VibTypeName = repmat({vibTypeName}, height(lowFreqTable), 1);
    else
        lowFreqTable = table();
    end
end 

% Helper function to add Rewarded column based on reward probability
function tableWithRewarded = addRewardedColumn(inputTable, StimParams)
    tableWithRewarded = inputTable;
    
    % Get reward probability from StimParams
    if isfield(StimParams.Behave, 'RewardProbability')
        rewardProbability = StimParams.Behave.RewardProbability;
    else
        rewardProbability = 1.0;  % Default to 100% reward if not specified
        warning('RewardProbability not found in StimParams, using default value of 1.0');
    end
    
    % Initialize Rewarded column
    tableWithRewarded.Rewarded = zeros(height(inputTable), 1);
    
    % Apply reward probability to non-catch trials (MMType != 'OO')
    for i = 1:height(inputTable)
        if strcmp(inputTable.MMType{i}, 'OO')
            % Catch trials are never rewarded
            tableWithRewarded.Rewarded(i) = 0;
        else
            % Non-catch trials are rewarded based on probability
            if rand() <= rewardProbability
                tableWithRewarded.Rewarded(i) = 1;
            else
                tableWithRewarded.Rewarded(i) = 0;
            end
        end
    end
end

% Helper function to add Rewarded column for boundary frequency table based on boundary reward probability
function tableWithRewarded = addBoundaryRewardedColumn(inputTable, StimParams)
    tableWithRewarded = inputTable;
    
    % Get boundary reward probability from StimParams
    if isfield(StimParams.Behave, 'BoundaryRewardProbability')
        boundaryRewardProbability = StimParams.Behave.BoundaryRewardProbability;
    else
        boundaryRewardProbability = 1.0;  % Default to 100% reward if not specified
        warning('BoundaryRewardProbability not found in StimParams, using default value of 1.0');
    end
    
    % Initialize Rewarded column
    tableWithRewarded.Rewarded = zeros(height(inputTable), 1);
    
    % Apply boundary reward probability to non-catch trials (MMType != 'OO')
    for i = 1:height(inputTable)
        if strcmp(inputTable.MMType{i}, 'OO')
            % Catch trials are never rewarded
            tableWithRewarded.Rewarded(i) = 0;
        else
            % Non-catch trials are rewarded based on boundary probability
            if rand() <= boundaryRewardProbability
                tableWithRewarded.Rewarded(i) = 1;
            else
                tableWithRewarded.Rewarded(i) = 0;
            end
        end
    end
end

% Generate boundary frequency stimulus sequence table
function boundaryFreqTable = makeBoundaryTable(StimParams, frequencyBoundary)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    sessionTypeName = StimParams.Session.TypeName;
    
    switch sessionTypeName
        case 'Multimodal'
            % For multimodal, create boundary frequency table with vibration at boundary frequency
            soundTypeName = StimParams.Sound.TypeName;
            vibTypeName = StimParams.Vibration.TypeName;
            
            switch soundTypeName
                case 'Noise Burst'
                    sndLevel = StimParams.Sound.Noise.Level;
                    vibAmp = StimParams.Vibration.Amplitude;
                    
                    % Create combinations with boundary frequency
                    [sndLevel, vibAmp] = ndgrid(sndLevel, vibAmp);
                    boundaryStimTableUnq = table(sndLevel(:), vibAmp(:), repmat(frequencyBoundary, length(sndLevel(:)), 1), ...
                        'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                    
                    % Remove invalid combinations
                    invalidRows = boundaryStimTableUnq.AudIntensity == -inf & (boundaryStimTableUnq.VibAmp == 0 | boundaryStimTableUnq.VibFreq == 0);
                    boundaryStimTableUnq = boundaryStimTableUnq(~invalidRows, :);
                    
                    % Generate randomized sequence
                    boundaryFreqTable = generateRandomizedTable(boundaryStimTableUnq, nTrials);
                    
                    % Add other parameters
                    boundaryFreqTable.AudFreqMin = repmat(StimParams.Sound.Noise.LowFreq, height(boundaryFreqTable), 1);
                    boundaryFreqTable.AudFreqMax = repmat(StimParams.Sound.Noise.HighFreq, height(boundaryFreqTable), 1);
                    boundaryFreqTable.SndTypeName = repmat({soundTypeName}, height(boundaryFreqTable), 1);
                    boundaryFreqTable.VibTypeName = repmat({vibTypeName}, height(boundaryFreqTable), 1);
                    boundaryFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(boundaryFreqTable), 1);
                otherwise
                    boundaryFreqTable = table();
            end
            
        case 'SoundOnly'
            % For sound only, create boundary frequency table with sound at boundary frequency
            soundTypeName = StimParams.Sound.TypeName;
            
            switch soundTypeName
                case 'Noise Burst'
                    sndLevel = StimParams.Sound.Noise.Level;
                    
                    % Create combinations with boundary frequency
                    [sndLevel] = ndgrid(sndLevel);
                    boundaryStimTableUnq = table(sndLevel(:), 'VariableNames', {'AudIntensity'});
                    
                    % Remove invalid rows
                    invalidRows = boundaryStimTableUnq.AudIntensity == -inf;
                    boundaryStimTableUnq = boundaryStimTableUnq(~invalidRows, :);
                    
                    % Generate randomized sequence
                    boundaryFreqTable = generateRandomizedTable(boundaryStimTableUnq, nTrials);
                    
                    % Add other parameters with boundary frequency range
                    boundaryFreqTable.AudFreqMin = repmat(frequencyBoundary, height(boundaryFreqTable), 1);
                    boundaryFreqTable.AudFreqMax = repmat(frequencyBoundary, height(boundaryFreqTable), 1);
                    boundaryFreqTable.SndTypeName = repmat({soundTypeName}, height(boundaryFreqTable), 1);
                    boundaryFreqTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(boundaryFreqTable), 1);
                otherwise
                    boundaryFreqTable = table();
            end
            
        case 'VibrationOnly'
            % For vibration only, create boundary frequency table with vibration at boundary frequency
            vibTypeName = StimParams.Vibration.TypeName;
            vibAmp = StimParams.Vibration.Amplitude;
            
            % Create combinations with boundary frequency
            [vibAmp] = ndgrid(vibAmp);
            boundaryStimTableUnq = table(vibAmp(:), repmat(frequencyBoundary, length(vibAmp(:)), 1), ...
                'VariableNames', {'VibAmp', 'VibFreq'});
            
            % Remove invalid rows
            invalidRows = boundaryStimTableUnq.VibAmp == 0 | boundaryStimTableUnq.VibFreq == 0;
            boundaryStimTableUnq = boundaryStimTableUnq(~invalidRows, :);
            
            % Generate randomized sequence
            boundaryFreqTable = generateRandomizedTable(boundaryStimTableUnq, nTrials);
            
            % Add other parameters
            boundaryFreqTable.VibTypeName = repmat({vibTypeName}, height(boundaryFreqTable), 1);
            
        otherwise
            boundaryFreqTable = table();
    end
end

end