BpodCOM = 'COM4';
HifiCOM = 'COM7';

%% Connect to Bpod and Hifi module
% Bpod(BpodCOM);

% Hifi = ArCOMObject(HifiCOM, 115200);
H = BpodHiFi(HifiCOM);
%% check info
H
% if Hifi.bytesAvailable
% Hifi.read(Hifi.bytesAvailable,'uint8')
% end
% Hifi.write('I')
% [isHD, bitDepth,maxWaves,digAtt,samprate,maxSperW,maxEnv] = Hifi.read(1,'uint8',1,'uint8',1,'uint8',1,'uint8',1,'int32',1,'int32',1,'int32')
%% set sampling rate
Fs = 192000;
H.SamplingRate = Fs
% % Fs = 44100;
% Hifi.write('S','uint8',Fs,'uint32'); % set to sampling rate to 192000
% ready = Hifi.read(1,'uint8');
% if ready; disp('ready');end
%% test synth control
% 
H.SynthWaveform = 'Sine';
H.SynthFrequency = 12000;
H.SynthAmplitude = 1; % start sound
pause(1) % wait for 1 s
H.SynthAmplitude = 0; % stop sound
H
%% play some synth music
A = 440; %Hz
C = 523;
D = 523*2^(1/6);
E = 523*2^(2/6);
F = 523*2^(5/12);
G = 523*2^(7/12);

tones = [C,D,E,C,C,D,E,C,E,F,G,G,E,F,G,G];

for i = 1:length(tones)
    H.SynthFrequency = tones(i);
    if i == 1; H.SynthAmplitude = 1; end
    pause(0.25);
end
H.SynthAmplitude = 0; % stop sound
%% test loading and playing waveform

    % create waveform
    duration_sec = 0.5;
    tt = 1/Fs:1/Fs:duration_sec;
    freq = 8e3; %Hz
    modFreq = 10; %Hz
    waveform = 0.5 * sin(2*pi*freq.*tt) .* (1-cos(2*pi*modFreq.*tt));
    amp = 1;% 2^15 - 1;
    waveform = amp .* waveform;
    waveform1 = sin(2*pi*freq.*tt);
    waveform2 = sin(2*pi*(0.5*freq).*tt);
    waveform3 = sin(2*pi*(0.5*10).*tt).^2;

    figure(1);
    plot(tt,waveform1,'r');hold on; 
    xlim([0,1e-3]);
    plot(tt,waveform2, 'b');
    % plot(tt,waveform3, 'g');
    hold off;
    legend({'waveform1','waveform2'})
    %% loading, push & play the waveform
    waveformIndex = 2;
    H.load(waveformIndex,0.5*waveform1);
    H.load(3,0.5*waveform2(1:40000));
    H.push;
    H.play(waveformIndex);
    pause(0.1)
    H.play(3);

    %%
    soundIndex = 1;
    H.load(soundIndex,waveform1*0.2,'LoopMode',1,'LoopDuration',5)   % 5 seconds
    H.push;
    H.play(soundIndex);
    H.load(soundIndex,waveform2*0.2) %'LoopMode',1,'LoopDuration',5
    pause(2)
    H.stop();
    H.push
    pause(6)
    H.play(soundIndex);
    H
%% test stereo
waveformIndex = 2;
H.load(waveformIndex,0.5*[waveform3;waveform1]);
H.push;
H.play(waveformIndex);

% nSamp = length(waveform);
% waveformIndex = 1; % 0 - 19
% isStereo = 0; % 0 or 1
% loopMode = 0; % 0 or 1
% duration = nSamp; % samp (32-bit integer)
% numSamp = nSamp; % samp
% Hifi.write('L','uint8',...
%            waveformIndex,'uint8',...
%            isStereo,'uint8',...
%            loopMode,'uint8',...
%            duration,'int32',...
%            numSamp,'int32',...
%            waveform,'int16'...
%              );
% 
% while Hifi.bytesAvailable == 0
%     pause(0.05)
% end
% ready = Hifi.read(1,'uint8');
% if ready; disp('ready');end

%% playing the waveform
Hifi.write('P','uint8',...
           waveformIndex,'uint8');
%% stopping
Hifi.write('X','uint8');