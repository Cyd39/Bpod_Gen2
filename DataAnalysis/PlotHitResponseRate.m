function PlotHitResponseRate(SessionData)
    % PlotHitResponseRate - Plot hit rate and response rate from saved SessionData
    % sliding window: last 15 trials for each side.
    % This function plots 4 lines:
    % - Left Response Rate: left-side trials with any lick in response window / left trials (sliding window)
    % - Left Hit Rate: left hits / left non-catch trials (sliding window)
    % - Right Response Rate: right-side trials with any lick in response window / right trials (sliding window)
    % - Right Hit Rate: right hits / right non-catch trials (sliding window)
    % Response rate: Any lick (BNC1High or BNC2High) within response window (stimulus start to ResWin), regardless of correctness. 
    % Hit rate: Correct response (reward received, not from Port1, not catch trial).  
    % Input:
    %   SessionData - Bpod session data structure
    
    % Window size for response rate calculation
    windowSize = 15;

    % Get side configuration from StimParams
    highFreqSpout = NaN;
    lowFreqSpout = NaN;
    if isfield(SessionData, 'StimParams') && isfield(SessionData.StimParams, 'Behave')
        if isfield(SessionData.StimParams.Behave, 'CorrectSpout')
            highFreqSpout = SessionData.StimParams.Behave.CorrectSpout; % 1 = left, 2 = right
            lowFreqSpout = 3 - highFreqSpout; % Opposite of high frequency spout
        end
    end
    % Use default configuration if not found
    if isnan(highFreqSpout)
        highFreqSpout = 2; % Default: high frequency -> right
        lowFreqSpout = 1;  % Default: low frequency -> left
    end
    
    % Get number of trials
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        error('SessionData does not contain RawEvents.Trial');
    end
    nTrials = length(SessionData.RawEvents.Trial);
    
    % Initialize arrays to store rates
    leftResponseRate = NaN(nTrials, 1);
    leftHitRate = NaN(nTrials, 1);
    rightResponseRate = NaN(nTrials, 1);
    rightHitRate = NaN(nTrials, 1);
    
    % Initialize arrays to store trial data for sliding window calculation
    % Store: correctSide, leftResponse, rightResponse, leftHit, rightHit, isCatchTrial
    trialCorrectSide = NaN(nTrials, 1);
    trialLeftResponse = false(nTrials, 1);  % Any lick in response window (left side trials)
    trialRightResponse = false(nTrials, 1); % Any lick in response window (right side trials)
    trialLeftHit = false(nTrials, 1);
    trialRightHit = false(nTrials, 1);
    trialIsCatchTrial = false(nTrials, 1);    
    
    % First pass: collect all trial data
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Check if this is a catch trial
        isCatchTrial = false;
        if isfield(SessionData, 'IsCatchTrial') && trialNum <= length(SessionData.IsCatchTrial)
            isCatchTrial = SessionData.IsCatchTrial(trialNum);
        end
        
        % Determine correct side for this trial
        correctSide = NaN;
        if isfield(SessionData, 'CurrentSide') && trialNum <= length(SessionData.CurrentSide)
            currentSide = SessionData.CurrentSide(trialNum);
            if ~isnan(currentSide)
                % Derive correctSide from CurrentSide using configuration
                if currentSide == 1  % Low frequency side
                    correctSide = lowFreqSpout;
                elseif currentSide == 2  % High frequency side
                    correctSide = highFreqSpout;
                end
            end
        end
        % Fallback to CorrectSide if CurrentSide is not available
        if isnan(correctSide) && isfield(SessionData, 'CorrectSide') && trialNum <= length(SessionData.CorrectSide)
            correctSide = SessionData.CorrectSide(trialNum);
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
        leftRewardVisited = false;
        rightRewardVisited = false;
        if isfield(trialData, 'States')
            if isfield(trialData.States, 'LeftReward')
                leftRewardVisited = ~isnan(trialData.States.LeftReward(1));
            end
            if isfield(trialData.States, 'RightReward')
                rightRewardVisited = ~isnan(trialData.States.RightReward(1));
            end
        end
        
        % Check if reward was triggered by Port1 click (Condition6)
        isLeftRewardFromPort1 = false;
        isRightRewardFromPort1 = false;
        
        % Only check Port1 if there was a reward
        if (leftRewardVisited || rightRewardVisited) && isfield(trialData, 'Events') && isfield(trialData.Events, 'Port1In')
            try
                port1InTimes = trialData.Events.Port1In;
                if ~isempty(port1InTimes)
                    % Determine valid Port1In times (before or during stimulus)
                    if ~isnan(stimulusStart)
                        validPort1InMask = port1InTimes <= stimulusStart;
                    else
                        validPort1InMask = port1InTimes >= 0 & port1InTimes <= 10;
                    end
                    
                    if any(validPort1InMask)
                        % Check if left reward was triggered by Port1
                        if leftRewardVisited
                            isLeftRewardFromPort1 = checkPort1TriggeredReward(...
                                trialData, 'LeftReward', port1InTimes, validPort1InMask, stimulusStart);
                        end
                        
                        % Check if right reward was triggered by Port1
                        if rightRewardVisited
                            isRightRewardFromPort1 = checkPort1TriggeredReward(...
                                trialData, 'RightReward', port1InTimes, validPort1InMask, stimulusStart);
                        end
                    end
                end
            catch
                % If extraction fails, assume reward is from animal lick
            end
        end
        
        % Store trial data
        trialCorrectSide(trialNum) = correctSide;
        trialIsCatchTrial(trialNum) = isCatchTrial;
        
        % Count hits (for hit rate calculation using sliding window)
        % Hit = reward received AND not from Port1 AND not catch trial
        if leftRewardVisited
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isLeftRewardFromPort1
                trialLeftHit(trialNum) = true;
            end
        end
        if rightRewardVisited
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isRightRewardFromPort1
                trialRightHit(trialNum) = true;
            end
        end
    end
    
    % Second pass: calculate response rate and hit rate using sliding window (last 15 trials)
    for trialNum = 1:nTrials
        % Calculate left response rate and hit rate (last 15 left-side trials)
        leftSideTrials = find(trialCorrectSide(1:trialNum) == 1);
        if ~isempty(leftSideTrials)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(leftSideTrials) - windowSize + 1);
            recentLeftTrials = leftSideTrials(startIdx:end);
            if ~isempty(recentLeftTrials)
                % Response rate: any lick in response window
                leftResponsesInWindow = sum(trialLeftResponse(recentLeftTrials));
                leftResponseRate(trialNum) = leftResponsesInWindow / min(windowSize, length(recentLeftTrials));
                
                % Hit rate: hits / non-catch trials in window
                leftNonCatchInWindow = recentLeftTrials(~trialIsCatchTrial(recentLeftTrials));
                if ~isempty(leftNonCatchInWindow)
                    leftHitsInWindow = sum(trialLeftHit(leftNonCatchInWindow));
                    leftHitRate(trialNum) = leftHitsInWindow / length(leftNonCatchInWindow);
                end
            end
        end
        
        % Calculate right response rate and hit rate (last 15 right-side trials)
        rightSideTrials = find(trialCorrectSide(1:trialNum) == 2);
        if ~isempty(rightSideTrials)
            % Get last windowSize trials (or all if less than windowSize)
            startIdx = max(1, length(rightSideTrials) - windowSize + 1);
            recentRightTrials = rightSideTrials(startIdx:end);
            if ~isempty(recentRightTrials)
                % Response rate: any lick in response window
                rightResponsesInWindow = sum(trialRightResponse(recentRightTrials));
                rightResponseRate(trialNum) = rightResponsesInWindow / min(windowSize, length(recentRightTrials));
                
                % Hit rate: hits / non-catch trials in window
                rightNonCatchInWindow = recentRightTrials(~trialIsCatchTrial(recentRightTrials));
                if ~isempty(rightNonCatchInWindow)
                    rightHitsInWindow = sum(trialRightHit(rightNonCatchInWindow));
                    rightHitRate(trialNum) = rightHitsInWindow / length(rightNonCatchInWindow);
                end
            end
        end
    end
    
    % Create figure
    figure('Name', 'Hit Rate and Response Rate', 'Position', [100 100 1200 600]);
    
    % Plot all 4 lines
    trialNumbers = 1:nTrials;
    hold on;
    
    % Left Response Rate
    plot(trialNumbers, leftResponseRate, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Left Response Rate');
    
    % Left Hit Rate
    plot(trialNumbers, leftHitRate, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Left Hit Rate');
    
    % Right Response Rate
    plot(trialNumbers, rightResponseRate, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Right Response Rate');
    
    % Right Hit Rate
    plot(trialNumbers, rightHitRate, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Right Hit Rate');
    
    % Formatting
    xlabel('Trial Number', 'FontSize', 12);
    ylabel('Rate', 'FontSize', 12);
    title(['Hit Rate and Response Rate Over Trials (window size = ' num2str(windowSize) ' trials)'], 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10);
    grid on;
    ylim([0 1]);
    xlim([1 nTrials]);
    
    hold off;
end

% Helper function to check if a reward was triggered by Port1
function isTriggered = checkPort1TriggeredReward(trialData, rewardStateName, port1InTimes, validPort1InMask, stimulusStart)
    % Check if reward state exists and get reward time
    if ~isfield(trialData, 'States') || ~isfield(trialData.States, rewardStateName)
        isTriggered = false;
        return;
    end
    
    try
        rewardTime = trialData.States.(rewardStateName)(1);
        if isnan(rewardTime)
            isTriggered = false;
            return;
        end
        
        % Check time relationship between Port1In and reward
        if ~isnan(stimulusStart)
            % Port1In should be before reward, and reward should be within 2 seconds
            timeFromPort1ToReward = rewardTime - port1InTimes;
            isTriggered = any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & validPort1InMask);
        else
            % If no stimulus start, check absolute time difference
            timeDiff = abs(port1InTimes - rewardTime);
            isTriggered = any(timeDiff < 2 & validPort1InMask);
        end
    catch
        % If extraction fails, assume reward is from animal lick
        isTriggered = false;
    end
end
