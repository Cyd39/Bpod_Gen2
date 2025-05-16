function StimTable = GenStimSeq(StimParams)
% GenStimSeq - Generate stimulus sequence table for each trial
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   StimTable - Table containing stimulus parameters for each trial

% get general parameters
nTrials = StimParams.Behave.NumTrials;
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

end
