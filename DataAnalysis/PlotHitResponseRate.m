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
    
    % Extract trial indices from SessionData
    if isfield(SessionData,"IsCatchTrial")
        isCatchTrial = SessionData.IsCatchTrial(:);  % Ensure column vector
    else
        isCatchTrial = zeros(SessionData.nTrials, 1);
    end
    catchTrialIndices = find(isCatchTrial);
    nonCatchTrialIndices = find(~isCatchTrial);
    
    % Extract side-specific indices from SessionData
    if height(SessionData.CorrectSide) ~= nTrials
        correctSide = SessionData.CorrectSide(1:nTrials);
    else
        correctSide = SessionData.CorrectSide(:);  % Ensure column vector
    end
    leftSideTrials = find(correctSide == 1);
    rightSideTrials = find(correctSide == 2);
    
    % Extract side-specific non-catch trial indices from SessionData
    leftSideNonCatchTrials = leftSideTrials(~isCatchTrial(leftSideTrials));
    rightSideNonCatchTrials = rightSideTrials(~isCatchTrial(rightSideTrials));
    
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
        
        % Get response window duration for this trial
        if ~isfield(SessionData,'ResWin')
            % setting for conditioning 
            ResWin = 50;
        else
            ResWin = SessionData.ResWin(trialNum);
        end

        % Get stimulus start time
        stimulusStart = trialData.States.Stimulus(1);
        responseWindowEnd = stimulusStart + ResWin;
        
        hasResponse = false;
        % Check if there was any lick in response window (BNC1High or BNC2High) if not a catch trial
        if ~isCatchTrial(trialNum)
            % Check for any lick events (BNC1High or BNC2High) in response window
            if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                licksInWindow = trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd;
                if any(licksInWindow)
                    hasResponse = true;
                end
            end
            if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                licksInWindow = trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd;
                if any(licksInWindow)
                    hasResponse = true;
                end
            end
        end
        
        % Store response based on correct side (for response rate calculation)
        if hasResponse
            if SessionData.CorrectSide(trialNum) == 1  % Left side trial
                trialLeftResponse(trialNum) = true;
            elseif SessionData.CorrectSide(trialNum) == 2  % Right side trial
                trialRightResponse(trialNum) = true;
            end
        end
        
        % Check if reward was received (for hit rate calculation)
        % Use same logic as PickSideAntiBias: check if any reward state was visited
        rewarded = any(~isnan([trialData.States.LeftReward, trialData.States.RightReward]));
        
        % Check if reward was triggered by Condition6 (Port1 click)
        % Use same simple check as PickSideAntiBias
        isCondition6 = false;
        if isfield(trialData, 'Events') && isfield(trialData.Events, 'Condition6')
            isCondition6 = true;
        end
        
        % Count hits (for hit rate calculation using sliding window)
        % Hit = reward received AND not Condition6 AND not catch trial
        % Same logic as PickSideAntiBias: rewarded & ~triggered & ~isCatchTrial
        if rewarded && ~isCatchTrial(trialNum) && ~isCondition6
            if SessionData.CorrectSide(trialNum) == 1  % Left side trial
                trialLeftHit(trialNum) = true;
            elseif SessionData.CorrectSide(trialNum) == 2  % Right side trial
                trialRightHit(trialNum) = true;
            end
        end
    end
    
    
    % Second pass: calculate response rate and hit rate using sliding window (last 15 trials), only for non-catch trials
    for trialNum = nonCatchTrialIndices'
        % Get left-side non-catch trials up to current trial
        leftSideTrialsUpToNow = leftSideNonCatchTrials(leftSideNonCatchTrials <= trialNum);
        if ~isempty(leftSideTrialsUpToNow)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(leftSideTrialsUpToNow) - windowSize + 1);
            recentLeftTrials = leftSideTrialsUpToNow(startIdx:end);
            if ~isempty(recentLeftTrials)
                % Response rate: any lick in response window
                leftResponsesInWindow = sum(trialLeftResponse(recentLeftTrials));
                leftHitsInWindow = sum(trialLeftHit(recentLeftTrials));
                leftResponseRate(trialNum) = leftResponsesInWindow / length(recentLeftTrials);
                leftHitRate(trialNum) = leftHitsInWindow / length(recentLeftTrials);
            end
        end
        
        % Get right-side non-catch trials up to current trial
        rightSideTrialsUpToNow = rightSideNonCatchTrials(rightSideNonCatchTrials <= trialNum);
        if ~isempty(rightSideTrialsUpToNow)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(rightSideTrialsUpToNow) - windowSize + 1);
            recentRightTrials = rightSideTrialsUpToNow(startIdx:end);
            if ~isempty(recentRightTrials)
                % Response rate: any lick in response window
                rightResponsesInWindow = sum(trialRightResponse(recentRightTrials));
                rightHitsInWindow = sum(trialRightHit(recentRightTrials));
                rightResponseRate(trialNum) = rightResponsesInWindow / length(recentRightTrials);
                rightHitRate(trialNum) = rightHitsInWindow / length(recentRightTrials);
            end
        end
    end
    
    % For catch trials, copy values from previous non-catch trial using vectorized operations
    % This handles consecutive catch trials: all will use the last non-catch trial's values
    if ~isempty(catchTrialIndices)
        % Create array: non-catch trials have their index, catch trials have 0
        % Ensure both are column vectors to avoid dimension mismatch
        idxArray = (1:nTrials)' .* (~isCatchTrial);
        
        % Use cummax to forward-fill: each position gets the maximum (last non-zero) index up to that point
        % This effectively gives us the last non-catch trial index for each position
        lastNonCatchIdx = cummax(idxArray);
        
        % Copy values for catch trials from their previous non-catch trial
        % Only process catch trials that have a valid previous non-catch trial
        validMask = lastNonCatchIdx(catchTrialIndices) > 0;
        validCatchTrials = catchTrialIndices(validMask);
        if ~isempty(validCatchTrials)
            prevIndices = lastNonCatchIdx(validCatchTrials);
            leftResponseRate(validCatchTrials) = leftResponseRate(prevIndices);
            leftHitRate(validCatchTrials) = leftHitRate(prevIndices);
            rightResponseRate(validCatchTrials) = rightResponseRate(prevIndices);
            rightHitRate(validCatchTrials) = rightHitRate(prevIndices);
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
    xlabel(ax, 'Trial Number');
    ylabel(ax, 'Rate');
    title(ax, ['Hit Rate and Response Rate Over Trials (window size = ' num2str(windowSize) ' trials)']);
    legend(ax, 'Location', 'best');
    grid(ax, 'on');
    ylim(ax, [0 1]);
    xlim(ax, [1 nTrials]);
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end
