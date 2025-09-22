% main analysis manager
classdef BehaviorAnalysisManager < handle
    properties
        Config              % configuration parameters
        DataLoader          % data loader
        Preprocessor        % data preprocessor
        Analyzers           % analyzer collection
        Visualizers         % visualizer collection
        ResultsManager      % result manager
    end
    
    methods
        function obj = BehaviorAnalysisManager(configPath)
            % initialize all components
            obj.initializeComponents(configPath);
        end
        
        function initializeComponents(obj, configPath)
            % load configuration
            obj.Config = AnalysisConfig(configPath);
            
            % initialize each module
            obj.DataLoader = DataLoader(obj.Config);
            obj.Preprocessor = DataPreprocessor(obj.Config);
            obj.Analyzers = AnalyzerFactory.createAnalyzers(obj.Config);
            obj.Visualizers = obj.createVisualizers();
            obj.ResultsManager = obj.createResultsManager();
        end
        
        function visualizers = createVisualizers(obj)
            % Create visualizer collection
            visualizers = struct();
            
            % Raster plot visualizer
            visualizers.raster = RasterVisualizer(obj.Config);
            
            % Hit rate visualizer
            visualizers.hitRate = HitRateVisualizer(obj.Config);
            
            % General figure manager
            visualizers.figureManager = obj.createFigureManager();
        end
        
        function figureManager = createFigureManager(obj)
            % Create figure manager for organizing plots
            figureManager = struct();
            figureManager.figures = {};
            figureManager.currentFigure = 1;
        end
        
        function resultsManager = createResultsManager(obj)
            % Create results manager
            resultsManager = struct();
            resultsManager.results = {};
            if isfield(obj.Config, 'OutputSettings') && isfield(obj.Config.OutputSettings, 'output_directory')
                resultsManager.outputPath = obj.Config.OutputSettings.output_directory;
            else
                resultsManager.outputPath = 'Analysis_Results';
            end
        end
        
        function runRealTimeAnalysis(obj, trialData)
            % real-time analysis (during experiment)
            processedData = obj.Preprocessor.processTrialData(trialData);
            
            % Run all real-time analyzers
            results = struct();
            if isfield(obj.Analyzers, 'realTime')
                analyzerNames = fieldnames(obj.Analyzers.realTime);
                for i = 1:length(analyzerNames)
                    analyzer = obj.Analyzers.realTime.(analyzerNames{i});
                    results.(analyzerNames{i}) = analyzer.analyze(processedData);
                end
            end
            
            % Update visualizations
            obj.updateRealTimeVisualizations(results);
            
            % Save results
            obj.saveResults(results, 'real_time');
        end
        
        function runPostAnalysis(obj, sessionPath)
            % post-analysis (after experiment) - equivalent to DataAnalysis/MainAnalysis.m
            fprintf('Starting post-analysis...\n');
            
            % Load data
            [SessionData, Session_tbl, filePath] = obj.DataLoader.loadSessionData(sessionPath);
            data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
            
            % Process data
            processedData = obj.Preprocessor.processSessionData(data);
            
            % Run all post-hoc analyzers
            results = struct();
            if isfield(obj.Analyzers, 'postHoc')
                analyzerNames = fieldnames(obj.Analyzers.postHoc);
                for i = 1:length(analyzerNames)
                    analyzer = obj.Analyzers.postHoc.(analyzerNames{i});
                    results.(analyzerNames{i}) = analyzer.analyze(processedData);
                end
            end
            
            % Create visualizations
            obj.createPostHocVisualizations(processedData, results);
            
            % Save results
            obj.saveResults(results, 'post_hoc');
            
            fprintf('Post-analysis completed.\n');
        end
        
        function updateRealTimeVisualizations(obj, results)
            % Update real-time visualizations
            % This would be implemented for real-time monitoring
            fprintf('Updating real-time visualizations...\n');
        end
        
        function createPostHocVisualizations(obj, processedData, results)
            % Create all post-hoc visualizations (equivalent to DataAnalysis/MainAnalysis.m)
            fprintf('Creating visualizations...\n');
            
            % Create main analysis figure
            obj.createMainAnalysisFigure(processedData, results);
            
            % Create individual plots
            obj.createHistogramPlots(processedData);
            obj.createRasterPlot(processedData);
            obj.createHitRatePlot(results);
            obj.createLatencyPlots(results);
        end
        
        function createMainAnalysisFigure(obj, processedData, results)
            % Create main analysis figure with multiple subplots
            fig = figure('Position', [200, 300, 1600, 400], 'Name', 'Behavior Analysis Results');
            
            % All licks histogram
            subplot(1, 2, 1);
            obj.Visualizers.raster.createHistogramPlot(processedData, 'Parent', gca, ...
                'Title', 'All Lick On Times', 'BinEdges', -5:0.05:2);
            
            % First lick histogram
            subplot(1, 2, 2);
            obj.Visualizers.raster.createFirstLickHistogram(processedData, 'Parent', gca, ...
                'Title', 'First Lick On Times', 'BinEdges', 0:0.05:2);
        end
        
        function createHistogramPlots(obj, processedData)
            % Create histogram plots
            obj.Visualizers.raster.createHistogramPlot(processedData, ...
                'Title', 'All Lick On Times');
            
            obj.Visualizers.raster.createFirstLickHistogram(processedData, ...
                'Title', 'First Lick On Times');
        end
        
        function createRasterPlot(obj, processedData)
            % Create raster plot
            obj.Visualizers.raster.createRasterPlot(processedData, ...
                'Title', 'Raster Plot - Lick Times by Intensity');
        end
        
        function createHitRatePlot(obj, results)
            % Create hit rate plot
            if isfield(results, 'hit_rate') && isfield(results.hit_rate, 'hitRateTable')
                obj.Visualizers.hitRate.createHitRatePlot(results.hit_rate.hitRateTable, ...
                    'Title', 'Hit Rate vs Intensity');
            end
        end
        
        function createLatencyPlots(obj, results)
            % Create latency plots
            if isfield(results, 'latency') && isfield(results.latency, 'latencyByIntensity')
                % Boxplot
                obj.Visualizers.hitRate.createLatencyPlot(results.latency.latencyByIntensity, ...
                    'PlotType', 'boxplot', 'Title', 'Latency by Intensity (Hit Trials Only)');
                
                % Median plot
                obj.Visualizers.hitRate.createMedianLatencyPlot(results.latency.latencyByIntensity, ...
                    'Title', 'Median Response Latency vs Intensity');
            end
        end
        
        function saveResults(obj, results, analysisType)
            % Save analysis results
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            filename = sprintf('analysis_results_%s_%s.mat', analysisType, timestamp);
            
            % Create output directory if it doesn't exist
            if isfield(obj.Config, 'OutputSettings') && isfield(obj.Config.OutputSettings, 'output_directory')
                outputDir = obj.Config.OutputSettings.output_directory;
            else
                outputDir = 'Analysis_Results';
            end
            
            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
            
            filepath = fullfile(outputDir, filename);
            save(filepath, 'results', 'analysisType', 'timestamp');
            
            fprintf('Results saved to: %s\n', filepath);
        end
        
        function runCompleteAnalysis(obj, sessionPath)
            % Run complete analysis equivalent to DataAnalysis/MainAnalysis.m
            fprintf('Running complete behavior analysis...\n');
            
            % Load and process data
            if nargin < 2 || isempty(sessionPath)
                % Use GUI data selection if no path provided
                [SessionData, Session_tbl, filePath] = obj.DataLoader.loadSessionData();
            else
                % Use provided path
                [SessionData, Session_tbl, filePath] = obj.DataLoader.loadSessionData(sessionPath);
            end
            data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
            processedData = obj.Preprocessor.processSessionData(data);
            
            % Run all analyses
            results = struct();
            
            % Hit rate analysis
            if isfield(obj.Analyzers, 'postHoc') && isfield(obj.Analyzers.postHoc, 'hit_rate')
                results.hit_rate = obj.Analyzers.postHoc.hit_rate.analyze(processedData);
            end
            
            % Latency analysis
            if isfield(obj.Analyzers, 'postHoc') && isfield(obj.Analyzers.postHoc, 'latency')
                results.latency = obj.Analyzers.postHoc.latency.analyze(processedData);
            end
            
            % Create all visualizations
            obj.createPostHocVisualizations(processedData, results);
            
            % Save results
            obj.saveResults(results, 'complete');
            
            fprintf('Complete analysis finished.\n');
        end
    end
end