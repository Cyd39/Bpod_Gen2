% Initialize Bpod
global BpodSystem

% Define protocol parameters
protocolName = 'mini_test';  
subjectName = 'human_test'; 
settingsName = 'mini_setting';

% Run protocol   
disp('Starting protocol...');
RunProtocol('Start', protocolName, subjectName, settingsName);

