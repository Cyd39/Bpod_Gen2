% hit rate visualizer
classdef HitRateVisualizer < handle
    properties
        Config
        FigureHandle
        AxesHandle
    end
    
    methods
        function obj = HitRateVisualizer(config)
            obj.Config = config;
        end
        
        function createHitRatePlot(obj, hitRateTable, varargin)
            % Create hit rate plot similar to DataAnalysis/MainAnalysis.m
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'ShowSEM', true, @islogical);
            addParameter(p, 'ShowDataPoints', true, @islogical);
            addParameter(p, 'Title', 'Hit Rate vs Intensity', @ischar);
            addParameter(p, 'XLabel', 'Intensity', @ischar);
            addParameter(p, 'YLabel', 'Hit Rate (%)', @ischar);
            addParameter(p, 'YLim', [0, 100], @isnumeric);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [100, 100, 800, 600]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Check if -inf is present in intensities
            hasInf = any(isinf(hitRateTable.Intensity) & hitRateTable.Intensity < 0);
            
            if hasInf
                % Separate -inf from other intensities for plotting
                infMask = isinf(hitRateTable.Intensity) & hitRateTable.Intensity < 0;
                normalMask = ~infMask;
                
                % Create x-axis values with -inf positioned to the left
                xValues = hitRateTable.Intensity;
                if any(normalMask)
                    minNormalInt = min(hitRateTable.Intensity(normalMask));
                    xValues(infMask) = minNormalInt - 20; % Position -inf to the left
                end
                
                % Plot normal intensities first
                if any(normalMask)
                    if p.Results.ShowSEM && isfield(hitRateTable, 'SEM')
                        errorbar(obj.AxesHandle, xValues(normalMask), ...
                            hitRateTable.HitRate(normalMask) * 100, ...
                            hitRateTable.SEM(normalMask) * 100, ...
                            'o-', 'LineWidth', 2, 'MarkerSize', 8);
                    else
                        plot(obj.AxesHandle, xValues(normalMask), ...
                            hitRateTable.HitRate(normalMask) * 100, ...
                            'o-', 'LineWidth', 2, 'MarkerSize', 8);
                    end
                    hold(obj.AxesHandle, 'on');
                end
                
                % Plot -inf values
                if any(infMask)
                    if p.Results.ShowSEM && isfield(hitRateTable, 'SEM')
                        errorbar(obj.AxesHandle, xValues(infMask), ...
                            hitRateTable.HitRate(infMask) * 100, ...
                            hitRateTable.SEM(infMask) * 100, ...
                            's', 'LineWidth', 2, 'MarkerSize', 8, 'Color', 'red');
                    else
                        plot(obj.AxesHandle, xValues(infMask), ...
                            hitRateTable.HitRate(infMask) * 100, ...
                            's', 'LineWidth', 2, 'MarkerSize', 8, 'Color', 'red');
                    end
                end
                
                % Set x-axis limits
                xlim(obj.AxesHandle, [min(xValues)-5, max(xValues)+5]);
                
                % Create custom x-axis with break
                tickPositions = [xValues(infMask); xValues(normalMask)];
                obj.AxesHandle.XTick = tickPositions;
                
                % Set tick labels
                tickLabels = cell(length(tickPositions), 1);
                for i = 1:length(tickPositions)
                    if isinf(tickPositions(i)) && tickPositions(i) < 0
                        tickLabels{i} = '-∞';
                    else
                        tickLabels{i} = num2str(tickPositions(i));
                    end
                end
                obj.AxesHandle.XTickLabel = tickLabels;
                
                % Add break symbol on x-axis
                if any(normalMask)
                    xBreak = minNormalInt - 10;
                    yLim = ylim(obj.AxesHandle);
                    hold(obj.AxesHandle, 'on');
                    plot(obj.AxesHandle, [xBreak, xBreak], yLim, 'k--', 'LineWidth', 1);
                    text(obj.AxesHandle, xBreak, yLim(2), '//', ...
                        'HorizontalAlignment', 'center', 'FontSize', 12);
                end
                
            else
                % No -inf values, plot normally
                if p.Results.ShowSEM && isfield(hitRateTable, 'SEM')
                    errorbar(obj.AxesHandle, hitRateTable.Intensity, ...
                        hitRateTable.HitRate * 100, hitRateTable.SEM * 100, ...
                        'o-', 'LineWidth', 2, 'MarkerSize', 8);
                else
                    plot(obj.AxesHandle, hitRateTable.Intensity, ...
                        hitRateTable.HitRate * 100, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
                end
            end
            
            % Add data points as text labels
            if p.Results.ShowDataPoints
                for i = 1:height(hitRateTable)
                    if hasInf && infMask(i)
                        xPos = xValues(i);
                    else
                        xPos = hitRateTable.Intensity(i);
                    end
                    text(obj.AxesHandle, xPos, hitRateTable.HitRate(i) * 100 + 2, ...
                        sprintf('n=%d', hitRateTable.TotalTrials(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 8);
                end
            end
            
            % Set labels and title
            xlabel(obj.AxesHandle, p.Results.XLabel);
            ylabel(obj.AxesHandle, p.Results.YLabel);
            title(obj.AxesHandle, p.Results.Title);
            ylim(obj.AxesHandle, p.Results.YLim);
            grid(obj.AxesHandle, 'on');
            
            % Add legend if there are -inf values
            if hasInf
                legend(obj.AxesHandle, 'Stimulus', 'No Stimulus', 'Location', 'best');
            end
        end
        
        function createLatencyPlot(obj, latencyData, varargin)
            % Create latency plot by intensity
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'PlotType', 'boxplot', @(x) ismember(x, {'boxplot', 'scatter', 'mean'}));
            addParameter(p, 'Title', 'Latency by Intensity', @ischar);
            addParameter(p, 'XLabel', 'Intensity', @ischar);
            addParameter(p, 'YLabel', 'Latency (s)', @ischar);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [100, 100, 800, 600]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Prepare data for plotting
            allData = [];
            groupLabels = {};
            intensities = latencyData.intensities;
            
            for i = 1:length(intensities)
                data = latencyData.data{i};
                if ~isempty(data)
                    allData = [allData; data];
                    
                    % Create group labels
                    if isinf(intensities(i)) && intensities(i) < 0
                        intensityLabel = '-∞';
                    else
                        intensityLabel = sprintf('%.1f', intensities(i));
                    end
                    
                    % Add group labels for each data point
                    groupLabels = [groupLabels; repmat({intensityLabel}, length(data), 1)];
                end
            end
            
            if isempty(allData)
                text(obj.AxesHandle, 0.5, 0.5, 'No latency data available', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                return;
            end
            
            % Create plot based on type
            switch p.Results.PlotType
                case 'boxplot'
                    boxplot(obj.AxesHandle, allData, groupLabels);
                    hold(obj.AxesHandle, 'on');
                    
                    % Add individual data points
                    for i = 1:length(intensities)
                        data = latencyData.data{i};
                        if ~isempty(data)
                            x_pos = i + (rand(length(data), 1) - 0.5) * 0.3;
                            scatter(obj.AxesHandle, x_pos, data, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
                        end
                    end
                    
                case 'scatter'
                    % Create scatter plot with jitter
                    x_pos = [];
                    y_data = [];
                    for i = 1:length(intensities)
                        data = latencyData.data{i};
                        if ~isempty(data)
                            x_jitter = i + (rand(length(data), 1) - 0.5) * 0.4;
                            x_pos = [x_pos; x_jitter];
                            y_data = [y_data; data];
                        end
                    end
                    scatter(obj.AxesHandle, x_pos, y_data, 50, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
                    
                case 'mean'
                    % Plot means with error bars
                    means = [];
                    sems = [];
                    x_vals = [];
                    for i = 1:length(intensities)
                        data = latencyData.data{i};
                        if ~isempty(data)
                            means = [means; mean(data)];
                            sems = [sems; std(data) / sqrt(length(data))];
                            x_vals = [x_vals; intensities(i)];
                        end
                    end
                    errorbar(obj.AxesHandle, x_vals, means, sems, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
            end
            
            % Set labels and title
            xlabel(obj.AxesHandle, p.Results.XLabel);
            ylabel(obj.AxesHandle, p.Results.YLabel);
            title(obj.AxesHandle, p.Results.Title);
            grid(obj.AxesHandle, 'on');
        end
        
        function createMedianLatencyPlot(obj, latencyData, varargin)
            % Create median latency plot
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'Title', 'Median Response Latency vs Intensity', @ischar);
            addParameter(p, 'XLabel', 'Intensity', @ischar);
            addParameter(p, 'YLabel', 'Median Latency (s)', @ischar);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [100, 100, 800, 600]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Prepare data for median plot
            medianLatencies = [];
            intensityValues = [];
            intensityLabels = {};
            
            for i = 1:length(latencyData.intensities)
                data = latencyData.data{i};
                if ~isempty(data)
                    medianLatencies = [medianLatencies; median(data)];
                    intensityValues = [intensityValues; latencyData.intensities(i)];
                    
                    if isinf(latencyData.intensities(i)) && latencyData.intensities(i) < 0
                        intensityLabels{end+1} = '-∞';
                    else
                        intensityLabels{end+1} = sprintf('%.1f', latencyData.intensities(i));
                    end
                end
            end
            
            if isempty(medianLatencies)
                text(obj.AxesHandle, 0.5, 0.5, 'No latency data available', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                return;
            end
            
            % Handle -inf for plotting
            plotIntensities = intensityValues;
            if any(isinf(intensityValues) & intensityValues < 0)
                % Replace -inf with a negative value for plotting
                plotIntensities(isinf(intensityValues) & intensityValues < 0) = ...
                    min(intensityValues(~isinf(intensityValues))) - 10;
            end
            
            % Create the plot
            plot(obj.AxesHandle, plotIntensities, medianLatencies, 'o-', ...
                'LineWidth', 2, 'MarkerSize', 8);
            
            % Set x-axis with proper labels
            obj.AxesHandle.XTick = plotIntensities;
            obj.AxesHandle.XTickLabel = intensityLabels;
            
            % Add break symbol if there's -inf
            if any(isinf(intensityValues) & intensityValues < 0)
                xBreak = min(intensityValues(~isinf(intensityValues))) - 5;
                yLim = ylim(obj.AxesHandle);
                hold(obj.AxesHandle, 'on');
                plot(obj.AxesHandle, [xBreak, xBreak], yLim, 'k--', 'LineWidth', 1);
                text(obj.AxesHandle, xBreak, yLim(2), '//', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12);
            end
            
            % Set labels and title
            xlabel(obj.AxesHandle, p.Results.XLabel);
            ylabel(obj.AxesHandle, p.Results.YLabel);
            title(obj.AxesHandle, p.Results.Title);
            grid(obj.AxesHandle, 'on');
        end
    end
end
