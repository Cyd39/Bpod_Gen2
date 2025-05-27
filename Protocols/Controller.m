% Add custom function path
if ~ismember('custom_func', path)
    addpath('custom_func');
end

global BpodSystem

% Get current timestamp for settings file name
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
settingsName = "Settings_" + timestamp;

% Get protocol parameters from GUI
[protocolName, subjectName] = ProtocolNameGui();

% Initialize parameter GUI and get parameters
StimParams = StimParamGui();

% Create protocol settings structure
ProtocolSettings = struct();
% Add GUI parameters
ProtocolSettings.StimParams = StimParams;
% Add timestamp
ProtocolSettings.Timestamp = timestamp;
% Add stimulus sets
% ProtocolSettings.StimSets = StimSets;

% Create settings file path and save settings
settingsPath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings');
if ~exist(settingsPath, 'dir')
    mkdir(settingsPath);
end

% Create empty settings file first
settingsFile = fullfile(settingsPath, settingsName + '.mat');

% Save settings to the file
save(settingsFile, 'ProtocolSettings');

% Display settings information
disp('Settings file created:');
disp(['File name: ' settingsName]);
disp('Parameters:');
disp(ProtocolSettings);

% Run protocol
try
    % Start the protocol
    disp('Starting protocol...');
    RunProtocol('Start', protocolName, subjectName, char(settingsName)); % char(settingsName) is needed for RunProtocol
    
catch err
    % Error handling
    disp('Error occurred during protocol execution:');
    disp(err.message);
end

hold on;

