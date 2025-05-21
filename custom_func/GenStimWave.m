function OutputWave = GenStimWave(StimRow)
% GenStimWave - Generate stimulus waveforms based on parameters
% Input:
%   StimParams - Single row from StimSeq table containing trial parameters
%   Fs - Sampling frequency
% Output:
%   OutputWave - Combined waveform (stereo: [sound, vibration])
Fs = 192000;

% Initialize empty waveforms
t = (0:1/Fs:StimRow.Duration/1000)';
SoundWave = zeros(size(t));
VibWave = zeros(size(t));

% Generate sound waveform based on type if not NaN
if ismember(StimRow.MMType,{'OA','SA'})
    % Convert cell to char if necessary
    sndType = StimRow.SndTypeName;
    if iscell(sndType)
        sndType = sndType{1};
    end
    
    switch sndType
        case "Noise Burst"
            % Set parameters
            Int = StimRow.AudIntensity;
            Mf = 0;
            Md = 0;
            fLow = StimRow.AudFreqMin;
            fHigh = StimRow.AudFreqMax;
            useLogDen = StimRow.LogDensity;
            maskBand = 0;
            transTime = -inf;
            transDur = 0;
            RiseTime = StimRow.RampDur * 0.001; % ms -> s
            FallTime = StimRow.RampDur * 0.001; % ms -> s
            Dur = StimRow.Duration/1000;
            
            % Temporary Gain matrix for testing
            % Format: [Frequency, Gain, Speaker]
            freqRange = linspace(fLow, fHigh, 100)';
            Gain = [freqRange, zeros(100,1), ones(100,1)];  % Flat gain
            Spk = 1;  % Speaker number
            Ref = [0, 0, 1];  % [Frequency, dB, DACmax]
            
            % Generate sound waveform
            SoundWave = genamnoise(Dur,Int,Mf,Md,fLow,fHigh,useLogDen,...
                maskBand,transTime, transDur,RiseTime,FallTime,...
                Fs,Spk,Gain,Ref);
            SoundWave = SoundWave(:);
        case "AM Noise"
            %pass
            
        case "Click Train"
            %pass
    end
end

% Generate vibration waveform if not NaN
if ismember(StimRow.MMType,{'SO','SA'})
    % Convert cell to char if necessary
    vibType = StimRow.VibTypeName;
    if iscell(vibType)
        vibType = vibType{1};
    end
    
    switch vibType
        case "Square"
            VibWave = StimRow.VibAmp * ones(size(t));
        case "UniSine"
            VibWave = StimRow.VibAmp * (1 - cos(2*pi*StimRow.VibFreq*t))/2;
        case "BiSine"
            VibWave = StimRow.VibAmp * sin(2*pi*StimRow.VibFreq*t);
    end

    % Apply ramp to vibration
    if StimRow.RampDur > 0
        Nenv = round(StimRow.RampDur*10^-3*Fs);
        VibWave = applyEnvelope(VibWave,Nenv);
    end
end

% Check if the length of the sound and vibration waveforms are the same
if length(SoundWave) ~= length(VibWave)
    % If not, pad the shorter waveform with zeros
    if length(SoundWave) < length(VibWave)
        SoundWave = [SoundWave; zeros(length(VibWave) - length(SoundWave), 1)];
    else
        VibWave = [VibWave; zeros(length(SoundWave) - length(VibWave), 1)];
    end
end

% Combine sound and vibration into stereo output
OutputWave = [SoundWave, VibWave];

end

function Snd = genamnoise(Dur,Int,Mf,Md,fLow,fHigh,useLogDen,...
        maskBand,transTime, transDur,RiseTime,FallTime,...
        Fs,Spk,Gain,Ref)
% [SND,FS] = GENAMNOISE
% All inputs in SI units

% -- specify default values --
if isempty(maskBand)|| fLow == fHigh ; maskBand = 0;end % 
if isempty(useLogDen) ; useLogDen = 1;end % 
if (fLow > fHigh); tF= fLow; fLow = fHigh; fHigh = tF; end
RiseFall = [RiseTime,FallTime];
if (isempty(RiseFall)); RiseFall = 5e-3;end
RiseFall = RiseFall(~isnan(RiseFall)); 

%-- Main --%

if fLow == fHigh || ((fHigh - fLow) < 2*maskBand)
    f1 = fLow;
    f2 = fHigh;
else
    f1 = fLow   +   maskBand; 
    f2 = fHigh  -   maskBand;
end

%% Derived parameters
nSamp       =   round(Fs*Dur);           % Number of samples in signal
dF          =   1/Dur;              % frequency resolution

%% Use Calibration
%Gain		=	Gain(Gain(:,3)==Spk,:); % -- select speaker --
%DACmax      =   Ref(1,3);
%RefdB       =   Ref(1,2);

% Generate Signal
%% Select frequncy band
FF          =   0:dF:dF*(nSamp-1);  % Freq Axis

mainIdx     =   (FF >= f1) & (FF <= f2);
maskIdx     =   (FF >= fLow) & (FF <= fHigh) & ~mainIdx;

mainN       =   sum([mainIdx]);           % number of freq samples in band
maskN       =   sum([maskIdx]);       % number of freq samples in band
totalN      =   mainN + maskN;           % number of freq samples in band

%% Generate random phased spectrum
maskXX1          =   zeros(1,nSamp);   % initialize with zeros
maskXX1(maskIdx) =   exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX1          =   zeros(1,nSamp);   % initialize with zeros
mainXX1(mainIdx) =   exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

maskXX2          =   zeros(1,nSamp);   % initialize with zeros
maskXX2(maskIdx) =   exp(2*pi*rand(1,maskN)*1i); % euler form - flat spectrum
mainXX2          =   zeros(1,nSamp);   % initialize with zeros
mainXX2(mainIdx) =   exp(2*pi*rand(1,mainN)*1i); % euler form - flat spectrum

%% log vs linear power density scaling
if useLogDen
    rawRMS = rms(maskXX1+mainXX1);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX1(maskIdx)  =   maskXX1(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX1(mainIdx)  =   mainXX1(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS      = rms(maskXX1+mainXX1);
    scale       = rawRMS / newRMS;
    maskXX1      =   maskXX1 .* scale;
    mainXX1      =   mainXX1 .* scale;

    rawRMS = rms(maskXX2+mainXX2);
    % apply pink noise scaling (1/f power density; or 1/sqrt(f) magnitude)
    maskXX2(maskIdx)  =   maskXX2(maskIdx) ./ sqrt(FF(maskIdx));
    mainXX2(mainIdx)  =   mainXX2(mainIdx) ./ sqrt(FF(mainIdx));
    % rescale total power (RMS)
    newRMS      = rms(maskXX2+mainXX2);
    scale       = rawRMS / newRMS;
    maskXX2      =   maskXX2 .* scale;
    mainXX2      =   mainXX2 .* scale;
end
%% apply calibration
ToneSPL		=	Int - 10 * log10(totalN);	%-- Each component contributes Lvl - 10*log10(# components) to the overall level --%
% --- temporary gain for testing ---
amplitude =  0.1 * 10^((ToneSPL-70)./20);
%-----------------------------
maskXX1(maskIdx)      =   maskXX1(maskIdx).*amplitude;%.*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX1(mainIdx)      =   mainXX1(mainIdx).*amplitude;%.*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

maskXX2(maskIdx)      =   maskXX2(maskIdx).*amplitude;%.*getamp(Gain,FF(maskIdx),ToneSPL,RefdB,DACmax);
mainXX2(mainIdx)      =   mainXX2(mainIdx).*amplitude;%.*getamp(Gain,FF(mainIdx),ToneSPL,RefdB,DACmax);

%% generate t-domain signal

mainSnd1         =   fft(mainXX1);  % fft;
maskSnd1         =   fft(maskXX1);  % fft;
mainSnd2         =   fft(mainXX2);  % fft;
maskSnd2         =   fft(maskXX2);  % fft;
TT              =   (0:nSamp-1)./Fs;    %s; time axis vector

%% Modulate signal and scramble

% -- scrambled noise (1) --
modSnd1         =   mainSnd1 .* (1+Md*cos(2*pi*(Mf*TT)));
sideSnd1 = modSnd1 - mainSnd1;
sideXX = ifft(sideSnd1);
scramXX = sideXX .* exp(2*pi*1i*rand(size(sideXX)));
scramSide1 = fft(scramXX);
scramSnd1 = mainSnd1 + scramSide1;
Snd1 = real(scramSnd1+maskSnd1);

% -- AM noise (2) --
phi = 2*pi-acos(sqrt((1+0.5*Md^2))-1); % phi in radian [0,pi] 
% Note: "instantaneous power" of starting phase is matched to scrambled version 
modSnd2         =   mainSnd2 .* (1+Md*cos(2*pi*(Mf*TT) + phi));
Snd2 = real(modSnd2+maskSnd2);

%% apply transition
if transTime < 0
    Snd = Snd2;
elseif transTime > 0 && isinf(transTime)
    Snd = Snd1;
else
    transIdx  = TT >= transTime & TT < transTime + transDur; % samples for transition
    nTrans  = sum(transIdx); 
    nRest   = sum(TT >= transTime + transDur);
    Snd = zeros(nSamp,1);
    Snd(TT < transTime) = Snd1(TT < transTime);
    Snd(TT >= transTime + transDur) = Snd2(nTrans+(1: nRest));
    Snd(transIdx) =   Snd2(1:nTrans).* sin(0.5*pi*(1:nTrans)./nTrans)... %sine (fade-in)
    +  Snd1(transIdx) .* cos(0.5*pi*(1:nTrans)./nTrans); %cosine (fade-out)]
end
Snd = Snd(:)'; % make sure Snd is a row vector (required for TDT)


%% -- Apply envelope --%
if( size(Snd,2) > 2 )
    if ~all(RiseFall == 0)
        Nenv			=	round( RiseFall .*Fs );
        Snd				=	applyEnvelope(Snd',Nenv)';
    end
end

end

function Sig = applyEnvelope(Sig, NEnv)
% Create a smooth on- and offset envelope for an auditory signal
%
% function SIG = ENVELOPE (SIG, NENV)
%
% .. Dr. P ...

if (length(NEnv) == 1); NEnv = [NEnv,NEnv];end

SigLen = size(Sig,1);

if (SigLen < 2*NEnv)

    disp ('-- ERROR: Envelope length greater than signal');

else

    Env1 = ( sin(0.5*pi*(0:NEnv(1))/NEnv(1)) ).^2;
    Env2 = flip( sin(0.5*pi*(0:NEnv(2))/NEnv(2)) ).^2;
    head = 1:(NEnv(1)+1);
    tail = (SigLen-NEnv(2)):SigLen;

    for i=1:size(Sig,2)
    Sig(head,i) = Env1' .* Sig(head,i);
    Sig(tail,i) = Env2' .* Sig(tail,i);
    end
end

function Amp = getamp(GainTable,Freq,Lvl,RefdB,DACmax)
%-- Select interpolate gain from the calibration table --%
uSpk = unique(GainTable(:,3));
nSpk = length(uSpk);

Gain2D = nan(nSpk,length(Freq));
for s = 1:nSpk
    Spk = uSpk(s);
    GT = GainTable(GainTable(:,3) == Spk,:);
    Gain2D(s,:) = interp1(GT(:,1),GT(:,2),Freq(:));
end

Gain = mean(Gain2D,1); % if both speakers 

Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;

if ( Amp >= DACmax )
    if( idx+1 > size(GainTable,1) )
        Gain	=	min([ mean( GainTable(idx-1:idx,2) ) 9]);
    else
        Gain	=	min([ mean( GainTable(idx-1:idx+1,2) ) 9]);
    end
    Amp		=	(10.^((Lvl-RefdB)/20)) ./ Gain;
    warning(['Used adjacent gains to calibrate f= ' num2str(round(Freq)) ' Hz & clipped to 9 V if necessary.'])
end

end
end