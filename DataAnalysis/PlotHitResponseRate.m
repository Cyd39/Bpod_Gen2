function PlotHitResponseRate(SessionData, varargin)
    % PlotHitResponseRate - Plot hit rate and response rate from SessionData
    % sliding window: last 15 trials for each side.
    % This function plots 4 lines:
    % - Left Response Rate: left-side trials with any lick in response window / left trials (sliding window)
    % - Left Hit Rate: left hits / left non-catch trials (sliding window)
    % - Right Response Rate: right-side trials with any lick in response window / right trials (sliding window)
    % - Right Hit Rate: right hits / right non-catch trials (sliding window)
    % Response rate: Any lick (BNC1High or BNC2High) within response window (stimulus start to ResWin), regardless of correctness. 
    % Hit rate: Correct response (reward received, not from Port1, not catch trial).  
    % 
    % Inputs:
    %   SessionData - Bpod session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'Hit Rate and Response Rate')
    %
    % Usage:
    %   Online mode: PlotHitResponseRate(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', responseRateAx);
    %   Offline mode: PlotHitResponseRate(SessionData);
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'Hit Rate and Response Rate', @ischar);
    parse(p, varargin{:});
    
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    
    % Activate figure if provided (for online mode)
    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Create axes if not provided (offline mode)
    if isempty(ax)
        figure('Name', figureName, 'Position', [100 100 1200 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
    end
    
    % Window size for response rate calculation
    windowSize = 15;
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(ax);
        text(ax, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Get number of trials
    nTrials = length(SessionData.RawEvents.Trial);
    
    % Check if there are any trials
    if nTrials == 0
        warning('No trials found in SessionData');
        cla(ax);
        text(ax, 0.5, 0.5, 'No trials available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Initialize arrays to store rates
    leftResponseRate = NaN(nTrials, 1);
    leftHitRate = NaN(nTrials, 1);
    rightResponseRate = NaN(nTrials, 1);
    rightHitRate = NaN(nTrials, 1);
    
    % Initialize arrays to store trial data for sliding window calculation
    % Note: trialCorrectSide and trialIsCatchTrial are not needed - use SessionData directly
    trialLeftResponse = false(nTrials, 1);  % Any lick in response window (left side trials)
    trialRightResponse = false(nTrials, 1); % Any lick in response window (right side trials)
    trialLeftHit = false(nTrials, 1);
    trialRightHit = false(nTrials, 1);    
    
    % First pass: collect all trial data
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Get correct side and catch trial status from SessionData
        % These are already stored in SessionData by the protocol
        correctSide = NaN;
        if isfield(SessionData, 'CorrectSide') && trialNum <= length(SessionData.CorrectSide)
            correctSide = SessionData.CorrectSide(trialNum);
        end
        
        isCatchTrial = false;
        if isfield(SessionData, 'IsCatchTrial') && trialNum <= length(SessionData.IsCatchTrial)
            isCatchTrial = SessionData.IsCatchTrial(trialNum);
        end
        
        % Get response window duration for this trial
        ResWin = NaN;
        if isfield(SessionData, 'ResWin') && trialNum <= length(SessionData.ResWin)
            ResWin = SessionData.ResWin(trialNum);
        elseif isfield(SessionData, 'TrialSettings') && trialNum <= length(SessionData.TrialSettings)
            if isfield(SessionData.TrialSettings(trialNum), 'GUI') && isfield(SessionData.TrialSettings(trialNum).GUI, 'ResWin')
                ResWin = SessionData.TrialSettings(trialNum).GUI.ResWin;
            end
        end
        
        % Get stimulus start time
        stimulusStart = NaN;
        if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus')
            stimulusStart = trialData.States.Stimulus(1);
        end
        
        % Check if there was any lick in response window (BNC1High or BNC2High)
        % Response = any lick within response window, regardless of correctness
        hasResponse = false;
        if ~isnan(stimulusStart) && ~isnan(ResWin)
            responseWindowEnd = stimulusStart + ResWin;
            
            % Check for any lick events (BNC1High or BNC2High) in response window
            if isfield(trialData, 'Events')
                % Check BNC1High (left lick port)
                if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                    licksInWindow = trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd;
                    if any(licksInWindow)
                        hasResponse = true;
                    end
                end
                
                % Check BNC2High (right lick port)
                if ~hasResponse && isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                    licksInWindow = trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd;
                    if any(licksInWindow)
                        hasResponse = true;
                    end
                end
            end
        end
        
        % Store response based on correct side (for response rate calculation)
        if ~isnan(correctSide) && hasResponse
            if correctSide == 1  % Left side trial
                trialLeftResponse(trialNum) = true;
            elseif correctSide == 2  % Right side trial
                trialRightResponse(trialNum) = true;
            end
        end
        
        % Check if reward was received (for hit rate calculation)
        % Use same logic as PickSideAntiBias: check if any reward state was visited
        rewarded = false;
        if isfield(trialData, 'States')
            rewarded = any(~isnan([trialData.States.LeftReward, trialData.States.RightReward]));
        end
        
        % Check if reward was triggered by Condition6 (Port1 click)
        % Use same simple check as PickSideAntiBias
        isCondition6 = false;
        if isfield(trialData, 'Events') && isfield(trialData.Events, 'Condition6')
            isCondition6 = true;
        end
        
        % Count hits (for hit rate calculation using sliding window)
        % Hit = reward received AND not Condition6 AND not catch trial
        % Same logic as PickSideAntiBias: rewarded & ~triggered & ~isCatchTrial
        if rewarded && ~isCatchTrial && ~isCondition6
            if correctSide == 1  % Left side trial
                trialLeftHit(trialNum) = true;
            elseif correctSide == 2  % Right side trial
                trialRightHit(trialNum) = true;
            end
        end
    end
    
    % Second pass: calculate response rate and hit rate using sliding window (last 15 trials)
    % Use SessionData.CorrectSide and SessionData.IsCatchTrial directly
    for trialNum = 1:nTrials
        % Get correct side array (handle missing field)
        if isfield(SessionData, 'CorrectSide')
            correctSideArray = SessionData.CorrectSide(1:min(trialNum, length(SessionData.CorrectSide)));
        else
            correctSideArray = NaN(1, trialNum);
        end
        
        % Get catch trial array (handle missing field)
        if isfield(SessionData, 'IsCatchTrial')
            isCatchTrialArray = SessionData.IsCatchTrial(1:min(trialNum, length(SessionData.IsCatchTrial)));
        else
            isCatchTrialArray = false(1, trialNum);
        end
        
        % Calculate left response rate and hit rate (last 15 left-side trials)
        leftSideTrials = find(correctSideArray == 1);
        if ~isempty(leftSideTrials)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(leftSideTrials) - windowSize + 1);
            recentLeftTrials = leftSideTrials(startIdx:end);
            if ~isempty(recentLeftTrials)
                % Response rate: any lick in response window
                leftResponsesInWindow = sum(trialLeftResponse(recentLeftTrials));
                leftResponseRate(trialNum) = leftResponsesInWindow / min(windowSize, length(recentLeftTrials));
                
                % Hit rate: hits / non-catch trials in window
                leftNonCatchInWindow = recentLeftTrials(~isCatchTrialArray(recentLeftTrials));
                if ~isempty(leftNonCatchInWindow)
                    leftHitsInWindow = sum(trialLeftHit(leftNonCatchInWindow));
                    leftHitRate(trialNum) = leftHitsInWindow / length(leftNonCatchInWindow);
                end
            end
        end
        
        % Calculate right response rate and hit rate (last 15 right-side trials)
        rightSideTrials = find(correctSideArray == 2);
        if ~isempty(rightSideTrials)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(rightSideTrials) - windowSize + 1);
            recentRightTrials = rightSideTrials(startIdx:end);
            if ~isempty(recentRightTrials)
                % Response rate: any lick in response window
                rightResponsesInWindow = sum(trialRightResponse(recentRightTrials));
                rightResponseRate(trialNum) = rightResponsesInWindow / min(windowSize, length(recentRightTrials));
                
                % Hit rate: hits / non-catch trials in window
                rightNonCatchInWindow = recentRightTrials(~isCatchTrialArray(recentRightTrials));
                if ~isempty(rightNonCatchInWindow)
                    rightHitsInWindow = sum(trialRightHit(rightNonCatchInWindow));
                    rightHitRate(trialNum) = rightHitsInWindow / length(rightNonCatchInWindow);
                end
            end
        end
    end
    
    % Plot all 4 lines
    axes(ax);  % Activate the correct axes
    cla(ax);   % Clear previous plot
    hold(ax, 'on');
    
    trialNumbers = 1:nTrials;
    
    % Left Response Rate
    plot(ax, trialNumbers, leftResponseRate, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Left Response Rate');
    
    % Left Hit Rate
    plot(ax, trialNumbers, leftHitRate, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Left Hit Rate');
    
    % Right Response Rate
    plot(ax, trialNumbers, rightResponseRate, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Right Response Rate');
    
    % Right Hit Rate
    plot(ax, trialNumbers, rightHitRate, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Right Hit Rate');
    
    % Formatting
    xlabel(ax, 'Trial Number', 'FontSize', 12);
    ylabel(ax, 'Rate', 'FontSize', 12);
    title(ax, ['Hit Rate and Response Rate Over Trials (window size = ' num2str(windowSize) ' trials)'], 'FontSize', 12);
    legend(ax, 'Location', 'best', 'FontSize', 10);
    grid(ax, 'on');
    ylim(ax, [0 1]);
    xlim(ax, [1 nTrials]);
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end
