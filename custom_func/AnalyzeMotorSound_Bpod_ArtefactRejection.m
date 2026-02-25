%% Load stimuli

[filename, filepath] = uigetfile('*.mat', 'Select raw recording file to load');
if isequal(filename, 0)
    error('User canceled file selection');
else
    % Get absolute path
    absolute_path = fullfile(filepath, filename);
    load(absolute_path);
    [~, baseFilename, extension] = fileparts(filename);
    % [filename, filepath] = uigetfile('*.mat', 'Select spectrogram data file to load',filepath);
    spectrogram_path = fullfile(filepath, [baseFilename,'_Spectogramdata.mat']); % spelling mistake!!!
    load(spectrogram_path,"UStim");
end

Fs = 1/512e-8;%195310;
%% Check artefact
numStim = length(Aud);

maxDev = nan(numStim,1);
for iTrial = 1:numStim
    maxDev(iTrial) = max(abs(Aud{iTrial}));
end

medianMaxDev = median(maxDev);
MADMaxDev = median(abs(maxDev-medianMaxDev));
artefactThreshold = medianMaxDev+6*MADMaxDev;
rejectTrial = maxDev > artefactThreshold;

% --
figure
plot(maxDev);hold on;
yline(medianMaxDev,':k');
yline(artefactThreshold,'--r');
scatter(find(rejectTrial),maxDev(rejectTrial),'xr','LineWidth',1);
hold off;


%% Spectral analysis

bw = 25;
nHarmonics = 15;
df = 10;
% 
iTrial = 1;
sound = Aud{iTrial};
stimFreq = T.VibFreq(iTrial);
tt = (1:length(sound))./Fs;
tIdx = tt > 0.15 & tt < 1.05;
soundToAnalyse = sound(tIdx);
numUStim = height(UStim);
for iStim = 1:numUStim
    %%
    stimFreq =UStim.VibFreq(iStim);
    stimAmp =UStim.VibAmp(iStim);

    trialNumbers = find( T.VibFreq == stimFreq ...
                         & T.VibAmp == stimAmp);
    pxx_all = [];
    for iTrial = trialNumbers
        if rejectTrial(iTrial); continue; end
        sound = Aud{iTrial};
        soundToAnalyse = sound(tIdx);
        [pxx,f] = calculateSpectrum(soundToAnalyse, Fs, df);
        if isempty(pxx_all)
            pxx_all = pxx;
        else
            pxx_all = [pxx_all,pxx];
        end
    end
    pxx_mean = mean(pxx_all,2);
    
    [pow_dBSPL,harm_dBSPL] = analyzeSpectrum(pxx_mean,df, stimFreq, bw, nHarmonics);
    UStim.pow_dBSPL(iStim) = pow_dBSPL;
    UStim.harm_dBSPL(iStim) = harm_dBSPL;

    UStim_Sel = UStim(UStim.VibFreq==stimFreq,:);

    if stimAmp == max(UStim_Sel.VibAmp)
        %%
        figure;
        plotSpectrum(pxx_mean,f,stimFreq,stimAmp,bw,nHarmonics,pow_dBSPL,harm_dBSPL);
    end
end

figure;
plotSummary(UStim,1)
title(baseFilename,'Interpreter','none');

function plotSummary(UStim,append)
    if nargin < 2; append = 0; end
    uFreq = nonzeros(unique(UStim.VibFreq));
    nFreq = length(uFreq);
    Colors = 0.9.*jet(nFreq);%lines(nFreq);
    if append; hold on; else  hold off; end
    for iFreq = 1:nFreq
        UStim_Sel = UStim(UStim.VibFreq == uFreq(iFreq),:);
        plot(UStim_Sel.VibAmp,UStim_Sel.pow_dBSPL,'-o','DisplayName',[num2str(uFreq(iFreq),'%.0f Hz')],...
            'Color',Colors(iFreq,:));
        hold on;
        plot(UStim_Sel.VibAmp,UStim_Sel.harm_dBSPL,':x','DisplayName',['harm ',num2str(uFreq(iFreq),'%.0f Hz')],...
            'Color',Colors(iFreq,:));
    end
    set(gca,'XScale','log')
    legend('location','eastoutside')
    ylabel('Sound intensity (dBSPL)')
    xlabel('Amplitude')
end

function [pxx,f] = calculateSpectrum(soundToAnalyse, Fs, df)
    if nargin < 3; df = 10; end %Hz
    window = [];%round(1/df*Fsam);%10000; %samples
    fracOverlap = 0.5; %samples
    if (isempty(window))
        window = round(0.5*Fs/df)*2;%10000; %samples
    end
    overlap = round(fracOverlap*window); %samples
    nfft = window; %number of points

    [pxx,f] = pwelch(soundToAnalyse,window,overlap,nfft,Fs);
end
function [pow_dBSPL,harm_dBSPL] = analyzeSpectrum(pxx,df, stimFreq, bw, nHarmonics)
    if nargin < 4; bw = 30; end %Hz
    if nargin < 5; nHarmonics = 15; end

    mic = '7012';
    switch mic
        case '7012'
            micSens = 16.4e-3;  % V / 1 Pa; 16.4mV/Pa ~ -35.7 dBV @ 1Pa i.e. 
        case '7016'
            micSens = 3.89e-3;  % V / 1 Pa; 3.89mV/Pa ~ -48.2 dBV @ 1Pa
        otherwise % 7016
            micSens = 3.89e-3;  % V / 1 Pa; 3.89mV/Pa ~ -48.2 dBV @ 1Pa
    end


    if stimFreq > 0
        pow_V2 = detectPower(pxx,df,stimFreq,bw);
        pow_dBSPL = V2ToSPL(pow_V2,micSens);
    
        harmFreqList = stimFreq * (2:nHarmonics+1);
        harm_V2 = 0;
        for harmFreq = harmFreqList
            harm_V2 = harm_V2 + detectPower(pxx,df,harmFreq,bw);
        end
        harm_dBSPL = V2ToSPL(harm_V2,micSens);
    else
        pow_dBSPL = nan;
        harm_dBSPL = nan;
    end

end

function plotSpectrum(pxx,f,stimFreq,stimAmp,bw,nHarmonics,pow_dBSPL,harm_dBSPL)
    harmFreqList = stimFreq * (2:nHarmonics+1);
    plot(f,pxx);
    set(gca,'YScale','log')
    set(gca,'XScale','log')
    
    if stimFreq > 0
        title(['Frequency:    ', num2str(stimFreq,"%.f"),' Hz', '   Amp:  ',num2str(stimAmp),newline,...
               'Power at F0:      ', num2str(pow_dBSPL,"%.1f"),' dBSPL', newline,...
               'Power (',num2str(nHarmonics),' harmonics):     ',num2str(harm_dBSPL,"%.1f"),' dBSPL',])
        xline(stimFreq-bw,'--k')
        xline(stimFreq+bw,'--k')
        xline(harmFreqList-bw,':r')
        xline(harmFreqList+bw,':r')
    else
        title("")
    end
end

function pow = detectPower(p,df,freq,bw)
    f = df .* ( 1:length(p) );
    % [C,ind] = min(abs(f - freq));
    idx = abs(f - freq) <= bw;
    pow = sum(p(idx))*df;
end       
function pow_dBSPL = V2ToSPL(pow_V2,micSens)
    pow_dBV = 10*log10(pow_V2);
    micSens_dB = 10*log10(micSens);
    postamp_dB = 40;
    pow_dBSPL = pow_dBV - micSens_dB + 94 - postamp_dB;
end