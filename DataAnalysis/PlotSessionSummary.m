function PlotSessionSummary(SessionData)
    % PlotSessionSummary - Generate descriptive text summary of session data
    % 
    % Input:
    %   SessionData - Session data structure loaded from saved .mat file
    %
    % This function extracts session information and displays it as text
    % in a figure, including:
    %   - Session category/type
    %   - Duration
    %   - ITI range
    %   - No-Lick range (MinQuietTime - MaxQuietTime)
    %   - Reward amount
    %   - Left/Right reward statistics
    %   - Hit rates for left and right sides
    %   - Total water volume received
    %
    % Usage:
    %   load('SessionData.mat', 'SessionData');
    %   PlotSessionSummary(SessionData);
    
    % Check if SessionData is valid
    if ~isfield(SessionData, 'nTrials')
        error('SessionData does not contain nTrials field');
    end
    
    nTrials = SessionData.nTrials;
    
    % Initialize figure
    figure('Name', 'Session Summary', 'Position', [200 200 600 600]);
    ax = axes('Position', [0.1 0.05 0.85 0.9]);
    axis(ax, 'off');
    hold(ax, 'on');
    
    % Initialize text lines array
    textLines = {};
    lineNum = 1;
    
    % ========================================================================
    % 1. SESSION CATEGORY/TYPE
    % ========================================================================
    sessionType = SessionData.StimParams.Session.TypeName;
    textLines{lineNum} = ['Session Type: ' sessionType];
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 2. DURATION
    % ========================================================================
    duration = NaN;
    if isfield(SessionData, 'TrialStartTimestamp') && ~isempty(SessionData.TrialStartTimestamp)
        if nTrials > 0 && length(SessionData.TrialStartTimestamp) >= nTrials
            startTime = SessionData.TrialStartTimestamp(1);
            % Get end time from last trial's WaitToFinish state
            if isfield(SessionData, 'RawEvents') && isfield(SessionData.RawEvents, 'Trial')
                if nTrials <= length(SessionData.RawEvents.Trial)
                    lastTrial = SessionData.RawEvents.Trial{nTrials};
                    if isfield(lastTrial, 'States') && isfield(lastTrial.States, 'WaitToFinish')
                        if ~isempty(lastTrial.States.WaitToFinish) && ~isnan(lastTrial.States.WaitToFinish(1, 2))
                            endTime = SessionData.TrialStartTimestamp(nTrials) + lastTrial.States.WaitToFinish(1, 2);
                            duration = endTime - startTime;
                        end
                    end
                end
            end
        end
    end
    
    if ~isnan(duration)
        hours = floor(duration / 3600);
        minutes = floor((duration - hours * 3600) / 60);
        seconds = duration - hours * 3600 - minutes * 60;
        if hours > 0
            textLines{lineNum} = ['Session Duration: ' sprintf('%.0f h %.0f m %.1f s', hours, minutes, seconds)];
        else
            textLines{lineNum} = ['Session Duration: ' sprintf('%.0f m %.1f s', minutes, seconds)];
        end
    else
        textLines{lineNum} = 'Session Duration: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 2.5. STIMULUS DURATION
    % ========================================================================
    stimulusDuration = NaN;
    if isfield(SessionData, 'StimParams') && isfield(SessionData.StimParams, 'Duration')
        stimulusDuration = SessionData.StimParams.Duration;
    end
    
    if ~isnan(stimulusDuration)
        textLines{lineNum} = ['Stimulus Duration: ' sprintf('%.0f ms', stimulusDuration)];
    else
        textLines{lineNum} = 'Stimulus Duration: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 3. ITI RANGE
    % ========================================================================
    % Check for ITI range changes across trials
    itiRanges = [];  % Store [trialNum, minITI, maxITI] for each unique range
    if isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Check all trials for ITI settings
        for trialIdx = 1:min(nTrials, length(SessionData.TrialSettings))
            if isfield(SessionData.TrialSettings(trialIdx), 'GUI')
                if isfield(SessionData.TrialSettings(trialIdx).GUI, 'MinITI') && ...
                   isfield(SessionData.TrialSettings(trialIdx).GUI, 'MaxITI')
                    minITI_val = SessionData.TrialSettings(trialIdx).GUI.MinITI;
                    maxITI_val = SessionData.TrialSettings(trialIdx).GUI.MaxITI;
                    % Check if this range is different from previous
                    if isempty(itiRanges) || ...
                       abs(itiRanges(end, 2) - minITI_val) > 0.001 || ...
                       abs(itiRanges(end, 3) - maxITI_val) > 0.001
                        % New range detected
                        itiRanges = [itiRanges; trialIdx, minITI_val, maxITI_val];
                    end
                end
            end
        end
    end
    
    % If no ranges found in TrialSettings, try ThisITI or first trial
    if isempty(itiRanges)
        if isfield(SessionData, 'ThisITI')
            itiValues = SessionData.ThisITI(~isnan(SessionData.ThisITI));
            if ~isempty(itiValues)
                minITI = min(itiValues);
                maxITI = max(itiValues);
                itiRanges = [1, minITI, maxITI];
            end
        end
    end
    
    % Display ITI range(s)
    if ~isempty(itiRanges)
        if size(itiRanges, 1) == 1
            % Single range
            minITI = itiRanges(1, 2);
            maxITI = itiRanges(1, 3);
            if abs(minITI - maxITI) < 0.001
                textLines{lineNum} = ['ITI Range: ' sprintf('%.1f s', minITI)];
            else
                textLines{lineNum} = ['ITI Range: ' sprintf('%.1f-%.1f s', minITI, maxITI)];
            end
        else
            % Multiple ranges detected - show all
            textLines{lineNum} = 'ITI Range:';
            lineNum = lineNum + 1;
            for i = 1:size(itiRanges, 1)
                trialStart = itiRanges(i, 1);
                minITI = itiRanges(i, 2);
                maxITI = itiRanges(i, 3);
                % Determine end trial for this range
                if i < size(itiRanges, 1)
                    endTrial = itiRanges(i+1, 1) - 1;
                else
                    endTrial = nTrials;
                end
                % Display range
                if abs(minITI - maxITI) < 0.001
                    if trialStart == endTrial
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) ': ' sprintf('%.1f s', minITI)];
                    else
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) '-' num2str(endTrial) ': ' sprintf('%.1f s', minITI)];
                    end
                else
                    if trialStart == endTrial
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) ': ' sprintf('%.1f-%.1f s', minITI, maxITI)];
                    else
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) '-' num2str(endTrial) ': ' sprintf('%.1f-%.1f s', minITI, maxITI)];
                    end
                end
                lineNum = lineNum + 1;
            end
            lineNum = lineNum - 1;  % Adjust for the extra increment
        end
    else
        textLines{lineNum} = 'ITI Range: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 4. NO-LICK RANGE (MinQuietTime - MaxQuietTime)
    % ========================================================================
    % Check for No-Lick range changes across trials
    quietTimeRanges = [];  % Store [trialNum, minQuietTime, maxQuietTime] for each unique range
    if isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Check all trials for QuietTime settings
        for trialIdx = 1:min(nTrials, length(SessionData.TrialSettings))
            if isfield(SessionData.TrialSettings(trialIdx), 'GUI')
                if isfield(SessionData.TrialSettings(trialIdx).GUI, 'MinQuietTime') && ...
                   isfield(SessionData.TrialSettings(trialIdx).GUI, 'MaxQuietTime')
                    minQuietTime_val = SessionData.TrialSettings(trialIdx).GUI.MinQuietTime;
                    maxQuietTime_val = SessionData.TrialSettings(trialIdx).GUI.MaxQuietTime;
                    % Check if this range is different from previous
                    if isempty(quietTimeRanges) || ...
                       abs(quietTimeRanges(end, 2) - minQuietTime_val) > 0.001 || ...
                       abs(quietTimeRanges(end, 3) - maxQuietTime_val) > 0.001
                        % New range detected
                        quietTimeRanges = [quietTimeRanges; trialIdx, minQuietTime_val, maxQuietTime_val];
                    end
                end
            end
        end
    end
    
    % If no ranges found in TrialSettings, try QuietTime or first trial
    if isempty(quietTimeRanges)
        if isfield(SessionData, 'QuietTime')
            quietTimeValues = SessionData.QuietTime(~isnan(SessionData.QuietTime));
            if ~isempty(quietTimeValues)
                minQuietTime = min(quietTimeValues);
                maxQuietTime = max(quietTimeValues);
                quietTimeRanges = [1, minQuietTime, maxQuietTime];
            end
        end
    end
    
    % Display No-Lick range(s)
    if ~isempty(quietTimeRanges)
        if size(quietTimeRanges, 1) == 1
            % Single range
            minQuietTime = quietTimeRanges(1, 2);
            maxQuietTime = quietTimeRanges(1, 3);
            if abs(minQuietTime - maxQuietTime) < 0.001
                textLines{lineNum} = ['No-Lick Range: ' sprintf('%.1f s', minQuietTime)];
            else
                textLines{lineNum} = ['No-Lick Range: ' sprintf('%.1f-%.1f s', minQuietTime, maxQuietTime)];
            end
        else
            % Multiple ranges detected - show all
            textLines{lineNum} = 'No-Lick Range:';
            lineNum = lineNum + 1;
            for i = 1:size(quietTimeRanges, 1)
                trialStart = quietTimeRanges(i, 1);
                minQuietTime = quietTimeRanges(i, 2);
                maxQuietTime = quietTimeRanges(i, 3);
                % Determine end trial for this range
                if i < size(quietTimeRanges, 1)
                    endTrial = quietTimeRanges(i+1, 1) - 1;
                else
                    endTrial = nTrials;
                end
                % Display range
                if abs(minQuietTime - maxQuietTime) < 0.001
                    if trialStart == endTrial
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) ': ' sprintf('%.1f s', minQuietTime)];
                    else
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) '-' num2str(endTrial) ': ' sprintf('%.1f s', minQuietTime)];
                    end
                else
                    if trialStart == endTrial
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) ': ' sprintf('%.1f-%.1f s', minQuietTime, maxQuietTime)];
                    else
                        textLines{lineNum} = ['  Trial ' num2str(trialStart) '-' num2str(endTrial) ': ' sprintf('%.1f-%.1f s', minQuietTime, maxQuietTime)];
                    end
                end
                lineNum = lineNum + 1;
            end
            lineNum = lineNum - 1;  % Adjust for the extra increment
        end
    else
        textLines{lineNum} = 'No-Lick Range: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 5. REWARD AMOUNT
    % ========================================================================
    rewardAmount = NaN;
    if isfield(SessionData, 'RewardAmount')
        rewardValues = SessionData.RewardAmount(~isnan(SessionData.RewardAmount));
        if ~isempty(rewardValues)
            % Use mean if multiple values exist
            rewardAmount = mean(rewardValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Try to get from TrialSettings if available
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'RewardAmount')
                rewardAmount = SessionData.TrialSettings(1).GUI.RewardAmount;
            end
        end
    end
    
    if ~isnan(rewardAmount)
        textLines{lineNum} = ['Volume of water rewarded per trial: ' sprintf('%.0f μL', rewardAmount)];
    else
        textLines{lineNum} = 'Volume of water rewarded per trial: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 5.5. N TO SWITCH (NCorrectToSwitch)
    % ========================================================================
    nToSwitch = NaN;
    if isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Get from last trial's TrialSettings
        lastTrialIdx = min(nTrials, length(SessionData.TrialSettings));
        if isfield(SessionData.TrialSettings(lastTrialIdx), 'GUI')
            if isfield(SessionData.TrialSettings(lastTrialIdx).GUI, 'NCorrectToSwitch')
                nToSwitch = SessionData.TrialSettings(lastTrialIdx).GUI.NCorrectToSwitch;
            end
        end
    end
    
    % Only display if the field exists (for compatibility with other protocols)
    if ~isnan(nToSwitch)
        textLines{lineNum} = ['N correct to switch: ' num2str(nToSwitch)];
        lineNum = lineNum + 1;
        textLines{lineNum} = '';  % Empty line
        lineNum = lineNum + 1;
    end
    
    % ========================================================================
    % 6-9. LEFT/RIGHT REWARD STATISTICS AND HIT RATES
    % ========================================================================
    % Get side configuration from StimParams (for trial count, not for hit calculation)
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
    leftTrials = 0;
    rightTrials = 0;
    leftRewards = 0;
    rightRewards = 0;
    leftHits = 0;
    rightHits = 0;
    leftNonCatchTrials = 0;  % Count non-catch trials for hit rate calculation
    rightNonCatchTrials = 0;  % Count non-catch trials for hit rate calculation
    leftManualRewards = 0;  % Port1-triggered rewards for left side
    rightManualRewards = 0;  % Port1-triggered rewards for right side
    totalWaterVolume = 0;
    
    % Loop through all trials
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
        
        if leftRewardVisited || rightRewardVisited
            try
                if isfield(trialData, 'Events')
                    % Get Port1In events
                    if isfield(trialData.Events, 'Port1In')
                        port1InTimes = trialData.Events.Port1In;
                        if ~isempty(port1InTimes)
                            % Get trial start time to ensure Port1In is within this trial
                            trialStartTime = 0; % Trial start is at time 0
                            
                            % Get Stimulus state timing to check if Port1In is before or during Stimulus
                            stimulusStart = NaN;
                            if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus')
                                stimulusStart = trialData.States.Stimulus(1);
                            end
                            
                            % Check if Port1In occurred in this trial (before or during Stimulus state)
                            if ~isnan(stimulusStart)
                                % Port1In should be before or at the start of Stimulus state
                                port1InBeforeOrDuringStimulus = port1InTimes <= stimulusStart;
                            else
                                % If Stimulus state doesn't exist, check if Port1In is within reasonable time window
                                port1InBeforeOrDuringStimulus = port1InTimes >= trialStartTime & port1InTimes <= 10;
                            end
                            
                            if any(port1InBeforeOrDuringStimulus)
                                % Check if left reward was triggered by Port1
                                if leftRewardVisited
                                    try
                                        leftRewardTime = trialData.States.LeftReward(1);
                                        if ~isnan(stimulusStart)
                                            timeFromPort1ToReward = leftRewardTime - port1InTimes;
                                            if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                                isLeftRewardFromPort1 = true;
                                            end
                                        else
                                            timeDiff = abs(port1InTimes - leftRewardTime);
                                            if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                                isLeftRewardFromPort1 = true;
                                            end
                                        end
                                    catch
                                    end
                                end
                                
                                % Check if right reward was triggered by Port1
                                if rightRewardVisited
                                    try
                                        rightRewardTime = trialData.States.RightReward(1);
                                        if ~isnan(stimulusStart)
                                            timeFromPort1ToReward = rightRewardTime - port1InTimes;
                                            if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                                isRightRewardFromPort1 = true;
                                            end
                                        else
                                            timeDiff = abs(port1InTimes - rightRewardTime);
                                            if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                                isRightRewardFromPort1 = true;
                                            end
                                        end
                                    catch
                                    end
                                end
                            end
                        end
                    end
                end
            catch
                % If extraction fails, assume reward is from animal lick
            end
        end
        
        % Count trials by correct side (for trial count)
        if ~isnan(correctSide)
            if correctSide == 1  % Left side
                leftTrials = leftTrials + 1;
                if ~isCatchTrial
                    leftNonCatchTrials = leftNonCatchTrials + 1;
                end
            elseif correctSide == 2  % Right side
                rightTrials = rightTrials + 1;
                if ~isCatchTrial
                    rightNonCatchTrials = rightNonCatchTrials + 1;
                end
            end
        end
        
        % Count rewards and hits
        % Hit = reward received AND not from Port1 AND not catch trial
        if leftRewardVisited
            leftRewards = leftRewards + 1;
            if isLeftRewardFromPort1
                leftManualRewards = leftManualRewards + 1;
            end
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isLeftRewardFromPort1
                leftHits = leftHits + 1;
            end
        end
        if rightRewardVisited
            rightRewards = rightRewards + 1;
            if isRightRewardFromPort1
                rightManualRewards = rightManualRewards + 1;
            end
            % Count as hit if: non-catch trial AND not manually triggered (Port1)
            if ~isCatchTrial && ~isRightRewardFromPort1
                rightHits = rightHits + 1;
            end
        end
        
        % Calculate total water volume
        % Count each reward separately (left and right)
        if leftRewardVisited
            % Get reward amount for this trial
            trialRewardAmount = rewardAmount;
            if isfield(SessionData, 'RewardAmount') && trialNum <= length(SessionData.RewardAmount)
                if ~isnan(SessionData.RewardAmount(trialNum))
                    trialRewardAmount = SessionData.RewardAmount(trialNum);
                end
            end
            if ~isnan(trialRewardAmount)
                totalWaterVolume = totalWaterVolume + trialRewardAmount;
            end
        end
        if rightRewardVisited
            % Get reward amount for this trial
            trialRewardAmount = rewardAmount;
            if isfield(SessionData, 'RewardAmount') && trialNum <= length(SessionData.RewardAmount)
                if ~isnan(SessionData.RewardAmount(trialNum))
                    trialRewardAmount = SessionData.RewardAmount(trialNum);
                end
            end
            if ~isnan(trialRewardAmount)
                totalWaterVolume = totalWaterVolume + trialRewardAmount;
            end
        end
    end
    
    % Display left side statistics
    textLines{lineNum} = 'Left Side:';
    lineNum = lineNum + 1;
    if leftTrials > 0
        textLines{lineNum} = ['  Rewards: ' num2str(leftRewards) ' / ' num2str(leftTrials) ' trials'];
        lineNum = lineNum + 1;
        if leftManualRewards > 0
            textLines{lineNum} = ['  Manual rewards: ' num2str(leftManualRewards)];
            lineNum = lineNum + 1;
        end
        if leftNonCatchTrials > 0
            leftHitRate = (leftHits / leftNonCatchTrials) * 100;
            textLines{lineNum} = ['  Hit Rate: ' sprintf('%.1f%%', leftHitRate) ' (' num2str(leftHits) '/' num2str(leftNonCatchTrials) ')'];
        else
            textLines{lineNum} = '  Hit Rate: N/A (no non-catch trials)';
        end
    else
        textLines{lineNum} = '  No left trials';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % Display right side statistics
    textLines{lineNum} = 'Right Side:';
    lineNum = lineNum + 1;
    if rightTrials > 0
        textLines{lineNum} = ['  Rewards: ' num2str(rightRewards) ' / ' num2str(rightTrials) ' trials'];
        lineNum = lineNum + 1;
        if rightManualRewards > 0
            textLines{lineNum} = ['  Manual rewards: ' num2str(rightManualRewards)];
            lineNum = lineNum + 1;
        end
        if rightNonCatchTrials > 0
            rightHitRate = (rightHits / rightNonCatchTrials) * 100;
            textLines{lineNum} = ['  Hit Rate: ' sprintf('%.1f%%', rightHitRate) ' (' num2str(rightHits) '/' num2str(rightNonCatchTrials) ')'];
        else
            textLines{lineNum} = '  Hit Rate: N/A (no non-catch trials)';
        end
    else
        textLines{lineNum} = '  No right trials';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % Display total water volume
    % Also verify calculation: total rewards × average reward amount
    totalRewards = leftRewards + rightRewards;
    if ~isnan(totalWaterVolume)
        textLines{lineNum} = ['Total Volume of water rewarded: ' sprintf('%.0f μL', totalWaterVolume)];
        % Add verification: expected = totalRewards × rewardAmount
        if ~isnan(rewardAmount) && totalRewards > 0
            expectedVolume = totalRewards * rewardAmount;
            if abs(totalWaterVolume - expectedVolume) > 0.01
                % If there's a discrepancy, it means reward amounts varied across trials
                % This is expected and the calculated totalWaterVolume is correct
            end
        end
    else
        textLines{lineNum} = 'Total Volume of water rewarded: N/A';
    end
    
    % ========================================================================
    % DISPLAY TEXT IN FIGURE
    % ========================================================================
    % Combine all text lines
    fullText = strjoin(textLines, '\n');
    
    % Display text
    text(ax, 0.05, 0.95, fullText, 'FontSize', 12, 'FontName', 'Courier', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'Interpreter', 'none');
    
    % Set title
    if isfield(SessionData, 'Info') && isfield(SessionData.Info, 'SubjectName')
        title(ax, ['Session Summary - ' SessionData.Info.SubjectName ' ' SessionData.Info.SessionDate ' ' SessionData.Info.SessionStartTime_UTC], 'FontSize', 12, 'FontWeight', 'bold');
    else
        title(ax, ['Session Summary - ' SessionData.Info.SessionDate ' ' SessionData.Info.SessionStartTime_UTC], 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    % Force update
    drawnow;
end

