function OnlineSessionSummary(customPlotFig, summaryAx, SessionData)
    % OnlineSessionSummary - Display session summary text in real-time
    % This function extracts session information from SessionData (all completed trials)
    % and displays it as text, similar to PlotSessionSummary but for online use
    % Inputs:
    %   customPlotFig - figure handle for the combined plot (optional, for activation)
    %   summaryAx - axes handle for the text display
    %   SessionData - session data structure (e.g., BpodSystem.Data)
    
    % Activate figure if provided
    if nargin >= 1 && ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Clear axes
    cla(summaryAx);
    axis(summaryAx, 'off');
    hold(summaryAx, 'on');
    
    % Check if data exists
    if ~isfield(SessionData, 'nTrials')
        text(summaryAx, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
        drawnow;
        return;
    end
    
    nTrials = SessionData.nTrials;
    
    % Initialize text lines array
    textLines = {};
    lineNum = 1;
    
    % ========================================================================
    % 1. SESSION CATEGORY/TYPE
    % ========================================================================
    sessionType = 'Unknown';
    if isfield(SessionData, 'StimParams') && isfield(SessionData.StimParams, 'Session') && ...
       isfield(SessionData.StimParams.Session, 'TypeName')
        sessionType = SessionData.StimParams.Session.TypeName;
    end
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
    % 3. ITI RANGE (simplified for online display)
    % ========================================================================
    minITI = NaN;
    maxITI = NaN;
    if isfield(SessionData, 'ThisITI')
        itiValues = SessionData.ThisITI(~isnan(SessionData.ThisITI));
        if ~isempty(itiValues)
            minITI = min(itiValues);
            maxITI = max(itiValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'MinITI') && ...
               isfield(SessionData.TrialSettings(1).GUI, 'MaxITI')
                minITI = SessionData.TrialSettings(1).GUI.MinITI;
                maxITI = SessionData.TrialSettings(1).GUI.MaxITI;
            end
        end
    end
    
    if ~isnan(minITI) && ~isnan(maxITI)
        if abs(minITI - maxITI) < 0.001
            textLines{lineNum} = ['ITI Range: ' sprintf('%.1f s', minITI)];
        else
            textLines{lineNum} = ['ITI Range: ' sprintf('%.1f-%.1f s', minITI, maxITI)];
        end
    else
        textLines{lineNum} = 'ITI Range: N/A';
    end
    lineNum = lineNum + 1;
    textLines{lineNum} = '';  % Empty line
    lineNum = lineNum + 1;
    
    % ========================================================================
    % 4. NO-LICK RANGE (simplified for online display)
    % ========================================================================
    minQuietTime = NaN;
    maxQuietTime = NaN;
    if isfield(SessionData, 'QuietTime')
        quietTimeValues = SessionData.QuietTime(~isnan(SessionData.QuietTime));
        if ~isempty(quietTimeValues)
            minQuietTime = min(quietTimeValues);
            maxQuietTime = max(quietTimeValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'MinQuietTime') && ...
               isfield(SessionData.TrialSettings(1).GUI, 'MaxQuietTime')
                minQuietTime = SessionData.TrialSettings(1).GUI.MinQuietTime;
                maxQuietTime = SessionData.TrialSettings(1).GUI.MaxQuietTime;
            end
        end
    end
    
    if ~isnan(minQuietTime) && ~isnan(maxQuietTime)
        if abs(minQuietTime - maxQuietTime) < 0.001
            textLines{lineNum} = ['No-Lick Range: ' sprintf('%.1f s', minQuietTime)];
        else
            textLines{lineNum} = ['No-Lick Range: ' sprintf('%.1f-%.1f s', minQuietTime, maxQuietTime)];
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
            rewardAmount = mean(rewardValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'RewardAmount')
                rewardAmount = SessionData.TrialSettings(1).GUI.RewardAmount;
            end
        end
    end
    
    if ~isnan(rewardAmount)
        textLines{lineNum} = ['Water rewarded per trial: ' sprintf('%.0f μL', rewardAmount)];
    else
        textLines{lineNum} = 'Water rewarded per trial: N/A';
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
    % Initialize counters
    leftTrials = 0;
    rightTrials = 0;
    leftRewards = 0;
    rightRewards = 0;
    leftHits = 0;
    rightHits = 0;
    leftNonCatchTrials = 0;
    rightNonCatchTrials = 0;
    leftManualRewards = 0;  % Port1-triggered rewards for left side
    rightManualRewards = 0;  % Port1-triggered rewards for right side
    totalWaterVolume = 0;
    
    % Loop through all completed trials
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
        if isfield(SessionData, 'CorrectSide') && trialNum <= length(SessionData.CorrectSide)
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
        
        % Count rewards by actual reward received
        if leftRewardVisited
            leftRewards = leftRewards + 1;
            if isLeftRewardFromPort1
                leftManualRewards = leftManualRewards + 1;
            end
            if ~isCatchTrial && ~isnan(correctSide) && correctSide == 1
                leftHits = leftHits + 1;
            end
        end
        if rightRewardVisited
            rightRewards = rightRewards + 1;
            if isRightRewardFromPort1
                rightManualRewards = rightManualRewards + 1;
            end
            if ~isCatchTrial && ~isnan(correctSide) && correctSide == 2
                rightHits = rightHits + 1;
            end
        end
        
        % Calculate total water volume
        if leftRewardVisited
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
    if ~isnan(totalWaterVolume)
        textLines{lineNum} = ['Total Water Rewarded: ' sprintf('%.0f μL', totalWaterVolume)];
    else
        textLines{lineNum} = 'Total Water Rewarded: N/A';
    end
    
    % ========================================================================
    % DISPLAY TEXT IN FIGURE
    % ========================================================================
    % Combine all text lines
    fullText = strjoin(textLines, '\n');
    
    % Display text
    text(summaryAx, 0.05, 0.95, fullText, 'FontSize', 10, 'FontName', 'Courier', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'Interpreter', 'none', 'Units', 'normalized');
    
    % Set title
    if isfield(SessionData, 'Info') && isfield(SessionData.Info, 'SubjectName')
        title(summaryAx, ['Session Summary - ' SessionData.Info.SubjectName ' ' SessionData.Info.SessionDate ' ' SessionData.Info.SessionStartTime_UTC], 'FontSize', 12, 'FontWeight', 'bold');
    else
        title(summaryAx, ['Session Summary - ' SessionData.Info.SessionDate ' ' SessionData.Info.SessionStartTime_UTC], 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    % Force update
    drawnow;
end

