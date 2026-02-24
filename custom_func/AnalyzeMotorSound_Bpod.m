%% 1. load behavioural stimuli
clearvars
% Select file and get absolute path
[filename, filepath] = uigetfile('*.*', 'Select a file to load');

if isequal(filename, 0)
    disp('User canceled file selection');
else
    % Get absolute path
    absolute_path = fullfile(filepath, filename);

    % Get filename without extension
    [~, name_only, ~] = fileparts(filename);
    
    % Display absolute path
    disp(['File path: ' absolute_path]);
    
    % Load file based on file type
    [~, ~, extension] = fileparts(filename);
    
    switch lower(extension)
        case {'.mat'}
            % Load MAT file
            load(absolute_path);
            disp('MAT file loaded successfully');
        otherwise
            % For other file types
            disp(['Unsupported file type: ' extension]);
            data = absolute_path;
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp('=== File Information ===');
    disp(['File name: ' filename]);
    disp(['File size: ' num2str(file_info.bytes) ' bytes']);
end

disp('Record File loaded');

%% Analysis
StmTemp = T; % stimuli_parameters.Stm; %trials x 1
%Aud = sound_parameters.Aud;
%Fs = sound_parameters.Fs;% mic sampling rate
Fs = 1/512e-8;%195310;
%Aud = Aud';

%filename = erase(stim_file.name,'.mat');

% 1. Format Aud (cell array --> matrix)
AudTemp = NaN(size(Aud,2), size(Aud{1},2));

% check if Aud contains all trials
if size(AudTemp,1) ~= size(StmTemp,1)
    error('aud file missing trials')
end

for i = 1:size(Aud,2)
    AudTemp(i,:) = Aud{i};
end

Aud = AudTemp;

% 4. Calculate spectograms
nSamp = size(Aud,2);
sound = Aud(1,:);
%`
window_dur = 0.02 ;% s
window = round(window_dur*Fs);
noverlap = round(0.9*window);
% spectrogram(sound,window,noverlap,[],Fs,'yaxis');

%
numTrials = size(Aud,1);
tic;
[s,f,t,ps_all] = spectrogram(Aud(1,:),window,noverlap,[],Fs,'yaxis'); % [freqs x time bins] ps_all: power spectrum in t bins
fprintf('%4d/%-4d\r',1,numTrials);
for ii = 2:numTrials
    [~,~,~,ps] = spectrogram(Aud(ii,:),window,noverlap,[],Fs,'yaxis');
    ps_all = cat(3,ps_all,ps); %[freqs x time bins x trials]
    fprintf('\b\b\b\b\b\b\b\b\b\b');
    fprintf('%4d/%-4d\r',ii,numTrials);
end
toc;

[nF,nT,~] = size(ps_all);

% adapt to select no sound only trials (for SxA sessions)
UStim = unique(StmTemp(:, {'VibFreq','VibAmp'}), 'rows');
%UStim = unique(StmTemp(:,{'SomFreq','Amplitude'}),'rows');
nUStim = size(UStim,1);

ps_mean = nan(nF,nT,nUStim);
for ii = 1:nUStim
    idx = StmTemp.VibFreq == UStim.VibFreq(ii) & StmTemp.VibAmp == UStim.VibAmp(ii);
    ps_mean(:,:,ii) = mean(ps_all(:,:,idx),3);
end

% save
savename = [name_only '_Spectogramdata'];
OutPath = filepath;
save(fullfile(OutPath, savename), "t", "f", "nT", "ps_mean", "ps_all", "UStim", '-v7.3','-nocompression')

disp("spectogram analysis done")

%% 5. plotting and saving figure

% % load data
clearvars
% spectogram_file = dir(fullfile(OutPath, sessionFile));
%spectogramdata = load([spectogram_file.folder '\' spectogram_file.name], 'f', 't', 'ps_mean', 'ps_all', 'UStim');
% Select file and get absolute path
[filename, filepath] = uigetfile('*.*', 'Select a file to load');
mic = '7012';
if isequal(filename, 0)
    disp('User canceled file selection');
else
    % Get absolute path
    absolute_path = fullfile(filepath, filename);

    % Get filename without extension
    [~, name_only, ~] = fileparts(filename);
    
    % Display absolute path
    disp(['File path: ' absolute_path]);
    
    % Load file based on file type
    [~, ~, extension] = fileparts(filename);
    
    switch lower(extension)
        case {'.mat'}
            % Load MAT file
            load(absolute_path);
            disp('MAT file loaded successfully');
            
        otherwise
            % For other file types
            disp('Supported file type: .mat ');
            data = absolute_path;
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp('=== File Information ===');
    disp(['File name: ' filename]);
    disp(['File size: ' num2str(file_info.bytes) ' bytes']);
end

%savename = erase(filename,".mat");

% f = spectogramdata.f;
% t = spectogramdata.t;
% nT = length(t);
% ps_mean = spectogramdata.ps_mean;
% ps_all = spectogramdata.ps_all;
%UStim = spectogramdata.UStim;
nUStim = size(UStim,1);


% 5. Calculate instantaneous power
fIdx = f > 10;
fLow = f > 500 & f <= 2000;
fMid = f > 2000 & f <= 10000;
fHigh = f > 10000;

instPower_raw = reshape(sum(ps_mean(fIdx,:,:)),[nT,nUStim]);
instPower_raw_dB = 10*log10(instPower_raw);
instPower_raw_dBSPL = dbv2spl(instPower_raw_dB,mic);

instPower_low = reshape(sum(ps_mean(fLow,:,:)),[nT,nUStim]);
instPower_low_dB = 10*log10(instPower_low);
instPower_low_dBSPL = dbv2spl(instPower_low_dB,mic);

instPower_mid = reshape(sum(ps_mean(fMid,:,:)),[nT,nUStim]);
instPower_mid_dB = 10*log10(instPower_mid);
instPower_mid_dBSPL = dbv2spl(instPower_mid_dB,mic);

instPower_high = reshape(sum(ps_mean(fHigh,:,:)),[nT,nUStim]);
instPower_high_dB = 10*log10(instPower_high);
instPower_high_dBSPL = dbv2spl(instPower_high_dB,mic);

% 6. plot average
figure('Position',[10,10,1900,1000]);
clim = [-110,-60];
freqRange = [0,10];%kHz
%dBRange_pow = [-Inf,Inf];
dBRange_pow = [-2,60];
tRange = [0,0.6];

nRows = floor(sqrt(nUStim));
nCols = ceil(nUStim / nRows);

for ii = 1:nUStim
    ax1 = subplot(nRows,nCols,ii);
    title([num2str(UStim.VibFreq(ii),'%d Hz'),'   a:',num2str(UStim.VibAmp(ii),'%.3f')])
    xlabel(ax1,'Time (s)')

    yyaxis(ax1,'left')
    imagesc(t,f./1000,squeeze(10*log10(ps_mean(:,:,ii))),clim)
    ax1.YDir = 'normal';
    ylim(freqRange);
    if mod(ii, nCols) == 1
        ylabel(ax1,'Frequency (kHz)')
    end

    yyaxis(ax1,'right')
    plot(ax1,t,instPower_raw_dBSPL(:,ii),'w-'); hold(ax1,'on');
    plot(ax1,t,instPower_low_dBSPL(:,ii),'-','Color',[1,.5,.5])
    plot(ax1,t,instPower_mid_dBSPL(:,ii),'-','Color',[1,0.1,0.1])
    plot(ax1,t,instPower_high_dBSPL(:,ii),'-','Color',[.5,0,0]); hold(ax1,'off');
    % legend(ax1,{'all (>10Hz)','low (500-2000Hz)','mid (2-10kHz)','high (>10kHz)'},'Location','best');
    if mod(ii, nCols) == 0
        ylabel(ax1,'Instantaneous power (dB SPL)')
    end

    ylim(dBRange_pow)
end

% make space for legend in subplot
if nCols * nRows == ii
    legend(ax1,{'all (>10Hz)','low (500-2000Hz)','mid (2-10kHz)','high (>10kHz)'})
else
    ax = subplot(nRows,nCols,ii+1,'Visible','off');
    axPos = ax.Position;
    hL = legend(ax1,{'all (>10Hz)','low (500-2000Hz)','mid (2-10kHz)','high (>10kHz)'});
    hL.Position(1:2) = axPos(1:2); % move legend to position of extra axes
end

% if strcmp(Par.SomatosensoryWaveform, 'UniSine') % && strcmp(Par.Rec, 'SxA')
%     figtitle = append('Actuator: ', Stm.Actuator(1,:), ', Waveform: ', Stm.Waveform(1,:));
%     %sgtitle(['Actuator: ' StmTemp.Actuator(1,:) ', Waveform: ' StmTemp.Waveform(1,:)])
% elseif strcmp(Par.SomatosensoryWaveform, 'Square') && strcmp(Par.Rec, 'SxA')
%     figtitle = append('Ramp: ', num2str(Stm.SomRamp(1)), ', ms, Actuator: ', Stm.Actuator(1,:), ', Waveform: ', Stm.Waveform(1,:));
% elseif strcmp(Par.SomatosensoryWaveform, 'Square') && strcmp(Par.Rec, 'SOM')
%     figtitle = append('Ramp: ', num2str(Stm.Ramp(1)), ', ms, Actuator: ', Stm.Actuator(1,:), ', Waveform: ', Stm.Waveform(1,:));
% elseif strcmp(Par.SomatosensoryWaveform, 'BiSine')
%     figtitle = append('Ramp: ', num2str(Stm.Ramp(1)), ', ms, Actuator: ', Stm.Actuator(1,:), ', Waveform: ', Stm.Waveform(1,:));
% end

%sgtitle(figtitle)

% save and close average spectogram figure
saveas(gcf,fullfile(filepath, [name_only,'_spectogram']), 'png')
% close(gcf)

% % plot individual subset
% figure('Position',[10,10,1400,900]);
% stimToPlot = [1,4:4:size(Stm,1)];
% nToPlot = length(stimToPlot)+1;
% clim = [-110,-60]; % color limit
% freqRange = [0,10];%kHz
% dBRange_pow = [-Inf,Inf];
% tRange = [0,0.6];
%
% nRows = floor(sqrt(nToPlot));
% nCols = ceil(nToPlot / nRows);
%
% for ii = 1:nToPlot
%     ax1 = subplot(nRows,nCols,ii);
%     yyaxis(ax1,'left')
%     if ii < nToPlot
%         idx = stimToPlot(ii);
%         imagesc(t,f./1000,squeeze(10*log10(ps_all(:,:,idx))),clim)
%         title([num2str(Stm.Rep(idx),'Rep: %d ')])
%     else
%         imagesc(t,f./1000,squeeze(10*log10(ps_mean(:,:,1))),clim)
%         title(['mean'])
%     end
%     ax1.YDir = 'normal';
%     ylim(freqRange);
%     ylabel(ax1,'Frequency (kHz)')
%     xlabel(ax1,'Time (s)')
% end
%
% sgtitle(figtitle)
%
% saveas(gcf,fullfile(OutPath, [savename,'_spectogram_trials']), 'png')
% %saveas(gcf,[filename,'_spectogram_trials.png'])

% close all


% %% plot all individual
% stimToPlot = 1:numTrials;
% nToPlot = length(stimToPlot);
% nRep = max(StmTemp.Rep);
% clim = [-110,-60];
% freqRange = [0,10];%kHz
% dBRange_pow = [-Inf,Inf];
% tRange = [0,0.6];
%
% nRows = 5;
% nCols = 4;
%
% for stimSet = 1:size(UStim, 1)
%     idx = stimToPlot(StmTemp.SomFreq == UStim.SomFreq(stimSet) & StmTemp.Amplitude == UStim.Amplitude(stimSet));  %select all trials of 1 stim condition
%     figure('Position',[10,10,1400,900]);
%     for rep = 1:length(idx)
%         ax1 = subplot(nRows,nCols,rep);
%         yyaxis(ax1,'left')
%         imagesc(t,f./1000,squeeze(10*log10(ps_all(:,:,idx(rep)))),clim)
%         title(['Rep: ' num2str(rep)])
%         ax1.YDir = 'normal';
%         ylim(freqRange);
%         ylabel(ax1,'Frequency (kHz)')
%         xlabel(ax1,'Time (s)')
%     end
%
%     sgtitle(['freq: ' num2str(UStim.SomFreq(stimSet)) ', amp: ' num2str(UStim.Amplitude(stimSet))])
% end


disp('Spectogram figures done')

% %% flag outliers - UNDER CONSTRUCTION
% % Calculate instantaneous power
% %fIdx = f > 10;
% %instPower_raw = reshape(sum(ps_mean(fIdx,:,:)),[nT,nUStim]); % sum freq
%
% % outlier based on average freq trace
% minstPower_raw = sum(instPower_raw,1); % time bins x nUStim
% baselinePower_raw = minstPower_raw(1)*3;
% figure;
% scatter(1:nUStim,minstPower_raw)
% outlierIdx = minstPower_raw >= baselinePower_raw;
% UStim(outlierIdx',:)
%
% % single trial outliers
% % select trial
% stimToPlot = 1:numTrials;
% idx = stimToPlot(StmTemp.SomFreq == UStim.SomFreq(17) & StmTemp.Amplitude == UStim.Amplitude(17));
%
% % time spectogram --> spectogram
% instPower_2d = squeeze(mean(ps_mean(:,:,:),2)); %avg over time
% clim = [-115,-40];
% figure;
% ax2 = gca;
% imagesc(1,f./1000,squeeze(10*log10(instPower_2d(:,17))),clim)
% ax2.YDir = 'normal';
% ylabel(ax2,'Frequency (kHz)')
% xlabel(ax2,'Time (s)')
% xticklabels(ax2, [])
% colorbar
%
% figure;
% ax2 = gca;
% imagesc(t,f./1000,squeeze(10*log10(ps_all(:,:,idx(1)))),clim)
% ax2.YDir = 'normal';
% ylim(freqRange);
% ylabel(ax2,'Frequency (kHz)')
% xlabel(ax2,'Time (s)')
% yyaxis(ax2,'left')

%% local functions
function dbspl = dbv2spl(dbv,mic)
% mic = '7012';
switch mic
    case '7012'
        micSens = 16.4e-3;  % V / 1 Pa; 16.4mV/Pa ~ -35.7 dBV @ 1Pa i.e. 
    case '7016'
        micSens = 3.89e-3;  % V / 1 Pa; 3.89mV/Pa ~ -48.2 dBV @ 1Pa
    otherwise % 7016
        micSens = 3.89e-3;  % V / 1 Pa; 3.89mV/Pa ~ -48.2 dBV @ 1Pa
end
micDBV  = 20*log10(micSens);
refdB   = 94;       % dB SPL = 1Pa
postAmp = 40;       % dB

dbspl = dbv - micDBV + refdB - postAmp;
end