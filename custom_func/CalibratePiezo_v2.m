%% Connect HiFi Module
HifiCOM = 'COM3';
H = BpodHiFi(HifiCOM);

%% set sampling rate
Fs = 192000;
H.SamplingRate = Fs;

%% setup stimulus
H.SynthAmplitude = 0; %  mute
H.SynthWaveform = 'Sine';

%% stimuli parameter table
amp = 0.1:0.05:0.6;
freq = 100:100:1000;
vibtype = 'BiSine';
mmtype = 'SO';
dur = 1000 ; % ms 1 second of stimulus
ramp = 5 ; % ms

[F, A] = meshgrid(freq, amp);

% Create table with all combinations
T = table(A(:), F(:), ...
          repmat({vibtype}, numel(A), 1), ...
          repmat({mmtype}, numel(A), 1), ...
          repmat(dur, numel(A), 1), ...
          repmat(ramp, numel(A), 1), ...
          'VariableNames', {'VibAmp', 'VibFreq', 'VibTypeName', 'MMType', 'Duration', 'RampDur'});
disp(T);

%% setup TDT
DSP = 'RZ6';
RPatten = '';
RPpath      =   'tdt_circuits\RZ6_SomAud.rcx';
[RS,zBus] = setuptdt(RPpath,DSP, RPatten);
zBus.zBusTrigB(0,2,3); % reset zBus
RS.Run;
TotalDurSamp = 2*Fs; % 2 seconds of recording
RS.SetTagVal('TotalDurSamp',TotalDurSamp);
%%
fig = figure;
ax1 = subplot(2,1,1);
ax2 = subplot(2,1,2);
%% loop of generation of sound and push to HiFi Module
numTrials = height(T);
Aud = cell(numTrials,1);
for n = 1:numTrials
    currentStimRow = T(n,:);
    soundWave = GenStimWave(currentStimRow);
    soundWave = soundWave(:,1:end-1); % remove the last sample.
    disp(currentStimRow);
    
    % Load the sound wave into BpodHiFi with loop mode
    % LoopMode = 1 (on), LoopDuration = 0 (loop indefinitely until stopped)
    H.load(1, soundWave); 
    H.push();
    disp(['Trial ' num2str(n) ': Sound loaded to buffer 1']);

    zBus.zBusTrigB(0,0,3);          %-- Triggering
    pause(0.5);
    H.play(1);
    pause(1.5);
    H.stop();
    try
        TotalDurSamp = RS.GetTagVal('TotalDurSamp');
        AudIn = RS.ReadTagV('DataOut', 0, TotalDurSamp);
        tt = (1:length(AudIn)) ./ Fs;
        plot(ax1,tt,AudIn);
        if(n == 1);xlim(ax1,[min(tt),max(tt)]);end
        plot(ax2,abs(fft(AudIn)));
        ax2.YScale="log";
        Aud{n} = AudIn;
    catch ME
        disp(ME)
        disp('error reading ADC.')
    end
end

% Save T and aud as file named by testing time
currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
% Ask for filename
filename = input('Enter filename: ', 's');
filename = [filename '_' char(currentTime) '.mat'];
save(filename, 'T','Aud');
disp(['Saved as: ' filename]);
saveas(fig, [filename '_fig.png']);
disp(['Saved figure as: ' filename '_fig.png']);
%%
RS.Halt;

function [RP,ZBus] = setuptdt(RPpath,RPtype, RPatten)

%-- set up the ZBus --%
%figure(100)
%set(gcf,'position',[1 1 1 1])
ZBus = actxserver('ZBus.x', [1 1 .01 .01]);
if( ~ZBus.ConnectZBUS('GB') )
	error('Failed to init ZBus');
end

%-- set up the RZ6 on the gigabit interface --%
RP = actxserver('RPco.x', [1 1 0.01 0.01]);
if( strcmpi(RPtype,'RX6') )
	Msg	=	RP.ConnectRX6('GB',1);
    devPA5 = actxserver('PA5.x');
    devPA5.ConnectPA5('GB',1)
    PA5_set(devPA5, RPatten);
    devPA5.ConnectPA5('GB',2)
    PA5_set(devPA5, RPatten);
elseif( strcmpi(RPtype,'RZ6') )
	Msg	=	RP.ConnectRZ6('GB',1);
else
	error('Unknown device')
end

if( ~Msg )
	error(['Failed to connect ' RPtype]);
end

RP.ClearCOF;
if( ~RP.LoadCOF(RPpath) )
	error(['Failure to load ' RPpath '!']);
end

RP.Halt;
RP.Run;

%-- Give it some time for data transfer --%
pause(.05);
end
