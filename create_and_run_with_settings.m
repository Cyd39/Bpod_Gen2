function create_and_run_with_settings()
    % 初始化 Bpod
    global BpodSystem
    if isempty(BpodSystem)
        Bpod();
    end
    
    % 定义协议信息
    protocolName = 'neuroactive_test';
    subjectName = 'mouse1';
    settingsName = 'MyCustomSettings';
    
    % 创建参数结构体
    ProtocolSettings = struct();
    ProtocolSettings.SoundFrequency = 1000;  % Hz
    ProtocolSettings.SoundDuration = 0.5;    % seconds
    ProtocolSettings.SoundVolume = 0.5;      % 0-1
    ProtocolSettings.MinITI = 2;            % seconds
    ProtocolSettings.MaxITI = 3;            % seconds
    ProtocolSettings.MinQuietTime = 1;      % seconds
    ProtocolSettings.MaxQuietTime = 2;      % seconds
    
    % 创建设置文件路径
    settingsPath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings');
    if ~exist(settingsPath, 'dir')
        mkdir(settingsPath);
    end
    
    % 保存设置文件
    settingsFile = fullfile(settingsPath, [settingsName '.mat']);
    save(settingsFile, 'ProtocolSettings');
    
    % 显示将要使用的参数
    disp('将使用以下参数运行实验：');
    disp(ProtocolSettings);
    
    % 运行协议
    try
        RunProtocol('Start', protocolName, subjectName, settingsName);
    catch err
        disp('运行实验时发生错误：');
        disp(err.message);
        try
            RunProtocol('Stop');
        catch
        end
        rethrow(err);
    end
end 