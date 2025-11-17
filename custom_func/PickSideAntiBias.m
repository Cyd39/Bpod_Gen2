% PickSideAntiBias function
% This function is used to decide which side the animal should be trained on in the next trial
% based on anti-bias logic (favor the side with lower hit rate)
% Input: SessionData - the session data
% Output: nextTrialSide - the side the animal should be trained on in the next trial (1=low freq, 2=high freq)
function nextTrialSide = PickSideAntiBias(SessionData)
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
    
    % Initialize counters
    leftHits = 0;
    rightHits = 0;
    leftNonCatchTrials = 0;  % Count non-catch trials for hit rate calculation
    rightNonCatchTrials = 0;  % Count non-catch trials for hit rate calculation
    runningAvg = 15;
    
    % Calculate starting trial number with boundary check
    totalTrials = length(SessionData.RawEvents.Trial);
    StartTrialNum = max(1, totalTrials - runningAvg + 1); % Ensure StartTrialNum >= 1

    % Loop through recent trials (last runningAvg trials)
    for trialNum = StartTrialNum:totalTrials        
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Check if this is a catch trial
        isCatchTrial = false;
        if isfield(SessionData, 'IsCatchTrial') && trialNum <= length(SessionData.IsCatchTrial)
            isCatchTrial = SessionData.IsCatchTrial(trialNum);
        end
        
        % Determine correct side for this trial (for trial count only, not for hit calculation)
        % Priority 1: Use CurrentSide (most reliable, already fixed to avoid shift)
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
        % Priority 2: Fallback to CorrectSide if CurrentSide is not available (for compatibility)
        if isnan(correctSide) && isfield(SessionData, 'CorrectSide') && trialNum <= length(SessionData.CorrectSide)
            correctSide = SessionData.CorrectSide(trialNum);
        end
        
        % Check if reward was received
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
        if ~(leftRewardVisited || rightRewardVisited)
            % No reward, skip Port1 check
        elseif ~isfield(trialData, 'Events') || ~isfield(trialData.Events, 'Port1In')
            % No Port1In events, skip check
        else
            try
                port1InTimes = trialData.Events.Port1In;
                if isempty(port1InTimes)
                    % No Port1In events, skip check
                else
                    % Get stimulus start time
                    stimulusStart = NaN;
                    if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus')
                        stimulusStart = trialData.States.Stimulus(1);
                    end
                    
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
        
        % Count trials by correct side (for trial count)
        if ~isnan(correctSide)
            if correctSide == 1  && ~isCatchTrial % Left side
                leftNonCatchTrials = leftNonCatchTrials + 1;
            elseif correctSide == 2  && ~isCatchTrial % Right side
                rightNonCatchTrials = rightNonCatchTrials + 1;
            end
        end
        
        % Count rewards and hits
        % Hit = reward received AND not from Port1 AND not catch trial
        if leftRewardVisited
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isLeftRewardFromPort1
                leftHits = leftHits + 1;
            end
        end
        if rightRewardVisited
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isRightRewardFromPort1
                rightHits = rightHits + 1;
            end
        end
    end

    % Add boundary check
    if rightNonCatchTrials > 0
        rightHitRate = rightHits / rightNonCatchTrials;
    else
        rightHitRate = 0.5; % Default value
    end

    if leftNonCatchTrials > 0
        leftHitRate = leftHits / leftNonCatchTrials;
    else
        leftHitRate = 0.5; % Default value
    end

    % Ensure probability is within reasonable range
    probL = (rightHitRate + (1 - leftHitRate)) / 2;

    % Generate next trial side
    if rand() < probL
        nextTrialSide = 1;
    else
        nextTrialSide = 2;
    end
end

% Function to check if a reward was triggered by Port1
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
