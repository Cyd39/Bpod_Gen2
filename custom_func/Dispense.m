function Dispense(ValveNum,DropSize,NumberOfDrops)
    global BpodSystem

    if nargin < 3; NumberOfDrops = 1; end
    InterDropInterval = 0.2; %s

    Valve = ['Valve',num2str(ValveNum)];

    % Create state machine
    sma = NewStateMachine();
    ValveTime = BpodLiquidCalibration('GetValveTimes', DropSize, ValveNum);

    disp(['Valve : ', Valve])
    disp(['Drop Size: ', num2str(DropSize),' uL'])
    disp(['Valve Open Time: ', num2str(ValveTime*1000,'%.1f'), ' ms'])

    sma = AddState(sma, 'Name', 'Ready', ...
        'Timer', 0.1, ...
        'StateChangeConditions', {'Tup', 'Dispense'}, ...
        'OutputActions', {Valve, 0});
    sma = AddState(sma, 'Name', 'Dispense', ...
        'Timer', ValveTime, ...
        'StateChangeConditions', {'Tup', 'After'}, ...
        'OutputActions', {Valve, 1});
    sma = AddState(sma, 'Name', 'After', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'exit'}, ... % Reset NoLick Timer
        'OutputActions', {Valve, 0});

    for dropNum = 1:NumberOfDrops
        % Send state machine to Bpod device
        SendStateMachine(sma);
    
        % Run state machine
        RawEvents = RunStateMachine;

        pause(InterDropInterval)
    end

    RunProtocol('Stop');