function TestSoundCalibration(CalTable,freq_list, dB_list)

if nargin <2
    freq_list = logspace(log10(1000), ...
                         log10(128000), ...
                         7*12+1);
    freq_list = freq_list(freq_list<=80000);
end

if nargin < 3
    dB_list = [80:-5:40];
end

HifiCOM = 'COM3';
H = BpodHiFi(HifiCOM);
%% set sampling rate
Fs = 192000;
H.SamplingRate = Fs;

%%
DSP = 'RZ6';
RPatten = '';
RPpath      =   'tdt_circuits\Calibrate_RZ6.rcx';
[RP,~] = setuptdt(RPpath,DSP, RPatten);

MicrophoneGain = -49.1; % dBV for 94 dBSPL
RefDB = 94; % dBSPL reference
PostAmp = 40; % dB
CalFactor = RefDB - MicrophoneGain - PostAmp;


RP.SetTagVal('CalFactor',CalFactor);

%% Test calibration with custom waveform

duration_sec = 0.5;
tt = 1/Fs:1/Fs:duration_sec;

% amp_list=[1.0];
% freq_list = [1000,64000,75000];
TestDB = nan(length(dB_list),length(freq_list));
TestDist = nan(length(dB_list),length(freq_list));

for ff = 1:length(freq_list)
    freq = freq_list(ff);
    RP.SetTagVal('CalFreq',freq);
    for aa = 1:length(dB_list)
        dBSPL = dB_list(aa);
        amp = cal_dB2amp(freq,dBSPL,CalTable);
        if amp > 1; continue; end % skip if amp needs to be larger than 1
        waveform = amp*sin(2*pi*freq.*tt);
        waveformIndex = 2;
        H.load(waveformIndex,waveform);
        H.push;
        H.play(waveformIndex);
        pause(0.2);
        
        TestDB(aa,ff) = RP.GetTagVal('CalDB');
        % read in distortion from microphone
        TestDist(aa,ff) = RP.GetTagVal('CalDist');
        
        fprintf("Freq: %.0f\twanted: %.1f\tAmp: %.3f\tInt: %.1f\n",freq,dBSPL,amp,TestDB(aa,ff));
%         fprintf("Freq: %.0f\n",freq)
        pause(0.4) 
        H.stop();
    end
   
end

figure;
plot(freq_list,TestDB','-x')
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

function amp = cal_dB2amp(freq,dBSPL,CalTable)
    
gain = interp1(CalTable.CalFreq,CalTable.CalDB,freq);

amp = db2a(dBSPL - gain);

end

function amp = db2a(dB)
    amp = 10.^(dB./20);
end
