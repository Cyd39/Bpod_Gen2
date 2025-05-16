function StimTable = GenStimSeq(StimParams)
% GenStimSeq - Generate stimulus sequence and waveforms
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   StimTable - Table containing stimulus parameters for each trial

% Generate stimuli for each trial
nTrials = StimParams.Behave.NumTrials;
   
% Extract timing parameters
Dur = str2double(StimParams.AMStimTime);

% Extract auditory parameters
Sndlvl = eval(StimParams.AMLevel);
Sndvel = eval(StimParams.AMVelocity);
Sndmd = eval(StimParams.AMModDepth);
F0 = str2double(StimParams.AMF0);
Nfreq = str2double(StimParams.AMNFreq);

% Get number of repetitions
Nrep = str2double(StimParams.Behave.NumRepetitions);

% Handle unmodulated condition
if (any(Sndmd == 0))
    addZero = 1;
else 
    addZero = 0;
end
Sndmd = Sndmd(Sndmd ~= 0);

% Create parameter grid
[Mf, Md, Intensity] = ndgrid(Sndvel', Sndmd', Sndlvl');

% Reshape parameters
Mf = Mf(:);
Md = Md(:);
Intensity = Intensity(:);

% Add unmodulated condition if needed
if (addZero)
    NLvl = length(Sndlvl);
    Intensity = [Intensity; Sndlvl(:)];
    Mf = [Mf; zeros(NLvl, 1)];
    Md = [Md; zeros(NLvl, 1)];
end

% Create parameter table
StimTable = table(Mf, Md, Intensity);

% Randomize trials within blocks
StimTable = randomizeTrials(StimTable, Nrep);

% Get number of trials
NStm = height(StimTable);

% Add static parameters
StimTable.Set = repmat(Nname, NStm, 1);
StimTable.StimT = repmat(Dur, NStm, 1);
StimTable.F0 = repmat(F0, NStm, 1);
StimTable.Nfreq = repmat(Nfreq, NStm, 1);
end

function StmTable = randomizeTrials(StmTable, Nrep)
% RANDOMIZETRIALS Randomize trial order within each block
% Input:
%   Stm - Original parameter table
%   Nrep - Number of repetitions
% Output:
%   Stm - Randomized parameter table with trials shuffled within each block

% Get original number of trials
nTrials = height(StmTable);

% Create repeated trials
StmTable = repmat(StmTable, Nrep, 1);

% Get total number of trials
nTotal = height(StmTable);

% Calculate number of trials per block
nTrialsPerBlock = nTrials;

% Initialize shuffled indices
shuffledIdx = zeros(nTotal, 1);

% Shuffle trials within each block
for i = 1:Nrep
    % Calculate start and end indices for current block
    startIdx = (i-1)*nTrialsPerBlock + 1;
    endIdx = i*nTrialsPerBlock;
    
    % Generate random permutation for current block
    blockIdx = randperm(nTrialsPerBlock);
    
    % Add block offset to indices
    blockIdx = blockIdx + (i-1)*nTrialsPerBlock;
    
    % Store shuffled indices
    shuffledIdx(startIdx:endIdx) = blockIdx;
end

% Randomize trial order
StmTable = StmTable(shuffledIdx, :);
end
