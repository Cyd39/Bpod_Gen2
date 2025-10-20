% SwitchWhenNCorrect protocol
% This protocol is used to switch the correct side when the animal has corrected N times
function SwitchWhenNCorrect()
    global BpodSystem

    % Create trial manager object
    trialManager = BpodTrialManager;

    % Initialize HiFi module
    H = BpodHiFi('COM3');
    H.SamplingRate = 192000;

    % get parameters from StimParamGui
    StimParams = BpodSystem.ProtocolSettings.StimParams;
    NumTrials = StimParams.Behave.NumTrials; 
    
    
