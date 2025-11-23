function PlotCDFHitRate(SessionData, varargin)
    % PlotCDFHitRate - Plot CDF histogram of reaction time for hits in response window
    % 
    % This function plots the cumulative distribution function (CDF) of reaction times
    % for hits within the response window. X-axis represents reaction time (0 to ResWin),
    % Y-axis represents cumulative proportion of hits.
    %
    % Input:
    %   SessionData - Bpod session data structure
    %   varargin - Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'CDF of Hit Rate')
    %
    % Output:
    %   None
    %
    % Usage:
    %   Online mode: PlotCDFHitRate(SessionData, 'FigureHandle', customPlotFig, 'Axes', cdfAx);
    %   Offline mode: PlotCDFHitRate(SessionData);

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'CDF of Hit Rate', @ischar);
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
        figure('Name', figureName, 'Position', [100 100 1000 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
    end
    
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
    
    % Extract trial information
    isCatchTrial = SessionData.IsCatchTrial(:);
    correctSide = SessionData.CorrectSide(:);
    
    % Get maximum ResWin for x-axis range
    if isfield(SessionData, 'ResWin')
        maxResWin = max(SessionData.ResWin);
    else
        maxResWin = 1; % Default if ResWin not available
    end
    
    % Collect reaction times for hits in each condition
    % Store reaction time for each trial (NaN if no hit)
    leftReactionTimes = NaN(nTrials, 1);
    rightReactionTimes = NaN(nTrials, 1);
    catchReactionTimes = NaN(nTrials, 1); % For catch trials, track false alarm reaction times
    
    % Count total trials for each condition
    nLeftTrials = 0;
    nRightTrials = 0;
    nCatchTrials = 0;
    
    % Process each trial to collect reaction times for hits
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Get response window duration for this trial
        if isfield(SessionData, 'ResWin') && length(SessionData.ResWin) >= trialNum
            ResWin = SessionData.ResWin(trialNum);
        else
            ResWin = 1; % Default response window
        end
        
        % Get stimulus start time
        if ~isfield(trialData, 'States') || ~isfield(trialData.States, 'Stimulus') || isempty(trialData.States.Stimulus)
            continue; % Skip trials without stimulus state
        end
        stimulusStart = trialData.States.Stimulus(1);
        responseWindowEnd = stimulusStart + ResWin;
        
        % Check if reward was received
        rewarded = false;
        if isfield(trialData, 'States')
            if isfield(trialData.States, 'LeftReward') && ~isnan(trialData.States.LeftReward(1))
                rewarded = true;
            elseif isfield(trialData.States, 'RightReward') && ~isnan(trialData.States.RightReward(1))
                rewarded = true;
            end
        end
        
        % Check if reward was triggered by Condition6 (Port1 click)
        isCondition6 = false;
        if isfield(trialData, 'Events') && isfield(trialData.Events, 'Condition6')
            isCondition6 = true;
        end
        
        % Find first lick time (BNC1High or BNC2High) in response window
        firstLickTime = NaN;
        if isfield(trialData, 'Events')
            if isCatchTrial(trialNum)
                % Count catch trial
                nCatchTrials = nCatchTrials + 1;
                
                % For catch trials, find first lick (false alarm)
                if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                    licksInWindow = trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd;
                    if any(licksInWindow)
                        firstLickTime = min(trialData.Events.BNC1High(licksInWindow));
                    end
                end
                if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                    licksInWindow = trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd;
                    if any(licksInWindow)
                        firstRightLickTime = min(trialData.Events.BNC2High(licksInWindow));
                        if isnan(firstLickTime) || firstRightLickTime < firstLickTime
                            firstLickTime = firstRightLickTime;
                        end
                    end
                end
            else
                % For non-catch trials, find first lick (BNC1High or BNC2High)
                if correctSide(trialNum) == 1  % Left side trial
                    nLeftTrials = nLeftTrials + 1;
                    if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                        licksInWindow = trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd;
                        if any(licksInWindow)
                            firstLickTime = min(trialData.Events.BNC1High(licksInWindow));
                        end
                    end
                elseif correctSide(trialNum) == 2  % Right side trial
                    nRightTrials = nRightTrials + 1;
                    if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                        licksInWindow = trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd;
                        if any(licksInWindow)
                            firstLickTime = min(trialData.Events.BNC2High(licksInWindow));
                        end
                    end
                end
            end
        end
        
        % Calculate reaction time and store if it's a hit
        if ~isnan(firstLickTime)
            reactionTime = firstLickTime - stimulusStart;
            
            if isCatchTrial(trialNum)
                % For catch trials, store false alarm reaction times
                if reactionTime >= 0 && reactionTime <= ResWin
                    catchReactionTimes(trialNum) = reactionTime;
                end
            else
                % For non-catch trials, only store if it's a hit (rewarded and not Condition6)
                if rewarded && ~isCondition6 && reactionTime >= 0 && reactionTime <= ResWin
                    if correctSide(trialNum) == 1  % Left side trial
                        leftReactionTimes(trialNum) = reactionTime;
                    elseif correctSide(trialNum) == 2  % Right side trial
                        rightReactionTimes(trialNum) = reactionTime;
                    end
                end
            end
        end
    end
    
    % Calculate CDF for each condition
    % Create time bins from 0 to maxResWin
    timeBins = linspace(0, maxResWin, 100); % 100 bins for smooth CDF
    
    % Calculate CDF for left hits (proportion of left trials that hit by time t)
    leftCDF = zeros(size(timeBins));
    if nLeftTrials > 0
        for i = 1:length(timeBins)
            % Count left trials that hit before or at timeBins(i)
            leftCDF(i) = sum(~isnan(leftReactionTimes) & leftReactionTimes <= timeBins(i)) / nLeftTrials;
        end
    end
    
    % Calculate CDF for right hits (proportion of right trials that hit by time t)
    rightCDF = zeros(size(timeBins));
    if nRightTrials > 0
        for i = 1:length(timeBins)
            % Count right trials that hit before or at timeBins(i)
            rightCDF(i) = sum(~isnan(rightReactionTimes) & rightReactionTimes <= timeBins(i)) / nRightTrials;
        end
    end
    
    % Calculate CDF for catch false alarms (proportion of catch trials that responded by time t)
    catchCDF = zeros(size(timeBins));
    if nCatchTrials > 0
        for i = 1:length(timeBins)
            % Count catch trials that responded before or at timeBins(i)
            catchCDF(i) = sum(~isnan(catchReactionTimes) & catchReactionTimes <= timeBins(i)) / nCatchTrials;
        end
    end
    
    % Plot CDF histogram
    axes(ax);
    cla(ax);
    hold(ax, 'on');
    
    % Plot CDF as step function (histogram style)
    if nLeftTrials > 0
        nLeftHits = sum(~isnan(leftReactionTimes));
        stairs(ax, timeBins, leftCDF, 'b-', 'LineWidth', 2, 'DisplayName', ['Left (hits=' num2str(nLeftHits) '/' num2str(nLeftTrials) ')']);
    end
    
    if nRightTrials > 0
        nRightHits = sum(~isnan(rightReactionTimes));
        stairs(ax, timeBins, rightCDF, 'r-', 'LineWidth', 2, 'DisplayName', ['Right (hits=' num2str(nRightHits) '/' num2str(nRightTrials) ')']);
    end
    
    if nCatchTrials > 0
        nCatchResponses = sum(~isnan(catchReactionTimes));
        stairs(ax, timeBins, catchCDF, 'g-', 'LineWidth', 2, 'DisplayName', ['Catch (responses=' num2str(nCatchResponses) '/' num2str(nCatchTrials) ')']);
    end
    
    % Formatting
    xlabel(ax, 'Reaction Time (seconds from stimulus start)', 'FontSize', 12);
    ylabel(ax, 'Cumulative Proportion of Hits', 'FontSize', 12);
    title(ax, 'CDF of Hit Reaction Times in Response Window', 'FontSize', 12);
    legend(ax, 'Location', 'northwest', 'FontSize', 10);
    grid(ax, 'on');
    ylim(ax, [0 1]);
    xlim(ax, [0 maxResWin]);
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end