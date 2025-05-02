function TestGUI()
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

    % Create update button
    h = struct();
    h.updateButton = uicontrol('Style', 'pushbutton', ...
        'String', 'Update Parameters', ...
        'Position', [160 240 150 30], ...  % [left bottom width height]
        'FontSize', 12, ...
        'Callback', @updateParams);

    % Initialize update flag
    updateFlag = false;

    % Update button callback function
    function updateParams(~, ~)
        updateFlag = true;
        disp('Parameters updated');
    end

    % Main loop
    for i = 1:10
        % Check if update button was pressed
        if updateFlag
            % get parameters from GUI
            S = BpodParameterGUI('sync', S);
            updateFlag = false; % reset flag
        end
        disp(['MinITI: ' num2str(S.GUI.MinITI)]);
        disp(['MaxITI: ' num2str(S.GUI.MaxITI)]);
        disp(['MinQuietTime: ' num2str(S.GUI.MinQuietTime)]);
        disp(['MaxQuietTime: ' num2str(S.GUI.MaxQuietTime)]);
        disp(['ValveTime: ' num2str(S.GUI.ValveTime)]);
        disp(['ResWin: ' num2str(S.GUI.ResWin)]);

        pause(10); % small pause to prevent CPU overuse

        % Check if protocol should end
        if BpodSystem.Status.BeingUsed == 0
            break;
        end
    end

    % End of protocol
    disp('Protocol ended');
end
