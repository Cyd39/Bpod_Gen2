function run_with_params()
    % 初始化 Bpod
    global BpodSystem
    if isempty(BpodSystem)
        Bpod();
    end
    
    % 定义协议信息
    protocolName = 'neuroactive_test';
    subjectName = 'mouse1';
    settingsName = 'DefaultSettings';
    
    % 在运行协议前直接设置参数
    BpodSystem.ProtocolSettings = struct();
    BpodSystem.ProtocolSettings.SoundFrequency = 1000;  % Hz
    BpodSystem.ProtocolSettings.SoundDuration = 0.5;    % seconds
    BpodSystem.ProtocolSettings.SoundVolume = 0.5;      % 0-1
    BpodSystem.ProtocolSettings.MinITI = 2;            % seconds
    BpodSystem.ProtocolSettings.MaxITI = 3;            % seconds
    BpodSystem.ProtocolSettings.MinQuietTime = 1;      % seconds
    BpodSystem.ProtocolSettings.MaxQuietTime = 2;      % seconds
    
    % 显示将要使用的参数
    disp('将使用以下参数运行实验：');
    disp(BpodSystem.ProtocolSettings);
    
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