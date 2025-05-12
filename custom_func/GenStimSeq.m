function [StimSeq, StimWave] = GenStimSeq(Par)
% GenStimSeq - Generate stimulus sequence and waveforms
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   StimSeq - Table containing stimulus parameters for each trial
%   StimWave - Structure containing generated stimulus waveforms

% Get stimulus parameters using internal function
StimSeq = generateStimParams(Par);

% Initialize output structure
StimWave = struct();
StimWave.Fs = 192000;  % Sampling frequency
StimWave.Stm = StimSeq;    % Store stimulus parameters

% Generate stimuli for each trial
nTrials = height(StimSeq);
StimWave.Snd = cell(nTrials, 1);  % Cell array to store sound stimuli

% Loop through each trial
for i = 1:nTrials
    % Get parameters for current trial
    Dur = StimSeq.StimT(i) / 1000;  % Convert ms to s
    Int = StimSeq.Intensity(i);
    Mf = StimSeq.Mf(i);
    Md = StimSeq.Md(i);
    fLow = StimSeq.F0(i);
    fHigh = StimSeq.Nfreq(i);
    
    % Default parameters for genamnoise
    useLogDen = 1;  % Use logarithmic density
    maskBand = 0;   % No masking
    transTime = -1; % No transition
    transDur = 0;   % No transition duration
    RiseTime = 5e-3; % 5ms rise time
    FallTime = 5e-3; % 5ms fall time
    Spk = 1;        % Default speaker
    Gain = [1 1 1]; % Default gain
    Ref = [1 1 1];  % Default reference
    
    % Generate stimulus using genamnoise
    [Snd, Fs] = genamnoise(Dur, Int, Mf, Md, fLow, fHigh, useLogDen,...
                          maskBand, transTime, transDur, RiseTime, FallTime,...
                          Par.Fs, Spk, Gain, Ref);
    
    % Store generated stimulus
    StimWave.Snd{i} = Snd;
end

% Add timing information
StimWave.PreT = StimSeq.PreT;
StimWave.StimT = StimSeq.StimT;
StimWave.PostT = StimSeq.PostT;
StimWave.ISI = StimSeq.ISI;

% Add metadata
StimWave.MouseNum = StimSeq.MouseNum(1);
StimWave.Set = StimSeq.Set(1);
StimWave.Pen = StimSeq.Pen(1);

end

function Stm = generateStimParams(Par)
% GENERATESTIMPARAMS Generate stimulus parameters table
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   Stm - Table containing stimulus parameters for each trial

% Extract basic parameters
Aname = str2double(Par.MouseNum);
Nname = str2double(Par.Set);
Pen = str2double(Par.Penetration);

% Extract timing parameters
Dur = str2double(Par.AMStimTime);
PreRec = str2double(Par.AMPreTime);
PostRec = str2double(Par.AMPostTime);
ISI = str2double(Par.AMISI);

% Extract auditory parameters
Sndloc = str2double(Par.AMLocation);
Sndlvl = eval(Par.AMLevel);
Sndvel = eval(Par.AMVelocity);
Sndmd = eval(Par.AMModDepth);
F0 = str2double(Par.AMF0);
Nfreq = str2double(Par.AMNFreq);

% Get number of repetitions
Nrep = str2double(Par.AMRepetitions);

% Handle unmodulated condition
if (any(Sndmd == 0))
    addZero = 1;
else 
    addZero = 0;
end
Sndmd = Sndmd(Sndmd ~= 0);

% Create parameter grid
[Mf, Md, Speaker, Intensity] = ndgrid(Sndvel', Sndmd', Sndloc', Sndlvl');

% Reshape parameters
Mf = Mf(:);
Md = Md(:);
Speaker = Speaker(:);
Intensity = Intensity(:);

% Add unmodulated condition if needed
if (addZero)
    NLvl = length(Sndlvl);
    Intensity = [Intensity; Sndlvl(:)];
    Speaker = [Speaker; repmat(Sndloc, NLvl, 1)];
    Mf = [Mf; zeros(NLvl, 1)];
    Md = [Md; zeros(NLvl, 1)];
end

% Create parameter table
Stm = table(Mf, Md, Intensity, Speaker);

% Randomize trials within blocks
Stm = randomizeTrials(Stm, Nrep);

% Get number of trials
NStm = height(Stm);

% Add static parameters
Stm.MouseNum = repmat(Aname, NStm, 1);
Stm.Set = repmat(Nname, NStm, 1);
Stm.Pen = repmat(Pen, NStm, 1);
Stm.PreT = repmat(PreRec, NStm, 1);
Stm.StimT = repmat(Dur, NStm, 1);
Stm.PostT = repmat(PostRec, NStm, 1);
Stm.F0 = repmat(F0, NStm, 1);
Stm.Nfreq = repmat(Nfreq, NStm, 1);

% Add randomized ISI
Stm.ISI = randomizeISI(ISI, NStm);

end

function Stm = randomizeTrials(Stm, Nrep)
% RANDOMIZETRIALS Randomize trial order within each block
% Input:
%   Stm - Original parameter table
%   Nrep - Number of repetitions
% Output:
%   Stm - Randomized parameter table with trials shuffled within each block

% Get original number of trials
nTrials = height(Stm);

% Create repeated trials
Stm = repmat(Stm, Nrep, 1);

% Get total number of trials
nTotal = height(Stm);

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
Stm = Stm(shuffledIdx, :);

end

function isi = randomizeISI(ISI, N)
% RANDOMIZEISI Generate random inter-stimulus intervals
% Input:
%   ISI - Mean ISI in ms
%   N - Number of trials
% Output:
%   isi - Vector of random ISIs

% Generate random ISIs between 0.5 and 1.5 times the mean
isi = ISI * (0.5 + rand(N, 1));

end
