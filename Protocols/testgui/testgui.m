function testgui()
    global BpodSystem

    % get parameters from StimParamGui
    StimParams = BpodSystem.ProtocolSettings.StimParams;
    
    % Setup default parameters
    S = struct;
    % use the behavior parameters from StimParamGui as default values
    S.GUI.MinITI = StimParams.Behave.MinITI; % seconds
    S.GUI.MaxITI = StimParams.Behave.MaxITI; % seconds
    S.GUI.MinQuietTime = StimParams.Behave.MinQuietTime; % seconds
    S.GUI.MaxQuietTime = StimParams.Behave.MaxQuietTime; % seconds
    S.GUI.ValveTime = StimParams.Behave.ValveTime; % seconds
    S.GUI.ResWin = StimParams.Behave.ResWin; % seconds

    % Initialize parameter GUI
    BpodParameterGUI('init', S);

    for i = 1:10
        % get parameters from GUI
        S = BpodParameterGUI('sync', S);
        disp(['MinITI: ' num2str(S.GUI.MinITI)]);
        disp(['MaxITI: ' num2str(S.GUI.MaxITI)]);
        disp(['MinQuietTime: ' num2str(S.GUI.MinQuietTime)]);
        disp(['MaxQuietTime: ' num2str(S.GUI.MaxQuietTime)]);
        disp(['ValveTime: ' num2str(S.GUI.ValveTime)]);
        disp(['ResWin: ' num2str(S.GUI.ResWin)]);
        pause(3);
    end

end
