% analyzer factory
classdef AnalyzerFactory
    methods (Static)
        function analyzers = createAnalyzers(config)
            % create analyzer collection based on configuration
            analyzers = struct();
            
            % real-time analyzer
            if config.RealTimeSettings.enabled
                analyzers.realTime = AnalyzerFactory.createRealTimeAnalyzers(config);
            end
            
            % post-analysis analyzer
            if config.PostHocSettings.enabled
                analyzers.postHoc = AnalyzerFactory.createPostHocAnalyzers(config);
            end
        end
        
        function realTimeAnalyzers = createRealTimeAnalyzers(config)
            realTimeAnalyzers = struct();
            analysisTypes = config.RealTimeSettings.analysisTypes;
            
            for i = 1:length(analysisTypes)
                analyzer = AnalyzerFactory.createAnalyzer(analysisTypes{i}, config);
                realTimeAnalyzers.(analysisTypes{i}) = analyzer;
            end
        end
    end
end