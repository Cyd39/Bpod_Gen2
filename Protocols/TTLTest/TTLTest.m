function TTLTest
global BpodSystem

%% 设置部分
% 定义参数和试验结构
S = BpodSystem.ProtocolSettings;

% 设置默认参数
if isempty(fieldnames(S))
    % 在这里定义默认设置
    S.GUI.TrialDuration = 10;  % 每个试验的持续时间(秒)
    S.GUI.ITI = 2;  % 试验间隔时间(秒)
end

% 初始化参数GUI
BpodParameterGUI('init', S);

%% 主循环
maxTrials = 100;  % 最大试验次数
for currentTrial = 1:maxTrials
    % 同步参数
    S = BpodParameterGUI('sync', S);
    
    % 创建状态机
    sma = NewStateMachine();
    
    % 添加等待状态
    sma = AddState(sma, 'Name', 'WaitForTTL', ...
        'Timer', S.GUI.TrialDuration, ...
        'StateChangeConditions', {'Tup', 'ITI', 'Wire1High', 'RecordTTL'}, ...
        'OutputActions', {});
    
    % 添加记录TTL状态
    sma = AddState(sma, 'Name', 'RecordTTL', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'WaitForTTL'}, ...
        'OutputActions', {});
    
    % 添加ITI状态
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', S.GUI.ITI, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {});
    
    % 发送状态机并运行
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    
    % 保存数据
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
        BpodSystem.Data.TrialSettings(currentTrial) = S;
        
        % 记录TTL事件
        if isfield(RawEvents, 'Events')
            if isfield(RawEvents.Events, 'Wire1High')
                BpodSystem.Data.TTLEvents(currentTrial) = RawEvents.Events.Wire1High;
            else
                BpodSystem.Data.TTLEvents(currentTrial) = [];
            end
        end
        
        SaveBpodSessionData;
        
        % 更新实时显示
        if currentTrial == 1
            figure('Position', [50 540 1000 250], 'name', 'TTL Events');
            plot(BpodSystem.Data.TTLEvents, 'o-');
            xlabel('Trial');
            ylabel('TTL Event Time (s)');
            title('TTL Events Over Time');
        else
            figure(findobj('name', 'TTL Events'));
            plot(BpodSystem.Data.TTLEvents, 'o-');
        end
    end
    
    % 处理暂停条件
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end 