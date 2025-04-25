% Add custom function path
if ~ismember('custom_func', path)
    addpath('custom_func');
end

% Initialize Bpod system
initBpod();

% Get current timestamp for settings file name
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
settingsName = "Settings_" + timestamp;

% Initialize parameter GUI and get parameters
StimParams = StimParamGui();

% Generate stimulus and get stimulus info
[SoundSet,VibrationSet] = genStim(StimParams);

% Create protocol settings structure
ProtocolSettings = struct();
% Add GUI parameters
ProtocolSettings.GUI = guiParams;
% Add stimulus information
ProtocolSettings.Stimulus = stimInfo;
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
disp('已创建实验设置文件:');
disp(['文件名: ' settingsName]);
disp('参数内容:');
disp(ProtocolSettings);

% Run protocol
try
    % Start the protocol
    disp('Starting protocol...');
    RunProtocol('Start', protocolName, subjectName, settingsName);
    
catch err
    % Error handling
    disp('运行实验时发生错误:');
    disp(err.message);
end