% Add custom function path
if ~ismember('custom_func', path)
    addpath('custom_func');
end

% Initialize Bpod system
InitBpod();

% Get current timestamp for settings file name
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
settingsName = "Settings_" + timestamp;

% Initialize parameter GUI and get parameters
StimParams = StimParamGui();

% Generate stimulus and get stimulus info
[SoundSet,VibrationSet] = GenStim(StimParams);

% Create protocol settings structure
ProtocolSettings = struct();
% Add GUI parameters
ProtocolSettings.StimParams = StimParams;
% Add timestamp
ProtocolSettings.Timestamp = timestamp;

% Define protocol parameters
protocolName = 'neuroactive';  
subjectName = 'human_test';       

% Create settings file path and save settings
global BpodSystem
settingsPath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings');
if ~exist(settingsPath, 'dir')
    mkdir(settingsPath);
end

% Save settings file
settingsFile = fullfile(settingsPath, [settingsName '.mat']);
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
    RunProtocol('Start', protocolName, subjectName, settingsName);
    
catch err
    % Error handling
    disp('Error occurred during experiment:');
    disp(err.message);
end