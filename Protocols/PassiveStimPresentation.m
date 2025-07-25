% generate stimulus parameters
StimParams = StimParamGui();
StimTable = GenStimSeq(StimParams);
n_trials = height(StimTable);

% do it with HiFiModule directly.
% connect to HiFi module
HifiCOM = 'COM3';
H = BpodHiFi(HifiCOM);
waveformIndex = 1;

% Load calibration table
CalFile = 'Calibration Files\CalTable_20250707.mat';
load(CalFile,'CalTable');
%%
% loop through trials
for currentTrial = 1:n_trials
    % pre-stimulus time
    pause(0.5);

    disp(StimTable(currentTrial,:));
    stimDuration = StimTable.Duration(currentTrial);
    soundWave = GenStimWave(StimTable(currentTrial,:),CalTable);

    if max(abs(soundWave)) > 1; warning("max amplitude > 1."); end
    
    % load 
    H.load(waveformIndex,soundWave);
    H.push;

    % play
    H.play(waveformIndex);

    % wait for stimulus duration
    pause(stimDuration*1e-3); % ms-> s

    % post-stimulus time
    pause(1);
end

% disconnect HiFi Module
H.delete