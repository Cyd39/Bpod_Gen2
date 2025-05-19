function StimTable = GenStimSeq(StimParams)
% GenStimSeq - Generate stimulus sequence table for each trial
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   StimTable - Table containing stimulus parameters for each trial

% get general parameters
nTrials = StimParams.Behave.NumTrials;
percCatch = 0.2;
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

% Add in catch trials
StimTable = addCatchTrials(StimTable, nTrials, percCatch);

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
        case 'White Noise'
            sndLevel = StimParams.Sound.Noise.Level;
            vibAmp = StimParams.Vibration.Amplitude;
            vibFreq = StimParams.Vibration.Frequency;

            % Create unique combinations of parameters
            [sndLevel, vibAmp, vibFreq] = ndgrid(sndLevel, vibAmp, vibFreq);
            stimTableUnq = table(sndLevel(:), vibAmp(:), vibFreq(:), 'VariableNames', {'SndLevel', 'VibAmp', 'VibFreq'});
            
            % Calculate number of blocks needed
            blockSize = height(stimTableUnq);
            numBlocks = floor(nTrials / blockSize);
            remainingRows = mod(nTrials, blockSize);

            % Initialize stimTable
            StimTable = table();

            % Randomize blocks and add to stimTable
            for i = 1:numBlocks
                randomBlock = stimTableUnq(randperm(blockSize), :);
                StimTable = [StimTable; randomBlock];
            end

            % Add remaining rows
            if remainingRows > 0
                randomIndices = randi(blockSize, remainingRows, 1);
                remainingBlock = stimTableUnq(randomIndices, :);
                StimTable = [StimTable; remainingBlock];
            end

            % Add other parameters
            StimTable.Duration = repmat(StimParams.Duration, height(StimTable), 1);
            StimTable.RampDur = repmat(StimParams.Ramp, height(StimTable), 1);
            StimTable.SndLow = repmat(StimParams.Sound.Noise.LowFreq, height(StimTable), 1);
            StimTable.SndHigh = repmat(StimParams.Sound.Noise.HighFreq, height(StimTable), 1);
            StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
            StimTable.VibTypeName = repmat({vibTypeName}, height(StimTable), 1);
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
        case 'Bandpass Noise'
            % pass
    end

end

% Generate stimulus table for sound only condition
function StimTable = makeSndTable(StimParams)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    soundTypeName = StimParams.Sound.TypeName;
    switch soundTypeName
        case 'White Noise'
            sndLevel = StimParams.Sound.Noise.Level;

            % Create unique combinations of parameters
            [sndLevel] = ndgrid(sndLevel);
            stimTableUnq = table(sndLevel(:), 'VariableNames', {'SndLevel'});
            
            % Calculate number of blocks needed
            blockSize = height(stimTableUnq);
            numBlocks = floor(nTrials / blockSize);
            remainingRows = mod(nTrials, blockSize);

            % Initialize stimTable
            StimTable = table();

            % Randomize blocks and add to stimTable
            for i = 1:numBlocks
                randomBlock = stimTableUnq(randperm(blockSize), :);
                StimTable = [StimTable; randomBlock];
            end

            % Add remaining rows
            if remainingRows > 0
                randomIndices = randi(blockSize, remainingRows, 1);
                remainingBlock = stimTableUnq(randomIndices, :);
                StimTable = [StimTable; remainingBlock];
            end

             % Add other parameters
             StimTable.Duration = repmat(StimParams.Duration, height(StimTable), 1);
             StimTable.RampDur = repmat(StimParams.Ramp, height(StimTable), 1);
             StimTable.SndLow = repmat(StimParams.Sound.Noise.LowFreq, height(StimTable), 1);
             StimTable.SndHigh = repmat(StimParams.Sound.Noise.HighFreq, height(StimTable), 1);
             StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
        case 'AM Noise'
            % pass
        case 'Click Train'
            % pass
        case 'Bandpass Noise'
            % pass
    end

end

% Generate stimulus table for vibration only condition
function StimTable = makeVibTable(StimParams)
    % get general parameters
    nTrials = StimParams.Behave.NumTrials;
    vibTypeName = StimParams.Vibration.TypeName;
    vibAmp = StimParams.Vibration.Amplitude;
    vibFreq = StimParams.Vibration.Frequency;

    % Create unique combinations of parameters
    [vibAmp, vibFreq] = ndgrid(vibAmp, vibFreq);
    stimTableUnq = table(vibAmp(:), vibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
    
    % Calculate number of blocks needed
    blockSize = height(stimTableUnq);
    numBlocks = floor(nTrials / blockSize);
    remainingRows = mod(nTrials, blockSize);

    % Initialize stimTable
    StimTable = table();

    % Randomize blocks and add to stimTable
    for i = 1:numBlocks
        randomBlock = stimTableUnq(randperm(blockSize), :);
        StimTable = [StimTable; randomBlock];
    end

    % Add remaining rows
    if remainingRows > 0
        randomIndices = randi(blockSize, remainingRows, 1);
        remainingBlock = stimTableUnq(randomIndices, :);
        StimTable = [StimTable; remainingBlock];
    end

     % Add other parameters
     StimTable.Duration = repmat(StimParams.Duration, height(StimTable), 1);
     StimTable.RampDur = repmat(StimParams.Ramp, height(StimTable), 1);
     StimTable.VibTypeName = repmat({vibTypeName}, height(StimTable), 1);
end 

% Add catch trials to the stimulus table
function StimTable = addCatchTrials(StimTable, nTrials, percCatch)
    % Calculate number of catch trials
    nCatch = floor(nTrials * percCatch);
    
    % Create catch trial template with null values
    catchTrial = table('Size', [1, width(StimTable)], 'VariableTypes', varfun(@class, StimTable, 'OutputFormat', 'cell'));
    catchTrial.Properties.VariableNames = StimTable.Properties.VariableNames;
    
    % Fill catch trial with NaN for numeric columns and 'null' for string/cell columns
    for i = 1:width(catchTrial)
        if isnumeric(StimTable{1,i})
            catchTrial{1,i} = NaN;
        else
            catchTrial{1,i} = {'null'};
        end
    end
    
    % Generate valid positions for catch trials (ensuring no consecutive positions)
    validPositions = 1:height(StimTable);
    catchPositions = zeros(1, nCatch);
    
    for i = 1:nCatch
        if isempty(validPositions)
            warning('Not enough valid positions for all catch trials');
            break;
        end
        % Randomly select a position from valid positions
        posIdx = randi(length(validPositions));
        catchPositions(i) = validPositions(posIdx);
        
        % Remove the selected position and its adjacent positions from valid positions
        validPositions = validPositions(~ismember(validPositions, ...
            [catchPositions(i)-1, catchPositions(i), catchPositions(i)+1]));
    end
    
    % Remove any unused positions (if we couldn't place all catch trials)
    catchPositions = catchPositions(catchPositions > 0);
    
    % Sort positions in descending order to avoid index shifting during insertion
    catchPositions = sort(catchPositions, 'descend');
    
    % Insert catch trials
    for i = 1:length(catchPositions)
        StimTable = [StimTable(1:catchPositions(i)-1,:); catchTrial; StimTable(catchPositions(i):end,:)];
    end
    
    % Trim table to match nTrials
    if height(StimTable) > nTrials
        StimTable = StimTable(1:nTrials, :);
    end
end

end

