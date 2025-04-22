function initBpod()
    global BpodSystem
    
    isInitialized = false;
    if ~isempty(BpodSystem)
        if isprop(BpodSystem, 'Status') && isprop(BpodSystem, 'GUIHandles')
            if BpodSystem.Status.Initialized && isgraphics(BpodSystem.GUIHandles.MainFig)
                isInitialized = true;
            end
        end
    end
    
    if ~isInitialized
        if ~isempty(BpodSystem)
            if isprop(BpodSystem, 'SerialPort')
                EndBpod; % 优雅地断开连接
            end
            BpodSystem = []; % 清除部分初始化的对象
        end
        Bpod(); % 初始化Bpod
    end
end