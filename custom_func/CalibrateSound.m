function CalTable = CalibrateSound(freq_list)
if nargin <1
    freq_list = logspace(log10(1000), ...
                         log10(128000), ...
                         7*12+1);
    freq_list = freq_list(freq_list<80000);
    freq_list = [freq_list,80e3];
end

HifiCOM = 'COM3';
H = BpodHiFi(HifiCOM);
%% set sampling rate
Fs = 192000;
H.SamplingRate = Fs;

%% setup stimulus
H.SynthAmplitude = 0; %  mute
H.SynthWaveform = 'Sine';

%%
DSP = 'RZ6';
RPatten = '';
RPpath      =   'tdt_circuits\Calibrate_RZ6.rcx';
[RP,~] = setuptdt(RPpath,DSP, RPatten);

%% 
n_freq = length(freq_list);

input_amp = 1;
H.SynthAmplitude = input_amp; % start sound

MicrophoneGain = -49.1; % dBV for 94 dBSPL
RefDB = 94; % dBSPL reference
PostAmp = 40; % dB
CalFactor = RefDB - MicrophoneGain - PostAmp;

RP.SetTagVal('CalFactor',CalFactor);
CalFreq = nan(n_freq,1);
CalAmp = input_amp*ones(n_freq,1);
CalDB = nan(n_freq,1);
CalDist = nan(n_freq,1);
CalBG = nan(n_freq,1);
for ff = 1:length(freq_list)
    freq = freq_list(ff);
    disp(['Calibrating ' num2str(freq), ' Hz.'])
    % set freq HiFi module
    H.SynthFrequency = freq;
    % set freq RZ6    
    RP.SetTagVal('CalFreq',freq);
    RP.SetTagVal('CalBW',freq*0.1);
    % check freq RZ6 is set
    CalFreq(ff) = RP.GetTagVal('CalFreq');
    if ff == 1; pause(1);end
    pause(0.1);

    % read in dBV from microphone
    CalDB_temp = nan(10,1);
    for i = 1:10
        CalDB_temp(i) = RP.GetTagVal('CalDB');
        pause(0.01);
    end
    CalDB(ff) = mean(CalDB_temp);
    % read in distortion from microphone
    CalDist(ff) = RP.GetTagVal('CalDist');

    pause(0.1);
end

H.SynthAmplitude = 0; % stop sound
disp("Measuring background.")
for ff = 1:length(freq_list)
    freq = freq_list(ff);
    % set freq RZ6    
    RP.SetTagVal('CalFreq',freq);
    pause(0.1);
    % read in dBV from microphone
    CalDB_temp = nan(10,1);
    for i = 1:10
        CalDB_temp(i) = RP.GetTagVal('CalDB');
        pause(0.01);
    end
    CalBG(ff) = mean(CalDB_temp);
end

CalTable = table(CalFreq,CalAmp,CalDB,CalDist,CalBG);


%% Plotting
figure;
plot(CalTable.CalFreq, CalTable.CalDB,'-x')
hold on;
plot(2*CalTable.CalFreq, CalTable.CalDist,'-o')
plot(CalTable.CalFreq, CalTable.CalBG,'-s')
legend({'Signal','Harmonics','Background'},'location','best')
ax = gca; ax.XScale = 'log';
ylabel('Sound level (dB SPL)')
xlabel('Tone frequency (Hz)')


end


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
