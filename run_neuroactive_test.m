% Script to run neuroactive test protocol
function run_neuroactive_test()
    % Initialize Bpod if not already initialized
    global BpodSystem
    if isempty(BpodSystem)
        Bpod();
    end
    
    % Define parameters
    protocolName = 'neuroactive_test';  % 协议名称
    subjectName = 'mouse1';             % 实验动物名称
    settingsName = 'DefaultSettings';    % 设置文件名称
    
    try
        % Start the protocol
        disp('Starting protocol...');
        RunProtocol('Start', protocolName, subjectName, settingsName);
        
    catch err
        % Error handling
        disp('Error occurred while running protocol:');
        disp(err.message);
        
        % Try to stop the protocol gracefully
        try
            RunProtocol('Stop');
        catch
            % If stop fails, just continue
        end
        
        % Rethrow the error
        rethrow(err);
    end
end

% Function to pause the protocol
function pauseProtocol()
    RunProtocol('StartPause');
end

% Function to stop the protocol
function stopProtocol()
    RunProtocol('Stop');
end 