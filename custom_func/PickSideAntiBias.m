% PickSideAntiBias function
% This function is used to decide which side the animal should be trained on in the next trial
% based on anti-bias logic (favor the side with lower hit rate)
% Input: SessionData - the session data
% Output: nextTrialSide - the spout side for the next trial (1=left, 2=right)
% Note: The return value is a spout (left/right), not a frequency side (low/high freq)
% The caller (AntiBias.m) will convert this to frequency side based on configuration
function nextTrialSide = PickSideAntiBias(SessionData)
    
    runningAvg = 10;
    % maxConsec = 3; % TO DO
   
    % Calculate starting trial number with boundary check
    totalTrials = length(SessionData.RawEvents.Trial);
    if totalTrials < 2 * runningAvg
        probL = 0.5;
        nextTrialSide = 2 - (rand() < probL);
        return
    end
    trialIdx = 1:totalTrials;
    leftNonCatchTrials = find(SessionData.CorrectSide(trialIdx) == 1 & ~SessionData.IsCatchTrial(trialIdx),...
                               runningAvg, 'last');
    rightNonCatchTrials = find(SessionData.CorrectSide(trialIdx) == 2 & ~SessionData.IsCatchTrial(trialIdx),...
                               runningAvg, 'last');
    % StartTrialNum = max(1, totalTrials - runningAvg + 1); % Ensure StartTrialNum >= 1

    % Loop through recent Left trials (last runningAvg trials)
    NumLeftNonCatchTrials = length(leftNonCatchTrials);
    rewarded = nan(1,NumLeftNonCatchTrials);
    triggered = nan(1,NumLeftNonCatchTrials);
    for trialNum = 1:NumLeftNonCatchTrials
        % Get trial data
        trialData = SessionData.RawEvents.Trial{leftNonCatchTrials(trialNum)};
        rewarded(trialNum) = any(~isnan([trialData.States.LeftReward,trialData.States.RightReward]));
        triggered(trialNum) = isTriggered(trialData);
    end
    leftHits = sum(rewarded & ~triggered);
    leftHitRate = leftHits / NumLeftNonCatchTrials;

    % Loop through recent Right trials (last runningAvg trials)
    NumRightNonCatchTrials = length(rightNonCatchTrials);
    rewarded = nan(1,NumRightNonCatchTrials);
    triggered = nan(1,NumRightNonCatchTrials);
    for trialNum = 1:NumRightNonCatchTrials
        % Get trial data
        trialData = SessionData.RawEvents.Trial{rightNonCatchTrials(trialNum)};
        rewarded(trialNum) = any(~isnan([trialData.States.LeftReward,trialData.States.RightReward]));
        triggered(trialNum) = isTriggered(trialData);
    end
    rightHits = sum(rewarded & ~triggered);
    rightHitRate = rightHits / NumRightNonCatchTrials;

    % Calculate probability of selecting left spout based on anti-bias logic
    % Formula: probL = (rightHitRate + (1 - leftHitRate)) / 2
    % This ensures:
    % - If right side performs well (high rightHitRate), increase prob of left (bias correction)
    % - If left side performs poorly (low leftHitRate), increase prob of left (bias correction)
    % - If both sides equal (0.5 each), probL = 0.5 (balanced)
    % Range: probL is always between 0 and 1
    probL = (rightHitRate + (1 - leftHitRate)) / 2;

    % Generate next trial side (1=left spout, 2=right spout)
    if rand() < probL
        nextTrialSide = 1; % Left spout
    else
        nextTrialSide = 2; % Right spout
    end
end

% Function to check if a reward was triggered by Port1
function triggered = isTriggered(trialData)

    if isfield(trialData.Events, 'Condition6') % hopefully not NaN.
        triggered = true;
    else
        triggered = false;
    end
end
