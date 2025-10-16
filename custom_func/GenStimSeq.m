function StimTable = GenStimSeq(StimParams)
% GenStimSeq - Generate stimulus sequence table for each trial
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   StimTable - Table containing stimulus parameters for each trial

% get general parameters
nTrials = StimParams.Behave.NumTrials;
propCatch = StimParams.Behave.PropCatch;
sessionTypeName = StimParams.Session.TypeName;


switch sessionTypeName
    case 'Multimodal'
        StimTable = makeMultiTable(StimParams);

    case 'SoundOnly'
        StimTable = makeSndTable(StimParams);

    case 'VibrationOnly'
        StimTable = makeVibTable(StimParams);
        
    otherwise
        error('Invalid session type');
end

% Add MMType column based on conditions
StimTable.MMType = cell(height(StimTable), 1);
for j = 1:height(StimTable)
    hasSnd = ismember('AudIntensity', StimTable.Properties.VariableNames);
    hasVib = ismember('VibAmp', StimTable.Properties.VariableNames);
    
    if hasSnd && hasVib
        if StimTable.AudIntensity(j) == -inf && StimTable.VibAmp(j) == 0
            StimTable.MMType{j} = 'OO';
        elseif StimTable.AudIntensity(j) == -inf
            StimTable.MMType{j} = 'SO';
        elseif StimTable.VibAmp(j) == 0
            StimTable.MMType{j} = 'OA';
        else
            StimTable.MMType{j} = 'SA';
        end
    elseif hasSnd
        if StimTable.AudIntensity(j) == -inf
            StimTable.MMType{j} = 'OO';
        else
            StimTable.MMType{j} = 'OA';
        end
    elseif hasVib
        if StimTable.VibAmp(j) == 0
            StimTable.MMType{j} = 'OO';
        else
            StimTable.MMType{j} = 'SO';
        end
    else
        StimTable.MMType{j} = 'OO';
    end
end

% Add Duration and RampDur columns
StimTable.Duration = repmat(StimParams.Duration, height(StimTable), 1);
StimTable.RampDur = repmat(StimParams.Ramp, height(StimTable), 1);

% Save StimTable to workspace
assignin('base', 'StimTable', StimTable);
disp('StimTable has been generated and saved to workspace');

% Generate stimulus table for multimodal condition
function StimTable = makeMultiTable(StimParams)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    soundTypeName = StimParams.Sound.TypeName;
    vibTypeName = StimParams.Vibration.TypeName;
    switch soundTypeName
        case 'Noise Burst'
            sndLevel = StimParams.Sound.Noise.Level;
            vibAmp = StimParams.Vibration.Amplitude;
            vibFreq = StimParams.Vibration.Frequency;

            % Create unique combinations of parameters
            [sndLevel, vibAmp, vibFreq] = ndgrid(sndLevel, vibAmp, vibFreq);
            stimTableUnq = table(sndLevel(:), vibAmp(:), vibFreq(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
            
            % Remove combinations that would be equivalent to catch trials
            % (where sndLevel is NaN and at least one of vibAmp or vibFreq is NaN)
            invalidRows = stimTableUnq.AudIntensity == -inf & (stimTableUnq.VibAmp == 0 | stimTableUnq.VibFreq == 0);
            stimTableUnq = stimTableUnq(~invalidRows, :);
            
            % Calculate number of blocks needed
            blockSize = height(stimTableUnq);
            numBlocks = floor(nTrials / blockSize);
            remainingRows = mod(nTrials, blockSize);

            % Preallocate StimTable
            StimTable = table('Size', [nTrials, width(stimTableUnq)], 'VariableTypes', varfun(@class, stimTableUnq, 'OutputFormat', 'cell'));
            StimTable.Properties.VariableNames = stimTableUnq.Properties.VariableNames;
            
            % Fill StimTable with randomized blocks
            currentRow = 1;
            for i = 1:numBlocks
                randomBlock = stimTableUnq(randperm(blockSize), :);
                StimTable(currentRow:currentRow+blockSize-1, :) = randomBlock;
                currentRow = currentRow + blockSize;
            end

            % Add remaining rows
            if remainingRows > 0
                randomIndices = randi(blockSize, remainingRows, 1);
                remainingBlock = stimTableUnq(randomIndices, :);
                StimTable(currentRow:end, :) = remainingBlock;
            end
            
            % Add in catch trials
            if propCatch > 0
                StimTable = addCatchTrials(StimTable, nTrials, propCatch);
            end

            % Add other parameters
            StimTable.AudFreqMin = repmat(StimParams.Sound.Noise.LowFreq, height(StimTable), 1);
            StimTable.AudFreqMax = repmat(StimParams.Sound.Noise.HighFreq, height(StimTable), 1);
            StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
            StimTable.VibTypeName = repmat({vibTypeName}, height(StimTable), 1);
            StimTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(StimTable), 1);
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
    end

end

% Generate stimulus table for sound only condition
function StimTable = makeSndTable(StimParams)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    soundTypeName = StimParams.Sound.TypeName;
    switch soundTypeName
        case 'Noise Burst'
            sndLevel = StimParams.Sound.Noise.Level;

            % Create unique combinations of parameters
            [sndLevel] = ndgrid(sndLevel);
            stimTableUnq = table(sndLevel(:), 'VariableNames', {'AudIntensity'});
            
            % Remove invalid rows
            invalidRows = stimTableUnq.AudIntensity == -inf;
            stimTableUnq = stimTableUnq(~invalidRows, :);

            % Calculate number of blocks needed
            blockSize = height(stimTableUnq);
            numBlocks = floor(nTrials / blockSize);
            remainingRows = mod(nTrials, blockSize);

            % Preallocate StimTable
            StimTable = table('Size', [nTrials, width(stimTableUnq)], 'VariableTypes', varfun(@class, stimTableUnq, 'OutputFormat', 'cell'));
            StimTable.Properties.VariableNames = stimTableUnq.Properties.VariableNames;
            
            % Fill StimTable with randomized blocks
            currentRow = 1;
            for i = 1:numBlocks
                randomBlock = stimTableUnq(randperm(blockSize), :);
                StimTable(currentRow:currentRow+blockSize-1, :) = randomBlock;
                currentRow = currentRow + blockSize;
            end

            % Add remaining rows
            if remainingRows > 0
                randomIndices = randi(blockSize, remainingRows, 1);
                remainingBlock = stimTableUnq(randomIndices, :);
                StimTable(currentRow:end, :) = remainingBlock;
            end

            % Add in catch trials
            if propCatch > 0
                StimTable = addCatchTrials(StimTable, nTrials, propCatch);
            end

             % Add other parameters
             StimTable.AudFreqMin = repmat(StimParams.Sound.Noise.LowFreq, height(StimTable), 1);
             StimTable.AudFreqMax = repmat(StimParams.Sound.Noise.HighFreq, height(StimTable), 1);
             StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
             StimTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(StimTable), 1);
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
    end

end

% Generate stimulus table for vibration only condition
function StimTable = makeVibTable(StimParams)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    propCatch = StimParams.Behave.PropCatch;
    vibTypeName = StimParams.Vibration.TypeName;
    vibAmp = StimParams.Vibration.Amplitude;
    vibFreq = StimParams.Vibration.Frequency;
    
    % Get reward probability and boundary frequency parameters
    rewardProbability = StimParams.Behave.RewardProbability; % 0-1
    boundaryRewardProbability = StimParams.Behave.BoundaryRewardProbability; % 0-1 - reward probability for boundary frequency
    boundaryFreq = StimParams.Vibration.BoundaryFreq; % Hz - frequency boundary for left/right decision

    % Create unique combinations of parameters
    [vibAmp, vibFreq] = ndgrid(vibAmp, vibFreq);
    stimTableUnq = table(vibAmp(:), vibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
    
    % Remove invalid rows
    invalidRows = stimTableUnq.VibAmp == 0 | stimTableUnq.VibFreq == 0;
    stimTableUnq = stimTableUnq(~invalidRows, :);
    
    % Calculate number of blocks needed
    blockSize = height(stimTableUnq);
    numBlocks = floor(nTrials / blockSize);
    remainingRows = mod(nTrials, blockSize);

    % Preallocate StimTable
    StimTable = table('Size', [nTrials, width(stimTableUnq)], 'VariableTypes', varfun(@class, stimTableUnq, 'OutputFormat', 'cell'));
    StimTable.Properties.VariableNames = stimTableUnq.Properties.VariableNames;
    
    % Fill StimTable with randomized blocks
    currentRow = 1;
    for i = 1:numBlocks
        randomBlock = stimTableUnq(randperm(blockSize), :);
        StimTable(currentRow:currentRow+blockSize-1, :) = randomBlock;
        currentRow = currentRow + blockSize;
    end

    % Add remaining rows
    if remainingRows > 0
        randomIndices = randi(blockSize, remainingRows, 1);
        remainingBlock = stimTableUnq(randomIndices, :);
        StimTable(currentRow:end, :) = remainingBlock;
    end

    % Add CorrectSide column based on frequency boundary
    % 1 = left (low frequency), 2 = right (high frequency), 3 = boundary frequency
    StimTable.CorrectSide = ones(height(StimTable), 1); % Initialize to 1 (low frequency)
    StimTable.CorrectSide(StimTable.VibFreq > boundaryFreq) = 2; % High frequency
    StimTable.CorrectSide(StimTable.VibFreq == boundaryFreq) = 3; % Boundary frequency

    % Add in catch trials
    if propCatch > 0
        StimTable = addCatchTrials(StimTable, nTrials, propCatch);
    end
    
    % Add Rewarded column based on reward probability (after catch trials are added)
    % Different reward probabilities for different frequency categories
    randomValues = rand(height(StimTable), 1);
    StimTable.Rewarded = zeros(height(StimTable), 1); % Initialize to 0
    
    % Apply reward probability based on CorrectSide
    % CorrectSide = 1 (low frequency) or 2 (high frequency): use regular reward probability
    regularTrials = (StimTable.CorrectSide == 1) | (StimTable.CorrectSide == 2);
    StimTable.Rewarded(regularTrials) = double(randomValues(regularTrials) <= rewardProbability);
    
    % CorrectSide = 3 (boundary frequency): use boundary reward probability
    boundaryTrials = (StimTable.CorrectSide == 3);
    StimTable.Rewarded(boundaryTrials) = double(randomValues(boundaryTrials) <= boundaryRewardProbability);
    
    % Ensure catch trials are never rewarded (VibFreq = 0)
    catchTrials = (StimTable.VibFreq == 0);
    StimTable.Rewarded(catchTrials) = 0;

     % Add other parameters
     StimTable.VibTypeName = repmat({vibTypeName}, height(StimTable), 1);
end 

% Add catch trials to the stimulus table
function StimTable = addCatchTrials(StimTable, nTrials, propCatch)
    % Calculate number of catch trials
    nCatch = floor(nTrials * propCatch);
    nOrigTrials = nTrials - nCatch;
    
    % First trim table to match nOrigTrials
    if height(StimTable) > nOrigTrials
        StimTable = StimTable(1:nOrigTrials, :);
    end
    
    % Create catch trial template with null values
    catchTrial = table('Size', [1, width(StimTable)], 'VariableTypes', varfun(@class, StimTable, 'OutputFormat', 'cell'));
    catchTrial.Properties.VariableNames = StimTable.Properties.VariableNames;
    
    % Fill catch trial with specific values based on column existence
    for i = 1:width(catchTrial)
        if strcmp(catchTrial.Properties.VariableNames{i}, 'AudIntensity')
            catchTrial.AudIntensity = -inf;
        elseif strcmp(catchTrial.Properties.VariableNames{i}, 'VibAmp') || strcmp(catchTrial.Properties.VariableNames{i}, 'VibFreq')
            catchTrial.VibAmp = 0;
            catchTrial.VibFreq = 0;
        elseif strcmp(catchTrial.Properties.VariableNames{i}, 'CorrectSide')
            % For catch trials, we need to determine CorrectSide based on VibFreq
            % Since catch trials have VibFreq = 0, we'll set CorrectSide based on boundary
            % If boundaryFreq > 0, then VibFreq = 0 < boundaryFreq, so CorrectSide = 1 (low frequency)
            catchTrial.CorrectSide = 1; % Default to low frequency for catch trials (VibFreq = 0)
        elseif strcmp(catchTrial.Properties.VariableNames{i}, 'Rewarded')
            catchTrial.Rewarded = 0; % Catch trials are never rewarded
        end
    end
    
    % Create a new table with nTrials rows
    newStimTable = table('Size', [nTrials, width(StimTable)], 'VariableTypes', varfun(@class, StimTable, 'OutputFormat', 'cell'));
    newStimTable.Properties.VariableNames = StimTable.Properties.VariableNames;
    
    % Randomly select positions for original trials
    origPositions = randperm(nTrials, nOrigTrials);
    origPositions = sort(origPositions);
    
    % Place original trials in their positions
    for i = 1:nOrigTrials
        newStimTable(origPositions(i),:) = StimTable(i,:);
    end
    
    % Fill remaining positions with catch trials
    remainingPositions = setdiff(1:nTrials, origPositions);
    for i = 1:length(remainingPositions)
        newStimTable(remainingPositions(i),:) = catchTrial;
    end
    
    StimTable = newStimTable;
end

end

