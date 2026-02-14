function PlotLickRasterSortedByFreq(SessionData)
    % PlotLickRasterSortedByFreq is similar to PlotLickRaster
    % This function operates in offline mode only and plots data 
    % sorted by frequency values.
   
    figureName = 'Lick Raster - Sorted by Frequency & Amplitude';  

    % Data check
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        return;
    end
    
    % Extract timestamps using ExtractTimeStamps
    try
        Session_tbl = ExtractTimeStamps(SessionData);
    catch ME
        warning(['Failed to extract timestamps: ' ME.message]);
        return;
    end
    
    % Check if Session_tbl is empty
    if isempty(Session_tbl) || height(Session_tbl) == 0
        warning('No trials completed.');
        return;
    end

    % Data sorting by frequency and amplitude
    if ismember('VibFreq', Session_tbl.Properties.VariableNames)
        sortColumns = {'VibFreq'};
        if ismember('VibAmp', Session_tbl.Properties.VariableNames)
            sortColumns = [sortColumns, {'VibAmp'}];
        end
        Session_tbl = sortrows(Session_tbl, sortColumns);
    end

    % Get all stimulus Freq&Amp combinations and index
    stimInfo = [];
    if all(ismember({'VibFreq', 'VibAmp'}, Session_tbl.Properties.VariableNames))
        [uniqueCombos, ~, comboIdx] = unique([Session_tbl.VibFreq, Session_tbl.VibAmp], 'rows', 'stable');
        nCombos = size(uniqueCombos, 1);
        
        % Calculate Y axis range for each combination
        comboYRanges = zeros(nCombos, 2);  % [startY, endY]
        for i = 1:nCombos
            trialIndices = find(comboIdx == i);
            comboYRanges(i, 1) = min(trialIndices);  % first trial for this Combo
            comboYRanges(i, 2) = max(trialIndices);  % last trial for this Combo
        end
        stimInfo = struct();
        stimInfo.uniqueCombos = uniqueCombos;
        stimInfo.comboIdx = comboIdx;
        stimInfo.comboYRanges = comboYRanges;
        stimInfo.nCombos = nCombos;
    end

    n_trial = height(Session_tbl);
    PlotLickRasterByFreq(Session_tbl, SessionData, n_trial, figureName, stimInfo);

    % file saving
    [file, path] = uiputfile('*.png', '保存为 PNG 图片', 'my_plot.png');

    % check if saving get canceled
    if isequal(file, 0) || isequal(path, 0)
        disp('用户取消了保存操作');
        return;
    end

    fullpath = fullfile(path, file);
    
    % ensure the file name ends with .png
    [~, ~, ext] = fileparts(fullpath);
    if isempty(ext)
        fullpath = [fullpath, '.png'];
    end
    
    exportgraphics(gcf, fullpath, 'Resolution', 300);
    fprintf('图片已保存为：%s\n', fullpath);
end

function PlotLickRasterByFreq(Session_tbl, SessionData, n_trial, figureName,  stimInfo)
    % full figure with multiple subplots (complete version from plotraster_behavior_v2)
    fig = figure('Position', [500, 300, 1200, 700]);
    clf(fig);
    
    % Add figure title
    sgtitle(fig, figureName, 'FontSize', 12, 'FontWeight', 'bold');
    
    t_min = 0;
    t_max = 0;
    
    % Get ResWin value for display
    ResWin = GetResWin(SessionData);
    
    % Handles for legend elements (shared across subplots)
    hResWin = [];
    
    % Subplot position configuration
    SUBPLOT1_POS = [0.05, 0.11, 0.38, 0.815];
    SUBPLOT2_POS = [0.5, 0.11, 0.35, 0.815];
    SUBPLOT3_POS = [0.95, 0.11, 0.05, 0.815];
    
    function applySubplotPositions(ax1, ax2, ax3)
        set(ax1, 'Position', SUBPLOT1_POS);
        set(ax2, 'Position', SUBPLOT2_POS);
        set(ax3, 'Position', SUBPLOT3_POS);
    end
    
    % Create subplots
    ax1 = subplot(1,3,1);
    ax2 = subplot(1,3,2);
    ax3 = subplot(1,3,3);
    
    applySubplotPositions(ax1, ax2, ax3);
    hold(ax1, 'on');
    hold(ax2, 'on');
    
    drawnow;
    
    % Flags to track if we've created legend handles
    leftLickLegendCreated = false;
    rightLickLegendCreated = false;
    rewardedLickLegendCreated = false;
    port1RewardLegendCreated = false;

    % Loop through data subplots
    for i_ax = 1:2
        if i_ax == 1
            ax = ax1;
        else
            ax = ax2;
        end
        
        for idx = 1:n_trial
            pos = idx;
            
            % Extract lick and reward data
            [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
             isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
                ExtractTrialData(Session_tbl, SessionData, idx);
            
            % Skip this trial if StimOnset is invalid
            if isnan(StimOnset)
                continue;
            end
            
            % Align to stimulus onset
            tempLeftLicks = tempLeftLicks - StimOnset;
            tempRightLicks = tempRightLicks - StimOnset;
            if ~isnan(tempLeftReward)
                tempLeftReward = tempLeftReward - StimOnset;
            end
            if ~isnan(tempRightReward)
                tempRightReward = tempRightReward - StimOnset;
            end
            trial_start = trial_start - StimOnset;
            t_min = min(t_min, trial_start);
            if ~isnan(trial_end)
                trial_end = trial_end - StimOnset;
                t_max = max(t_max, trial_end);
                plot(ax, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            else
                default_trial_end = trial_start + 5;
                t_max = max(t_max, default_trial_end);
                plot(ax, [trial_start, default_trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            end
            
            % Plot left licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempLeftLicks)
                if ~leftLickLegendCreated && i_ax == 1
                    plot(ax, tempLeftLicks(1), pos, '.', 'Color', [0.2 0.2 1], 'DisplayName', 'Left Lick');
                    leftLickLegendCreated = true;
                    if length(tempLeftLicks) > 1
                        plot(ax, tempLeftLicks(2:end), pos.*ones(size(tempLeftLicks(2:end))), '.', 'Color', [0.2 0.2 1]);
                    end
                else
                    plot(ax, tempLeftLicks, pos.*ones(size(tempLeftLicks)), '.', 'Color', [0.2 0.2 1]);
                end
            end
            
            % Plot right licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempRightLicks)
                if ~rightLickLegendCreated && i_ax == 1
                    plot(ax, tempRightLicks(1), pos, '.', 'Color', [1 0.2 0.2], 'DisplayName', 'Right Lick');
                    rightLickLegendCreated = true;
                    if length(tempRightLicks) > 1
                        plot(ax, tempRightLicks(2:end), pos.*ones(size(tempRightLicks(2:end))), '.', 'Color', [1 0.2 0.2]);
                    end
                else
                    plot(ax, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
                end
            end
            
            isRewarded = false;
            % Plot reward markers
            if ~isnan(tempLeftReward)
                isRewarded = true;
                if isLeftRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
                    end
                end
            end
            
            if ~isnan(tempRightReward)
                isRewarded = true;
                if isRightRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
                    end
                end
            end


            % Plot incorrect markers(first lick in unrewarded trial)
            % Get first licks after Stimulus Onset（or return NAN）
            minLeftTime = min([tempLeftLicks(tempLeftLicks > 0 & tempLeftLicks < ResWin), Inf]);
            minRightTime = min([tempRightLicks(tempRightLicks > 0 & tempRightLicks < ResWin), Inf]);
            if ~isRewarded
                [earliestTime, lickSide] = min([minLeftTime, minRightTime]);
                if isfinite(earliestTime)

                    if lickSide == 1               % left lick first
                        lickColor = [0.2 0.2 1];    % blue
                    else                            % right lick first
                        lickColor = [1 0.2 0.2];    % red
                    end
                    
                    % marker "x"
                    plot(ax, earliestTime, pos, 'x', 'Color', lickColor, ...
                        'MarkerSize', 8, 'LineWidth', 1.5);
                end
            end
        end
        
        % Set labels for each subplot
        ylabel(ax, 'Trial number');
        xlabel(ax, 'Time re stim. onset (s)');
        ylim(ax, [0.2, n_trial + 0.8]);
        
        % Plot ResWin lines in both subplots
        if ~isnan(ResWin)
            xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            if i_ax == 1
                hResWin = plot(ax, [NaN NaN], [NaN NaN], '--', 'Color', [0 0.5 0], 'LineWidth', 1.5, ...
                    'DisplayName', 'ResWindow');
            end
        end
        
        switch i_ax
            case 1
                if isnan(t_min) || isnan(t_max) || t_min >= t_max
                    xlim(ax, [-1, 5]);
                else
                    xlim(ax, [t_min-0.1, t_max+0.1]);
                end
            case 2
                if ~isnan(ResWin)
                    xlim(ax, [-.55, ResWin + 0.5]);
                else
                    if isnan(t_min) || isnan(t_max) || t_min >= t_max
                        xlim(ax, [-.55, 1]);
                    else
                        xlim(ax, [-.55, min(t_max+0.5, 5)]);
                    end
                end
        end
    end
    
    % Re-apply positions after data plotting
    applySubplotPositions(ax1, ax2, ax3);
    
    % Add stimulus labels after xlim is set so divider lines span correct range
    if nargin >= 5 && ~isempty(stimInfo) && isfield(stimInfo, 'comboYRanges')
        addStimulusLabelsToAxes(ax1, stimInfo);
        addStimulusLabelsToAxes(ax2, stimInfo);
    end
    
    % Re-apply labels
    ylabel(ax1, 'Trial number');
    xlabel(ax1, 'Time re stim. onset (s)');
    ylabel(ax2, 'Trial number');
    xlabel(ax2, 'Time re stim. onset (s)');
    
    % Use the third subplot for legend display
    axis(ax3, 'off');
    hold(ax3, 'on');
    legendHandles = [];
    legendLabels = {};
    
    % Create dummy objects for legend
    hLeftDummy = plot(ax3, NaN, NaN, '.', 'Color', [0.2 0.2 1], 'MarkerSize', 10);
    legendHandles = [legendHandles, hLeftDummy];
    legendLabels{end+1} = 'Left Lick';
    
    hRightDummy = plot(ax3, NaN, NaN, '.', 'Color', [1 0.2 0.2], 'MarkerSize', 10);
    legendHandles = [legendHandles, hRightDummy];
    legendLabels{end+1} = 'Right Lick';
    
    hRewardedDummy = plot(ax3, NaN, NaN, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hRewardedDummy];
    legendLabels{end+1} = 'Rewarded lick';
    
    hPort1RewardDummy = plot(ax3, NaN, NaN, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hPort1RewardDummy];
    legendLabels{end+1} = 'Manual reward';

    hIncorrectLickDummy = plot(ax3, NaN, NaN, 'x', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hIncorrectLickDummy];
    legendLabels{end+1} = 'Incorrect first lick';
    
    if ~isempty(hResWin) && ~isnan(ResWin)
        hResWinDummy = plot(ax3, NaN, NaN, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
        legendHandles = [legendHandles, hResWinDummy];
        legendLabels{end+1} = ['ResWindow = ' sprintf('%.2f', ResWin) ' s'];
    end
    
    % Create legend
    if ~isempty(legendHandles)
        legend(ax3, legendHandles, legendLabels, 'Location', 'north', 'Box', 'off');
    end
    
    % Final position check and fix
    applySubplotPositions(ax1, ax2, ax3);
    ylabel(ax1, 'Trial number');
    xlabel(ax1, 'Time re stim. onset (s)');
    ylabel(ax2, 'Trial number');
    xlabel(ax2, 'Time re stim. onset (s)');
    drawnow;
end

function addStimulusLabelsToAxes(ax, stimInfo)
    % Add divider lines and frequency/amplitude labels for each stimulus combo.
    
    amp_to_dis = 50.5; % amp: 0-1 displacement = amp_to_dis * amp

    if ~isfield(stimInfo, 'nCombos') || ~isfield(stimInfo, 'comboYRanges') || ~isfield(stimInfo, 'uniqueCombos')
        warning('stimInfo missing required fields, skipping stimulus labels.');
        return;
    end

    xl = xlim(ax);
    newXLeft = xl(1);  % extend left for label area if needed
    xlim(ax, [newXLeft, xl(2)]);

    hold(ax, 'on');

    for i = 1:stimInfo.nCombos
        startY = stimInfo.comboYRanges(i, 1);
        endY = stimInfo.comboYRanges(i, 2);

        if i > 1
            prevEndY = stimInfo.comboYRanges(i-1, 2);
            dividerY = (prevEndY + startY) / 2;
            plot(ax, [newXLeft, xl(2)], [dividerY, dividerY], ...
                '-', 'Color', [0.6 0.2 0.2], 'LineWidth', 1.5);
        end

        midY = (startY + endY) / 2;
        freq = stimInfo.uniqueCombos(i, 1);
        amp = stimInfo.uniqueCombos(i, 2);

        if freq == 0
            labelText = 'Catch trial';  
        else
            labelText = sprintf('%.0fHz\n%.2fμm', freq, amp*amp_to_dis);
        end

        text(ax, newXLeft + 0.2, midY, labelText, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 8, ...
            'FontWeight', 'bold', ...
            'Color', [0.2 0.2 0.5]);
    end

    hold(ax, 'off');
end

function ResWin = GetResWin(SessionData)
    % Helper function to extract ResWin value from SessionData
    ResWin = NaN;
    if isfield(SessionData, 'ResWin')
        ResWinData = SessionData.ResWin;
        if isstruct(ResWinData)
            ResWinValues = [];
            for i = 1:length(ResWinData)
                structFields = fieldnames(ResWinData(i));
                if ~isempty(structFields)
                    for j = 1:length(structFields)
                        fieldValue = ResWinData(i).(structFields{j});
                        if isnumeric(fieldValue) && isscalar(fieldValue) && ~isnan(fieldValue)
                            ResWinValues = [ResWinValues, fieldValue];
                            break;
                        elseif isstruct(fieldValue)
                            nestedFields = fieldnames(fieldValue);
                            if ~isempty(nestedFields)
                                nestedValue = fieldValue.(nestedFields{1});
                                if isnumeric(nestedValue) && isscalar(nestedValue) && ~isnan(nestedValue)
                                    ResWinValues = [ResWinValues, nestedValue];
                                    break;
                                end
                            end
                        end
                    end
                end
            end
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        elseif isnumeric(ResWinData)
            ResWinValues = ResWinData(~isnan(ResWinData));
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        lastTrial = length(SessionData.TrialSettings);
        if isfield(SessionData.TrialSettings(lastTrial), 'GUI') && ...
           isfield(SessionData.TrialSettings(lastTrial).GUI, 'ResWin')
            ResWin = SessionData.TrialSettings(lastTrial).GUI.ResWin;
        end
    end
end

function [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
          isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
    ExtractTrialData(Session_tbl, SessionData, idx)
    % Helper function to extract trial data
    
    % Handle both cell array and numeric array cases
    if iscell(Session_tbl.LeftLickOn)
        tempLeftLicks = Session_tbl.LeftLickOn{idx};
    else
        tempLeftLicks = Session_tbl.LeftLickOn(idx);
    end
    if iscell(Session_tbl.RightLickOn)
        tempRightLicks = Session_tbl.RightLickOn{idx};
    else
        tempRightLicks = Session_tbl.RightLickOn(idx);
    end
    
    % Convert scalar NaN to empty array
    if isscalar(tempLeftLicks) && isnan(tempLeftLicks)
        tempLeftLicks = [];
    end
    if isscalar(tempRightLicks) && isnan(tempRightLicks)
        tempRightLicks = [];
    end
    
    try
        tempLeftReward = Session_tbl.LeftReward(idx,1);
    catch
        tempLeftReward = NaN;
    end
    
    try
        tempRightReward = Session_tbl.RightReward(idx,1);
    catch
        tempRightReward = NaN;
    end
    
    % Check if reward was triggered by Port1 click
    isLeftRewardFromPort1 = false;
    isRightRewardFromPort1 = false;
    
    try
        if isfield(SessionData, 'RawEvents') && isfield(SessionData.RawEvents, 'Trial') && ...
           idx <= length(SessionData.RawEvents.Trial) && ...
           isfield(SessionData.RawEvents.Trial{idx}, 'Events')
            
            if isfield(SessionData.RawEvents.Trial{idx}.Events, 'Port1In')
                port1InTimes = SessionData.RawEvents.Trial{idx}.Events.Port1In;
                if ~isempty(port1InTimes)
                    trialStartTime = 0;
                    stimulusStart = NaN;
                    if isfield(SessionData.RawEvents.Trial{idx}, 'States') && ...
                       isfield(SessionData.RawEvents.Trial{idx}.States, 'Stimulus')
                        stimulusStart = SessionData.RawEvents.Trial{idx}.States.Stimulus(1);
                    end
                    
                    if ~isnan(stimulusStart)
                        port1InBeforeOrDuringStimulus = port1InTimes <= stimulusStart;
                    else
                        port1InBeforeOrDuringStimulus = port1InTimes >= trialStartTime & port1InTimes <= 10;
                    end
                    
                    if any(port1InBeforeOrDuringStimulus)
                        if ~isnan(tempLeftReward)
                            try
                                leftRewardAbsTime = Session_tbl.LeftReward(idx,1);
                                if ~isnan(stimulusStart)
                                    timeFromPort1ToReward = leftRewardAbsTime - port1InTimes;
                                    if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                        isLeftRewardFromPort1 = true;
                                    end
                                else
                                    timeDiff = abs(port1InTimes - leftRewardAbsTime);
                                    if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                        isLeftRewardFromPort1 = true;
                                    end
                                end
                            catch
                            end
                        end
                        
                        if ~isnan(tempRightReward)
                            try
                                rightRewardAbsTime = Session_tbl.RightReward(idx,1);
                                if ~isnan(stimulusStart)
                                    timeFromPort1ToReward = rightRewardAbsTime - port1InTimes;
                                    if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                        isRightRewardFromPort1 = true;
                                    end
                                else
                                    timeDiff = abs(port1InTimes - rightRewardAbsTime);
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
    end
    
    trial_start = 0;
    try
        trial_end = Session_tbl.WaitToFinish(idx,2);
    catch
        trial_end = NaN;
    end
    
    % Get stimulus onset
    try
        if iscell(Session_tbl.Stimulus)
            StimOnset = Session_tbl.Stimulus{idx}(1);
        else
            StimOnset = Session_tbl.Stimulus(idx,1);
        end
    catch
        StimOnset = NaN;
    end
end