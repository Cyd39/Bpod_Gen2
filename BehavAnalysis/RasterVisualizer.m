% raster plot visualizer
classdef RasterVisualizer < handle
    properties
        Config
        FigureHandle
        AxesHandle
    end
    
    methods
        function obj = RasterVisualizer(config)
            obj.Config = config;
        end
        
        function createRasterPlot(obj, data, varargin)
            % Create raster plot similar to DataAnalysis/plotraster.m
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'ColorMap', 'turbo', @ischar);
            addParameter(p, 'MarkerSize', 8, @isnumeric);
            addParameter(p, 'LineWidth', 1.5, @isnumeric);
            addParameter(p, 'XLimit', [0, 2], @isnumeric);
            addParameter(p, 'Title', 'Raster Plot', @ischar);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [100, 100, 1200, 800]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Extract data
            if isfield(data, 'LickOnAfterStim')
                EventT = data.LickOnAfterStim;
            else
                error('Missing LickOnAfterStim data');
            end
            
            if isfield(data, 'AudIntensity')
                Var = data.AudIntensity;
            elseif isfield(data, 'Intensity')
                Var = data.Intensity;
            else
                error('Missing intensity data (AudIntensity or Intensity)');
            end
            
            % Get unique intensities and create color map
            uInt = unique(Var);
            nInt = length(uInt);
            
            if strcmp(p.Results.ColorMap, 'turbo')
                Colour = turbo(nInt);
            else
                Colour = colormap(p.Results.ColorMap, nInt);
            end
            
            % Check if we have valid data
            hasValidData = false;
            for i = 1:length(EventT)
                if ~isempty(EventT{i}) && ~all(isnan(EventT{i}))
                    hasValidData = true;
                    break;
                end
            end
            
            if ~hasValidData
                % No valid data - show message
                text(obj.AxesHandle, 0.5, 0.5, 'No valid lick data found', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 14, 'Color', 'red');
                title(obj.AxesHandle, [p.Results.Title ' - No Data']);
                return;
            end
            
            % Create raster plot
            [ax, YTick, YTickLab] = obj.plotRaster(obj.AxesHandle, EventT, Var, Colour, 10, 1, varargin{:});
            
            % Set properties (exactly like DataAnalysis)
            if ~isempty(YTick) && ~isempty(YTick{1})
                % Remove NaN values and ensure ascending order
                validYTick = YTick{1}(~isnan(YTick{1}));
                if ~isempty(validYTick)
                    validYTick = sort(validYTick);
                    ax.YTick = validYTick;
                    
                    % Match YTickLab to valid YTick
                    if ~isempty(YTickLab) && length(YTickLab) == length(YTick{1})
                        % Find which YTick values are valid
                        validIdx = ~isnan(YTick{1});
                        validYTickLab = YTickLab(validIdx);
                        ax.YTickLabel = arrayfun(@(x) sprintf('%.0f', x), validYTickLab, 'UniformOutput', false);
                    else
                        ax.YTickLabel = {};
                    end
                else
                    ax.YTick = [];
                    ax.YTickLabel = {};
                end
            else
                ax.YTick = [];
                ax.YTickLabel = {};
            end
            
            % Set axis limits
            xlim(ax, p.Results.XLimit);
            
            % Set Y-axis limits to show all trials
            if ~isempty(YTick) && ~isempty(YTick{end})
                yMin = min(YTick{end}) - 0.5;
                yMax = max(YTick{end}) + 0.5;
                ylim(ax, [yMin, yMax]);
            end
            
            xlabel(ax, 'Time (s)');
            ylabel(ax, 'Trial');
            title(ax, p.Results.Title);
            
            % Increase marker size for better visibility
            lineObjects = findobj(ax, 'Type', 'line');
            if ~isempty(lineObjects)
                set(lineObjects, 'MarkerSize', p.Results.MarkerSize);
                set(lineObjects, 'LineWidth', p.Results.LineWidth);
            end
            
            % Add legend for intensities only if we have data points
            if nInt > 1 && ~isempty(lineObjects)
                legendEntries = cell(nInt, 1);
                for i = 1:nInt
                    if isinf(uInt(i)) && uInt(i) < 0
                        legendEntries{i} = '-∞';
                    else
                        legendEntries{i} = sprintf('%.1f', uInt(i));
                    end
                end
                legend(ax, legendEntries, 'Location', 'best');
            end
        end
        
        function [ax, YTick, YTickLab, varargout] = plotRaster(obj, ax, EventT, Var, Colour, yinc, ticklevel, varargin)
            % Raster plot implementation (based on DataAnalysis/plotraster.m)
            
            NVar = size(Var, 2);
            NStim = size(Var, 1);
            UVar = unique(Var, 'rows');
            NUVar = size(UVar, 1);
            
            CVar = unique(Var(:,1));
            NColor = length(CVar);
            
            mksz = 1;
            
            if nargin < 5; yinc = flip(10.^[1:NVar]); end
            if isempty(yinc); yinc = flip(10.^[1:NVar]); end
            
            % Process varargin parameters
            for i = 1 : 2 : (length(varargin) - 1)
                if i+1 <= length(varargin) && ischar(varargin{i})
                    try
                        eval([char(varargin{i}),' = ', char(varargin{i+1}),';']);
                    catch
                        % Skip invalid parameter assignments
                        continue;
                    end
                end
            end
            
            %% Creating raster data
            [SortVar, idx] = sortrows(Var);
            if nargout > 3; varargout{1} = SortVar; end
            diffVar = SortVar(1:end-1,:) ~= SortVar(2:end,:);
            diffVar = [zeros(1,NVar); diffVar];
            if nargout > 4; varargout{2} = diffVar; end
            
            XX = []; YY = []; CC = [];
            
            Ycnt = 0;
            Ypos = nan(NStim, 1);
            
            for k = 1:NStim
                stimNum = idx(k);
                
                % get event times and append to XX
                X = EventT{stimNum, 1};
                if ~isempty(X) && ~all(isnan(X))
                    XX = [XX; X(:)];
                    
                    % calculate next position (exactly like DataAnalysis)
                    Ycnt = Ycnt + 1;
                    for v = 1:NVar  % add offset if stimulus is new
                        if (diffVar(k,v)); Ycnt = Ycnt + yinc(v); end
                    end
                    
                    % append y points to YY
                    Y = ones(size(X)) * Ycnt;
                    YY = [YY; Y(:)];
                    Ypos(stimNum) = Ycnt;
                    
                    % index for color
                    C = ones(size(X)) * find(CVar == Var(stimNum,1));
                    CC = [CC; C(:)];
                end
            end
            
            %% Plotting
            if (size(Colour,1) > 1) % plotting each color
                hold(ax, 'off');
                for k = 1:NColor
                    pColour = Colour(k,:);
                    sel = (CC == k);
                    if any(sel)
                        plot(ax, XX(sel), YY(sel), '.', 'MarkerFaceColor', pColour, ...
                            'MarkerEdgeColor', pColour, 'MarkerSize', mksz);
                        hold(ax, 'on');
                    end
                end
            else % plotting single color
                if isempty(Colour)
                    pColour = 'k';
                else
                    pColour = Colour;
                end
                plot(ax, XX, YY, '.', 'MarkerFaceColor', pColour, ...
                    'MarkerEdgeColor', pColour, 'MarkerSize', mksz);
            end
            
            %% Calculate YTicks at each level
            YTick = cell(NVar+1,1);
            YTickLim = cell(NVar,1);
            
            for v = 1:NVar
                tempUVar = unique(Var(:,1:v), 'rows');
                tempNUVar = size(tempUVar, 1);
                tempYTick = nan(tempNUVar, 1);
                tempYTickLim = nan(tempNUVar, 2);
                for k = 1:tempNUVar
                    sel = ones(NStim, 1);
                    for p = 1:v
                        sel = sel & Var(:,p) == tempUVar(k,p);
                    end
                    if any(sel)
                        % Use mean Y position for this group (exactly like DataAnalysis)
                        tempYTick(k) = mean(Ypos(sel));
                        tempYTickLim(k,1) = min(Ypos(sel));
                        tempYTickLim(k,2) = max(Ypos(sel));
                    end
                end
                YTick{v} = tempYTick;
                YTickLim{v} = tempYTickLim;
            end
            
            % Set YTickLab (exactly like DataAnalysis)
            if exist('tempUVar', 'var') && ~isempty(tempUVar) && ticklevel <= size(tempUVar, 2)
                YTickLab = tempUVar(:,ticklevel);
            else
                YTickLab = [];
            end
            
            % Set final YTick
            validYpos = Ypos(~isnan(Ypos));
            if ~isempty(validYpos)
                YTick{end} = sort(validYpos);
            else
                YTick{end} = [];
            end
            
            if nargout > 5; varargout{3} = YTickLim{end}; end
        end
        
        function createHistogramPlot(obj, data, varargin)
            % Create histogram plot similar to DataAnalysis/MainAnalysis.m
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'BinEdges', -5:0.05:2, @isnumeric);
            addParameter(p, 'Title', 'Lick On Times', @ischar);
            addParameter(p, 'XLabel', 'Time (s)', @ischar);
            addParameter(p, 'YLabel', 'Count', @ischar);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [200, 300, 1600, 400]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Extract all lick times
            allLickTimes = [];
            if isfield(data, 'LickOnAfterStim')
                for i = 1:length(data.LickOnAfterStim)
                    if ~isempty(data.LickOnAfterStim{i}) && ~all(isnan(data.LickOnAfterStim{i}))
                        validTimes = data.LickOnAfterStim{i}(~isnan(data.LickOnAfterStim{i}));
                        allLickTimes = [allLickTimes; validTimes(:)];
                    end
                end
            end
            
            % Check if we have valid data
            if isempty(allLickTimes)
                text(obj.AxesHandle, 0.5, 0.5, 'No valid lick data found', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 14, 'Color', 'red');
                title(obj.AxesHandle, [p.Results.Title ' - No Data']);
                return;
            end
            
            % Create histogram
            histogram(obj.AxesHandle, allLickTimes, p.Results.BinEdges);
            title(obj.AxesHandle, p.Results.Title);
            xlabel(obj.AxesHandle, p.Results.XLabel);
            ylabel(obj.AxesHandle, p.Results.YLabel);
            grid(obj.AxesHandle, 'on');
        end
        
        function createFirstLickHistogram(obj, data, varargin)
            % Create first lick histogram
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
            addParameter(p, 'BinEdges', 0:0.05:2, @isnumeric);
            addParameter(p, 'Title', 'First Lick On Times', @ischar);
            addParameter(p, 'XLabel', 'Time (s)', @ischar);
            addParameter(p, 'YLabel', 'Count', @ischar);
            parse(p, varargin{:});
            
            % Create figure if no parent specified
            if isempty(p.Results.Parent)
                obj.FigureHandle = figure('Position', [200, 300, 800, 400]);
                obj.AxesHandle = axes('Parent', obj.FigureHandle);
            else
                obj.AxesHandle = p.Results.Parent;
            end
            
            % Extract first lick times
            firstLickTimes = [];
            if isfield(data, 'FirstLickAfterStim')
                for i = 1:length(data.FirstLickAfterStim)
                    if ~isempty(data.FirstLickAfterStim{i}) && ~isnan(data.FirstLickAfterStim{i})
                        firstLickTimes = [firstLickTimes; data.FirstLickAfterStim{i}];
                    end
                end
            end
            
            % Check if we have valid data
            if isempty(firstLickTimes)
                text(obj.AxesHandle, 0.5, 0.5, 'No valid first lick data found', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 14, 'Color', 'red');
                title(obj.AxesHandle, [p.Results.Title ' - No Data']);
                return;
            end
            
            % Create histogram
            histogram(obj.AxesHandle, firstLickTimes, p.Results.BinEdges);
            title(obj.AxesHandle, p.Results.Title);
            xlabel(obj.AxesHandle, p.Results.XLabel);
            ylabel(obj.AxesHandle, p.Results.YLabel);
            grid(obj.AxesHandle, 'on');
        end
    end
end
