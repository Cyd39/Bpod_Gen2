% Script to run neuroactive test protocol
function run_neuroactive_test(varargin)
    % Initialize Bpod if not already initialized
    global BpodSystem
    if isempty(BpodSystem)
        Bpod();
    end
    
    % Define default parameters
    params = struct();
    params.SoundFrequency = 523;    % Hz
    params.SoundDuration = 1;       % seconds
    params.SoundVolume = 0.3;       % 0-1
    params.MinITI = 2;             % seconds
    params.MaxITI = 3;             % seconds
    params.MinQuietTime = 1;       % seconds
    params.MaxQuietTime = 2;       % seconds
    
    % Override defaults with any provided parameters
    if nargin > 0 && isstruct(varargin{1})
        providedParams = varargin{1};
        fields = fieldnames(providedParams);
        for i = 1:length(fields)
            params.(fields{i}) = providedParams.(fields{i});
        end
    end
    
    % Protocol information
    protocolName = 'neuroactive_test';  % 协议名称
    subjectName = 'mouse1';             % 实验动物名称
    settingsName = 'CurrentSettings';    % 设置文件名称
    
    try
        % 创建设置文件路径
        settingsPath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings');
        if ~exist(settingsPath, 'dir')
            mkdir(settingsPath);
        end
        
        % 保存参数到设置文件
        ProtocolSettings = params;
        save(fullfile(settingsPath, [settingsName '.mat']), 'ProtocolSettings');
        
        % Start the protocol
        disp('正在启动实验...');
        disp('使用以下参数:');
        disp(params);
        
        RunProtocol('Start', protocolName, subjectName, settingsName);
        
    catch err
        % Error handling
        disp('运行实验时发生错误:');
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

% 使用示例:
% 使用默认参数运行:
% run_neuroactive_test()
%
% 使用自定义参数运行:
% params = struct();
% params.SoundFrequency = 1000;
% params.SoundDuration = 0.5;
% run_neuroactive_test(params) 