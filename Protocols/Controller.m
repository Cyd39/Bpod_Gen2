% Add custom function path
if ~ismember('custom_func', path)
    addpath('custom_func');
end

% Initialize Bpod system
initBpod();

% Initialize parameter GUI
StimParamGui();

% Run protocol
RunProtocol('Start', 'neuroactive', 'human_test')