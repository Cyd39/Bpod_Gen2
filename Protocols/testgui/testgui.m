function testgui()
    global BpodSystem

    disp('testgui');
    % load settings
    settings = BpodSystem.ProtocolSettings.StimParams;
    disp(settings);
end
