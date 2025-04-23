% Add custom function path
if ~ismember('custom_func', path)
    addpath('custom_func');
end

% Initialize Bpod system
initBpod();

% Initialize parameter GUI
StimParamGui();

% Generate stimulus
genStim();

% Define protocol parameters
protocolName = 'neuroactive';  
subjectName = 'human_test';            
settingsName = 'DefaultSettings';

% Run protocol
try
    % Start the protocol
    disp('Starting protocol...');
    RunProtocol('Start', protocolName, subjectName, settingsName);
    
catch err
    % Error handling
    disp('Error occurred while running protocol:');
    disp(err.message);
end