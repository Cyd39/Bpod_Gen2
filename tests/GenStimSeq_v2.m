function StimTable = GenStimSeq_v2(StimParams)
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
    
    % Get frequency boundary for separating high and low frequencies
    if isfield(StimParams.Vibration, 'BoundaryFreq')
        frequencyBoundary = StimParams.Vibration.BoundaryFreq;
    else
        frequencyBoundary = []; % No boundary specified, use same amplitude for all
    end
    
    % Check if separate amplitudes for high/low frequencies are specified
    sameAmplitude = true;
    if isfield(StimParams.Vibration, 'Amplitude')
        vibAmp = StimParams.Vibration.Amplitude;
    else
        if isfield(StimParams.Vibration, 'HighFreqAmplitude') && isfield(StimParams.Vibration, 'LowFreqAmplitude')
            vibAmpHigh = StimParams.Vibration.HighFreqAmplitude;
            vibAmpLow = StimParams.Vibration.LowFreqAmplitude;
            sameAmplitude = false;
        else
            % Fallback to Amplitude if separate amplitudes not found
            vibAmp = StimParams.Vibration.Amplitude;
        end
    end
    
    switch soundTypeName
        case 'Noise Burst'
            sndLevel = StimParams.Sound.Noise.Level;
            vibFreq = StimParams.Vibration.Frequency;

            % If frequency boundary is specified and different amplitudes are used, separate by frequency
            if ~isempty(frequencyBoundary) && ~sameAmplitude
                % Separate high and low frequency vibrations
                highVibFreq = vibFreq(vibFreq > frequencyBoundary);
                lowVibFreq = vibFreq(vibFreq < frequencyBoundary);
                boundaryVibFreq = vibFreq(vibFreq == frequencyBoundary);
                
                % Generate high frequency combinations
                highStimTableUnq = table();
                if ~isempty(highVibFreq)
                    [highSndLevel, highVibAmp, highVibFreqGrid] = ndgrid(sndLevel, vibAmpHigh, highVibFreq);
                    highStimTableUnq = table(highSndLevel(:), highVibAmp(:), highVibFreqGrid(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                    invalidRows = highStimTableUnq.AudIntensity == -inf & (highStimTableUnq.VibAmp == 0 | highStimTableUnq.VibFreq == 0);
                    highStimTableUnq = highStimTableUnq(~invalidRows, :);
                end
                
                % Generate low frequency combinations
                lowStimTableUnq = table();
                if ~isempty(lowVibFreq)
                    [lowSndLevel, lowVibAmp, lowVibFreqGrid] = ndgrid(sndLevel, vibAmpLow, lowVibFreq);
                    lowStimTableUnq = table(lowSndLevel(:), lowVibAmp(:), lowVibFreqGrid(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                    invalidRows = lowStimTableUnq.AudIntensity == -inf & (lowStimTableUnq.VibAmp == 0 | lowStimTableUnq.VibFreq == 0);
                    lowStimTableUnq = lowStimTableUnq(~invalidRows, :);
                end
                
                % Generate boundary frequency combinations (use high amplitude)
                boundaryStimTableUnq = table();
                if ~isempty(boundaryVibFreq)
                    [boundarySndLevel, boundaryVibAmp, boundaryVibFreqGrid] = ndgrid(sndLevel, vibAmpHigh, boundaryVibFreq);
                    boundaryStimTableUnq = table(boundarySndLevel(:), boundaryVibAmp(:), boundaryVibFreqGrid(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                    invalidRows = boundaryStimTableUnq.AudIntensity == -inf & (boundaryStimTableUnq.VibAmp == 0 | boundaryStimTableUnq.VibFreq == 0);
                    boundaryStimTableUnq = boundaryStimTableUnq(~invalidRows, :);
                end
                
                % Combine all frequency categories
                stimTableUnq = table();
                if ~isempty(highStimTableUnq)
                    stimTableUnq = [stimTableUnq; highStimTableUnq];
                end
                if ~isempty(lowStimTableUnq)
                    stimTableUnq = [stimTableUnq; lowStimTableUnq];
                end
                if ~isempty(boundaryStimTableUnq)
                    stimTableUnq = [stimTableUnq; boundaryStimTableUnq];
                end
            else
                % Use same amplitude for all frequencies (original behavior)
                [sndLevel, vibAmp, vibFreq] = ndgrid(sndLevel, vibAmp, vibFreq);
                stimTableUnq = table(sndLevel(:), vibAmp(:), vibFreq(:), 'VariableNames', {'AudIntensity', 'VibAmp', 'VibFreq'});
                
                % Remove combinations that would be equivalent to catch trials
                invalidRows = stimTableUnq.AudIntensity == -inf & (stimTableUnq.VibAmp == 0 | stimTableUnq.VibFreq == 0);
                stimTableUnq = stimTableUnq(~invalidRows, :);
            end
            
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
            StimTable.AudFreqMin = repmat(StimParams.Sound.Noise.FreqMin, height(StimTable), 1);
            StimTable.AudFreqMax = repmat(StimParams.Sound.Noise.FreqMax, height(StimTable), 1);
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

            % Fill StimTable with randomized blocks
            StimTable = fillUpBlocks(stimTableUnq, nTrials);

            % Add in catch trials
            if propCatch > 0
                StimTable = addCatchTrials(StimTable, nTrials, propCatch);
            end

             % Add other parameters
             StimTable.AudFreqMin = repmat(StimParams.Sound.Noise.FreqMin, height(StimTable), 1);
             StimTable.AudFreqMax = repmat(StimParams.Sound.Noise.FreqMax, height(StimTable), 1);
             StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
             StimTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(StimTable), 1);
        case 'AM Noise'
            Dur		=	StimParams.Duration; %ms

            %-- Auditory parameters --%
            Sndlvl	=	StimParams.Sound.Noise.Intensity; % dB
            Sndvel	=	StimParams.Sound.AM.ModFreq; % Hz
            Sndmd	=	StimParams.Sound.AM.ModDepth; % [0,1]
            Sndtrans = StimParams.Sound.AM.TransitionTime / 1000; %ms -> s
            SndMask = 0;

            %-- Unimodal auditory stimulus parameters --%
            if (any(Sndmd == 0));    addZero = 1; else; addZero = 0; end
            Sndmd = Sndmd(Sndmd ~= 0);Sndvel = Sndvel(Sndvel ~= 0);

            [Mf,Md,Intensity,TransTime,MaskBand]	=	ndgrid(Sndvel',Sndmd',Sndlvl',Sndtrans',SndMask');
            Mf          =	Mf(:);
            Md          =	Md(:);
            Intensity	=	Intensity(:);
            TransTime   =   TransTime(:);
            MaskBand   =   MaskBand(:);
            
            if (addZero) % zero modulation
                [ZeroSpeaker,ZeroIntensity,ZeroTransTime]	=	ndgrid(Sndloc',Sndlvl',Sndtrans');
                ZeroSpeaker = ZeroSpeaker(:);
                ZeroIntensity = ZeroIntensity(:);
                ZeroTransTime = ZeroTransTime(:);
            
                NZero        = length(ZeroIntensity); 
                Intensity   = [Intensity; ZeroIntensity(:)]; % different intensities
                Speaker     = [Speaker;ZeroSpeaker]; % assume single speaker
                Mf          = [Mf;zeros(NZero,1)]; % Mf = 0
                Md          = [Md;zeros(NZero,1)]; % Md = 0
                TransTime  = [TransTime;ZeroTransTime]; %
                MaskBand  = [MaskBand;zeros(NZero,1)]; % masking does not matter.
            end

            stimTableUnq    =	table(Mf, Md, Intensity, TransTime,MaskBand, ...
                                       'VariableNames', {'ModFreq','ModDepth','AudIntensity',...
                                                        'TransTime','MaskBand'});
            % Fill StimTable with randomized blocks
            StimTable = fillUpBlocks(stimTableUnq, nTrials);

            % Add in catch trials
            if propCatch > 0
                StimTable = addCatchTrials(StimTable, nTrials, propCatch);
            end

            StimTable.AudFreqMin = repmat(StimParams.Sound.Noise.FreqMin, height(StimTable), 1);
            StimTable.AudFreqMax = repmat(StimParams.Sound.Noise.FreqMax, height(StimTable), 1);
            StimTable.SndTypeName = repmat({soundTypeName}, height(StimTable), 1);
            StimTable.TransDur = repmat(StimParams.Sound.AM.TransitionDuration / 1000, height(StimTable), 1); % ms -> s
            StimTable.LogDensity = repmat(StimParams.Sound.Noise.LogDen, height(StimTable), 1);
            StimTable.RiseTime = repmat(StimParams.Sound.Ramp, height(StimTable), 1);
            StimTable.FallTime = repmat(StimParams.Sound.Ramp, height(StimTable), 1);

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
    
    % Extract stimulus pairs from the new structure
    if ~isfield(StimParams.Vibration, 'Stimulus') || isempty(StimParams.Vibration.Stimulus)
        error('Vibration.Stimulus not found in StimParams or is empty');
    end
    
    stimStruct = StimParams.Vibration.Stimulus;

    % Convert struct array to arrays of freq and amp
    vibFreq = [stimStruct.freq];
    vibAmp = [stimStruct.amp];

    % Get reward probability and boundary frequency parameters
    rewardProbability = StimParams.Behave.RewardProbability; % 0-1
    boundaryRewardProbability = StimParams.Behave.BoundaryRewardProbability; % 0-1 - reward probability for boundary frequency
    boundaryProb = StimParams.Behave.BoundaryProbability; % 0-1 - probability of boundary frequency trials
    boundaryFreq = StimParams.Vibration.BoundaryFreq; % Hz - frequency boundary for left/right decision

    % Separate high and low frequency vibrations based on boundary frequency
    highVibFreqIdx = find(vibFreq > boundaryFreq);
    lowVibFreqIdx = find(vibFreq < boundaryFreq);
    boundaryVibFreqIdx = find(vibFreq == boundaryFreq);
    
    % Calculate number of boundary frequency trials based on BoundaryProbability
    nBoundaryTrials = round(nTrials * boundaryProb);
    nRegularTrials = nTrials - nBoundaryTrials;
    
    % For high frequency (regular trials)
    highStimTableUnq = table();
    if ~isempty(highVibFreqIdx)
        highVibFreq = vibFreq(highVibFreqIdx);
        highVibAmp = vibAmp(highVibFreqIdx);
        
        % Create table directly from the stimulus pairs
        highStimTableUnq = table(highVibAmp(:), highVibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
        
        % Remove invalid rows
        invalidRows = highStimTableUnq.VibAmp == 0 | highStimTableUnq.VibFreq == 0;
        highStimTableUnq = highStimTableUnq(~invalidRows, :);
    end
    
    % For low frequency (regular trials)
    lowStimTableUnq = table();
    if ~isempty(lowVibFreqIdx)
        lowVibFreq = vibFreq(lowVibFreqIdx);
        lowVibAmp = vibAmp(lowVibFreqIdx);
        
        % Create table directly from the stimulus pairs
        lowStimTableUnq = table(lowVibAmp(:), lowVibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
        
        % Remove invalid rows
        invalidRows = lowStimTableUnq.VibAmp == 0 | lowStimTableUnq.VibFreq == 0;
        lowStimTableUnq = lowStimTableUnq(~invalidRows, :);
    end
    
    % Combine high and low frequency tables for regular trials
    regularStimTableUnq = table();
    if ~isempty(highStimTableUnq)
        regularStimTableUnq = highStimTableUnq;
    end
    if ~isempty(lowStimTableUnq)
        if height(regularStimTableUnq) == 0
            regularStimTableUnq = lowStimTableUnq;
        else
            regularStimTableUnq = [regularStimTableUnq; lowStimTableUnq];
        end
    end
    
    % For boundary frequency (only use exact matches)
    boundaryStimTableUnq = table();
    if ~isempty(boundaryVibFreqIdx) && nBoundaryTrials > 0
        boundaryVibFreq = vibFreq(boundaryVibFreqIdx);
        boundaryVibAmp = vibAmp(boundaryVibFreqIdx);
        
        % Create table from matching pairs
        boundaryStimTableUnq = table(boundaryVibAmp(:), boundaryVibFreq(:), 'VariableNames', {'VibAmp', 'VibFreq'});
        
        % Remove invalid rows
        invalidRows = boundaryStimTableUnq.VibAmp == 0 | boundaryStimTableUnq.VibFreq == 0;
        boundaryStimTableUnq = boundaryStimTableUnq(~invalidRows, :);
    end
    
    % Check if we have valid stimulus combinations
    if height(regularStimTableUnq) == 0 && nRegularTrials > 0
        error('No valid regular stimulus combinations found. Please check your amplitude and frequency parameters.');
    end
    
    % Generate regular trials (high + low frequency)
    if nRegularTrials > 0 && height(regularStimTableUnq) > 0
        blockSize = height(regularStimTableUnq);
        numBlocks = floor(nRegularTrials / blockSize);
        remainingRows = mod(nRegularTrials, blockSize);

        % Preallocate regularStimTable
        regularStimTable = table('Size', [nRegularTrials, width(regularStimTableUnq)], ...
                                'VariableTypes', varfun(@class, regularStimTableUnq, 'OutputFormat', 'cell'));
        regularStimTable.Properties.VariableNames = regularStimTableUnq.Properties.VariableNames;
        
        % Fill with randomized blocks
        currentRow = 1;
        for i = 1:numBlocks
            randomBlock = regularStimTableUnq(randperm(blockSize), :);
            regularStimTable(currentRow:currentRow+blockSize-1, :) = randomBlock;
            currentRow = currentRow + blockSize;
        end

        % Add remaining rows
        if remainingRows > 0
            randomIndices = randi(blockSize, remainingRows, 1);
            remainingBlock = regularStimTableUnq(randomIndices, :);
            regularStimTable(currentRow:end, :) = remainingBlock;
        end
    else
        regularStimTable = table('Size', [nRegularTrials, 0]);
    end
    
    % Generate boundary frequency trials
    if nBoundaryTrials > 0 && height(boundaryStimTableUnq) > 0
        boundaryBlockSize = height(boundaryStimTableUnq);
        boundaryNumBlocks = floor(nBoundaryTrials / boundaryBlockSize);
        boundaryRemainingRows = mod(nBoundaryTrials, boundaryBlockSize);

        % Preallocate boundaryStimTable
        boundaryStimTable = table('Size', [nBoundaryTrials, width(boundaryStimTableUnq)], ...
                                 'VariableTypes', varfun(@class, boundaryStimTableUnq, 'OutputFormat', 'cell'));
        boundaryStimTable.Properties.VariableNames = boundaryStimTableUnq.Properties.VariableNames;
        
        % Fill with randomized blocks
        currentRow = 1;
        for i = 1:boundaryNumBlocks
            randomBlock = boundaryStimTableUnq(randperm(boundaryBlockSize), :);
            boundaryStimTable(currentRow:currentRow+boundaryBlockSize-1, :) = randomBlock;
            currentRow = currentRow + boundaryBlockSize;
        end

        % Add remaining rows
        if boundaryRemainingRows > 0
            randomIndices = randi(boundaryBlockSize, boundaryRemainingRows, 1);
            remainingBlock = boundaryStimTableUnq(randomIndices, :);
            boundaryStimTable(currentRow:end, :) = remainingBlock;
        end
    else
        boundaryStimTable = table('Size', [nBoundaryTrials, 0]);
        if ~isempty(boundaryVibFreqIdx) && boundaryProb > 0
            disp(['Note: BoundaryProbability = ', num2str(boundaryProb), ...
                  ', but no valid boundary frequency stimuli found. No boundary trials will be generated.']);
        elseif boundaryProb > 0
            disp(['Note: BoundaryProbability = ', num2str(boundaryProb), ...
                  ', but no boundary frequency stimuli match the boundary frequency (', num2str(boundaryFreq), ' Hz).']);
        end
    end
    
    % Concatenate regular and boundary trials with random interleaving
    if height(regularStimTable) > 0 && height(boundaryStimTable) > 0
        % Combine both tables
        combinedTable = [regularStimTable; boundaryStimTable];
        
        % Create a random permutation of row indices
        totalRows = height(combinedTable);
        randomOrder = randperm(totalRows);
        
        % Shuffle the table using the random permutation
        StimTable = combinedTable(randomOrder, :);
        
        disp(['Trials will be randomly interleaved (boundary trials: ' num2str(nBoundaryTrials) '/' num2str(totalRows) ')']);
    elseif height(regularStimTable) > 0
        StimTable = regularStimTable;
    elseif height(boundaryStimTable) > 0
        StimTable = boundaryStimTable;
    else
        error('No valid stimulus combinations found. Please check your amplitude and frequency parameters.');
    end

    % Add CorrectSide column based on frequency boundary and user configuration
    % 1 = left, 2 = right, 3 = boundary frequency (both sides correct)
    % Get side configuration from StimParamGui
    if isfield(StimParams.Behave, 'CorrectSpout')
        highFreqSpout = StimParams.Behave.CorrectSpout; % 1 = left, 2 = right
        lowFreqSpout = 3 - highFreqSpout; % Opposite of high frequency spout
    else
        % Default configuration if not specified
        highFreqSpout = 2; % Default: high frequency -> right
        lowFreqSpout = 1;  % Default: low frequency -> left
        warning('CorrectSpout not found in StimParams.Behave, using default configuration (high freq -> right, low freq -> left)');
    end
    
    % Initialize CorrectSide based on frequency relative to boundary
    StimTable.CorrectSide = repmat(lowFreqSpout, height(StimTable), 1); % Initialize to low frequency spout
    StimTable.CorrectSide(StimTable.VibFreq > boundaryFreq) = highFreqSpout; % High frequency -> configured spout
    StimTable.CorrectSide(StimTable.VibFreq == boundaryFreq) = 3; % Boundary frequency -> both sides correct
    
    % Display configuration for user verification
    spoutNames = {'left', 'right'};
    disp(['Frequency-Side Configuration:']);
    disp(['  High frequency (>' num2str(boundaryFreq) ' Hz) -> ' spoutNames{highFreqSpout} ' spout']);
    disp(['  Low frequency (<' num2str(boundaryFreq) ' Hz) -> ' spoutNames{lowFreqSpout} ' spout']);
    disp(['  Boundary frequency (' num2str(boundaryFreq) ' Hz) -> both spouts correct']);
    if nBoundaryTrials > 0
        disp(['  Expected boundary trials: ' num2str(nBoundaryTrials) ' out of ' num2str(nTrials) ' total trials (' ...
              num2str(boundaryProb*100) '%)']);
    end

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
     StimTable.VibWaveform = repmat({StimParams.Vibration.TypeName}, height(StimTable), 1);
end 

% fill up blocks
    function StimTable = fillUpBlocks(stimTableUnq, nTrials)
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

