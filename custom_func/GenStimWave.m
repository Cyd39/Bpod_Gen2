function OutputWave = GenStimWave(StimParams)
% GenStimWave - Generate stimulus waveforms based on parameters
% Input:
%   StimParams - Single row from StimSeq table containing trial parameters
%   Fs - Sampling frequency
% Output:
%   OutputWave - Combined waveform (stereo: [sound, vibration])
Fs = 192000;
% Generate sound waveform based on type
switch StimParams.SoundType
    case "AM Noise"
        % Generate AM noise
        t = (0:1/Fs:StimParams.SoundDuration/1000)';
        carrier = sin(2*pi*StimParams.CarrierFreq*t);
        modulator = 1 + StimParams.AMDepth * sin(2*pi*StimParams.AMFrequency*t);
        SoundWave = StimParams.SoundVolume * carrier .* modulator;
        
        % Apply bandpass filter
        [b,a] = butter(4, [StimParams.CarrierFreq-StimParams.BandWidth/2, ...
            StimParams.CarrierFreq+StimParams.BandWidth/2]/(Fs/2), 'bandpass');
        SoundWave = filtfilt(b, a, SoundWave);
        
        % Apply transition envelope
        if StimParams.TransTime > 0
            ramp = hanning(round(StimParams.TransTime*Fs*2));
            ramp = ramp(1:round(length(ramp)/2));
            SoundWave(1:length(ramp)) = SoundWave(1:length(ramp)) .* ramp;
            SoundWave(end-length(ramp)+1:end) = SoundWave(end-length(ramp)+1:end) .* flip(ramp);
        end
        
    case "Click Train"
        % Generate click train
        t = (0:1/Fs:StimParams.SoundDuration/1000)';
        clickInterval = round(Fs/StimParams.ClickRate);
        SoundWave = zeros(size(t));
        
        for i = 1:clickInterval:length(t)
            if i <= length(t)
                SoundWave(i) = StimParams.ClickAmplitude;
            end
        end
        
        % Add mask noise
        maskNoise = StimParams.MaskIntensity * randn(size(t));
        SoundWave = SoundWave + maskNoise;
        
    case "Noise"
        % Generate bandpass noise
        t = (0:1/Fs:StimParams.SoundDuration/1000)';
        noise = randn(size(t));
        [b,a] = butter(4, [StimParams.LowFreq, StimParams.HighFreq]/(Fs/2), 'bandpass');
        SoundWave = StimParams.NoiseIntensity * filtfilt(b, a, noise);
end

% Generate vibration waveform
t = (0:1/Fs:StimParams.VibDuration/1000)';
switch StimParams.VibType
    case "Square"
        VibWave = StimParams.VibAmplitude * ones(size(t));
    case "UniSine"
        VibWave = StimParams.VibAmplitude * (1 - cos(2*pi*StimParams.VibFrequency*t))/2;
    case "BiSine"
        VibWave = StimParams.VibAmplitude * sin(2*pi*StimParams.VibFrequency*t);
end

% Apply ramp to vibration
if StimParams.VibRamp > 0
    ramp = hanning(round(StimParams.VibRamp*Fs*2));
    ramp = ramp(1:round(length(ramp)/2));
    VibWave(1:length(ramp)) = VibWave(1:length(ramp)) .* ramp;
    VibWave(end-length(ramp)+1:end) = VibWave(end-length(ramp)+1:end) .* flip(ramp);
end

% Combine sound and vibration into stereo output
% Make sure both signals have the same length
maxLength = max(length(SoundWave), length(VibWave));
OutputWave = zeros(maxLength, 2);

% Put sound in left channel
OutputWave(1:length(SoundWave), 1) = SoundWave;

% Put vibration in right channel
OutputWave(1:length(VibWave), 2) = VibWave;

end

function Stim = GenStimWave(Par)
% GenStim - Generate stimuli based on parameters from StimParamGui
% Input:
%   Par - Structure containing parameters from StimParamGui
% Output:
%   Stim - Structure containing generated stimuli
%   Fs - Sampling frequency

% Get stimulus parameters using makeAMstm
Stm = makeAMstm(Par);

% Initialize output structure
Stim = struct();
Stim.Fs = 192000;  % Sampling frequency
Stim.Stm = Stm;    % Store stimulus parameters

% Generate stimuli for each trial
nTrials = height(Stm);
Stim.Snd = cell(nTrials, 1);  % Cell array to store sound stimuli

% Loop through each trial
for i = 1:nTrials
    % Get parameters for current trial
    Dur = Stm.StimT(i) / 1000;  % Convert ms to s
    Int = Stm.Intensity(i);
    Mf = Stm.Mf(i);
    Md = Stm.Md(i);
    fLow = Stm.F0(i);
    fHigh = Stm.Nfreq(i);
    
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
    Stim.Snd{i} = Snd;
end

% Add timing information
Stim.PreT = Stm.PreT;
Stim.StimT = Stm.StimT;
Stim.PostT = Stm.PostT;
Stim.ISI = Stm.ISI;

% Add metadata
Stim.MouseNum = Stm.MouseNum(1);
Stim.Set = Stm.Set(1);
Stim.Pen = Stm.Pen(1);

end

function Stm = makeAMstm(Par)
% MAKEAMSTM Generate amplitude modulation stimulus parameters
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
Snddens = 0;  % Default density
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
[Mf, Dens, Md, Speaker, Intensity] = ndgrid(Sndvel', Snddens', Sndmd', Sndloc', Sndlvl');

% Reshape parameters
Mf = Mf(:);
Dens = Dens(:);
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
    Dens = [Dens; zeros(NLvl, 1)];
end

% Create parameter table
Stm = table(Mf, Dens, Md, Intensity, Speaker);

% Randomize trials
Stm = randtrls(Stm, Nrep);

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
Stm.ISI = getisi(ISI, NStm);

end

function isi = getisi(ISI, N)
% GETISI Generate random inter-stimulus intervals
% Input:
%   ISI - Mean ISI in ms
%   N - Number of trials
% Output:
%   isi - Vector of random ISIs

% Generate random ISIs between 0.5 and 1.5 times the mean
isi = ISI * (0.5 + rand(N, 1));

end

function Stm = randtrls(Stm, Nrep)
% RANDTRLS Randomize trial order within each block
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

function [Snd, Fs] = genamnoise(Dur, Int, Mf, Md, fLow, fHigh, useLogDen,...
                        maskBand, transTime, transDur, RiseTime, FallTime,...
                        Fs, Spk, Gain, Ref)
% GENAMNOISE Generate amplitude modulated noise
% Input:
%   Dur - Duration in seconds
%   Int - Intensity in dB SPL
%   Mf - Modulation frequency in Hz
%   Md - Modulation depth [0,1]
%   fLow - Lower frequency bound in Hz
%   fHigh - Upper frequency bound in Hz
%   useLogDen - Use logarithmic density (1) or linear (0)
%   maskBand - Masking bandwidth in Hz
%   transTime - Transition time in seconds (-1 for no transition)
%   transDur - Transition duration in seconds
%   RiseTime - Rise time in seconds
%   FallTime - Fall time in seconds
%   Fs - Sampling frequency in Hz
%   Spk - Speaker number
%   Gain - Gain values
%   Ref - Reference values
% Output:
%   Snd - Generated sound signal
%   Fs - Sampling frequency

% -- specify default values --
if isempty(maskBand) || fLow == fHigh
    maskBand = 0;
end
if isempty(useLogDen)
    useLogDen = 1;
end
if (fLow > fHigh)
    tF = fLow;
    fLow = fHigh;
    fHigh = tF;
end
RiseFall = [RiseTime, FallTime];
if (isempty(RiseFall))
    RiseFall = 5e-3;
end
RiseFall = RiseFall(~isnan(RiseFall));

%-- Main --%
if fLow == fHigh || ((fHigh - fLow) < 2*maskBand)
    f1 = fLow;
    f2 = fHigh;
else
    f1 = fLow + maskBand;
    f2 = fHigh - maskBand;
end

% Derived parameters
nSamp = round(Fs*Dur);           % Number of samples in signal
dF = 1/Dur;                      % frequency resolution

% Use Calibration
Gain = Gain(Gain(:,3)==Spk,:);   % select speaker
DACmax = Ref(1,3);
RefdB = Ref(1,2);

% Generate Signal
% Select frequency band
FF = 0:dF:dF*(nSamp-1);          % Freq Axis

mainIdx = (FF >= f1) & (FF <= f2);
maskIdx = (FF >= fLow) & (FF <= fHigh) & ~mainIdx;

mainN = sum(mainIdx);            % number of freq samples in band
maskN = sum(maskIdx);            % number of freq samples in band
totalN = mainN + maskN;          % number of freq samples in band

% Generate random phased spectrum
maskXX1 = zeros(1,nSamp);        % initialize with zeros
maskXX1(maskIdx) = exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX1 = zeros(1,nSamp);        % initialize with zeros
mainXX1(mainIdx) = exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

maskXX2 = zeros(1,nSamp);        % initialize with zeros
maskXX2(maskIdx) = exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX2 = zeros(1,nSamp);        % initialize with zeros
mainXX2(mainIdx) = exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

% log vs linear power density scaling
if useLogDen
    rawRMS = rms(maskXX1+mainXX1);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX1(maskIdx) = maskXX1(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX1(mainIdx) = mainXX1(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS = rms(maskXX1+mainXX1);
    scale = rawRMS / newRMS;
    maskXX1 = maskXX1 .* scale;
    mainXX1 = mainXX1 .* scale;

    rawRMS = rms(maskXX2+mainXX2);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX2(maskIdx) = maskXX2(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX2(mainIdx) = mainXX2(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS = rms(maskXX2+mainXX2);
    scale = rawRMS / newRMS;
    maskXX2 = maskXX2 .* scale;
    mainXX2 = mainXX2 .* scale;
end

% apply calibration
ToneSPL = Int - 10 * log10(totalN);  % Each component contributes Lvl - 10*log10(# components) to the overall level

maskXX1(maskIdx) = maskXX1(maskIdx).*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX1(mainIdx) = mainXX1(mainIdx).*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

maskXX2(maskIdx) = maskXX2(maskIdx).*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX2(mainIdx) = mainXX2(mainIdx).*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

% generate t-domain signal
mainSnd1 = fft(mainXX1);  % fft
maskSnd1 = fft(maskXX1);  % fft
mainSnd2 = fft(mainXX2);  % fft
maskSnd2 = fft(maskXX2);  % fft
TT = (0:nSamp-1)./Fs;     % time axis vector

% Modulate signal and scramble
% -- scrambled noise (1) --
modSnd1 = mainSnd1 .* (1+Md*cos(2*pi*(Mf*TT)));
sideSnd1 = modSnd1 - mainSnd1;
sideXX = ifft(sideSnd1);
scramXX = sideXX .* exp(2*pi*1i*rand(size(sideXX)));
scramSide1 = fft(scramXX);
scramSnd1 = mainSnd1 + scramSide1;
Snd1 = real(scramSnd1+maskSnd1);

% -- AM noise (2) --
phi = 2*pi-acos(sqrt((1+0.5*Md^2))-1); % phi in radian [0,pi]
% Note: "instantaneous power" of starting phase is matched to scrambled version
modSnd2 = mainSnd2 .* (1+Md*cos(2*pi*(Mf*TT) + phi));
Snd2 = real(modSnd2+maskSnd2);

% apply transition
if transTime < 0
    Snd = Snd2;
elseif transTime > 0 && isinf(transTime)
    Snd = Snd1;
else
    transIdx = TT >= transTime & TT < transTime + transDur; % samples for transition
    nTrans = sum(transIdx);
    nRest = sum(TT >= transTime + transDur);
    Snd = zeros(nSamp,1);
    Snd(TT < transTime) = Snd1(TT < transTime);
    Snd(TT >= transTime + transDur) = Snd2(nTrans+(1:nRest));
    Snd(transIdx) = Snd2(1:nTrans).* sin(0.5*pi*(1:nTrans)./nTrans)... %sine (fade-in)
        + Snd1(transIdx) .* cos(0.5*pi*(1:nTrans)./nTrans); %cosine (fade-out)
end
Snd = Snd(:)'; % make sure Snd is a row vector (required for TDT)

% Apply envelope
if(size(Snd,2) > 2)
    if ~all(RiseFall == 0)
        Nenv = round(RiseFall .* Fs);
        Snd = envelope(Snd', Nenv)';
    end
end

end

function amp = getamp(Gain, freq, level, refdB, DACmax)
% GETAMP Calculate amplitude based on calibration
% Input:
%   Gain - Gain values
%   freq - Frequency in Hz
%   level - Level in dB SPL
%   refdB - Reference level in dB
%   DACmax - Maximum DAC value
% Output:
%   amp - Calculated amplitude

% Simple linear interpolation for gain
if length(Gain) == 1
    amp = Gain;
else
    amp = interp1(Gain(:,1), Gain(:,2), freq, 'linear', 'extrap');
end

% Convert dB to amplitude
amp = amp * 10^((level - refdB)/20) / DACmax;

end 