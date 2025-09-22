% analyzer factory
classdef AnalyzerFactory
    methods (Static)
        function analyzers = createAnalyzers(config)
            % create analyzer collection based on configuration
            analyzers = struct();
            
            % real-time analyzer
            if isfield(config, 'AnalysisSettings') && isfield(config.AnalysisSettings, 'realTime') && config.AnalysisSettings.realTime.enabled
                analyzers.realTime = AnalyzerFactory.createRealTimeAnalyzers(config);
            end
            
            % post-analysis analyzer
            if isfield(config, 'AnalysisSettings') && isfield(config.AnalysisSettings, 'postHoc') && config.AnalysisSettings.postHoc.enabled
                analyzers.postHoc = AnalyzerFactory.createPostHocAnalyzers(config);
            end
        end
        
        function realTimeAnalyzers = createRealTimeAnalyzers(config)
            realTimeAnalyzers = struct();
            analysisTypes = config.AnalysisSettings.realTime.analysisTypes;
            
            for i = 1:length(analysisTypes)
                analyzer = AnalyzerFactory.createAnalyzer(analysisTypes{i}, config);
                realTimeAnalyzers.(analysisTypes{i}) = analyzer;
            end
        end
        
        function postHocAnalyzers = createPostHocAnalyzers(config)
            postHocAnalyzers = struct();
            analysisTypes = config.AnalysisSettings.postHoc.analysisTypes;
            
            for i = 1:length(analysisTypes)
                analyzer = AnalyzerFactory.createAnalyzer(analysisTypes{i}, config);
                postHocAnalyzers.(analysisTypes{i}) = analyzer;
            end
        end
        
        function analyzer = createAnalyzer(analyzerType, config)
            % Create specific analyzer based on type
            switch lower(analyzerType)
                case 'hit_rate'
                    analyzer = HitRateAnalyzer(config);
                case 'latency'
                    analyzer = LatencyAnalyzer(config);
                case 'performance'
                    analyzer = PerformanceAnalyzer(config);
                case 'reaction_time'
                    analyzer = LatencyAnalyzer(config); % Alias for latency
                case 'psychometric'
                    analyzer = HitRateAnalyzer(config); % Uses hit rate for psychometric analysis
                case 'chronometric'
                    analyzer = LatencyAnalyzer(config); % Alias for latency
                otherwise
                    error('Unknown analyzer type: %s', analyzerType);
            end
        end
    end
end