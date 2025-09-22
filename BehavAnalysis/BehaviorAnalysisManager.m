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
            obj.Analyzers = createAnalyzers(obj.Config);
            obj.Visualizers = createVisualizers(obj.Config);
            obj.ResultsManager = ResultsManager(obj.Config);
        end
        
        function runRealTimeAnalysis(obj, trialData)
            % real-time analysis (during experiment)
            processedData = obj.Preprocessor.processTrialData(trialData);
            results = obj.Analyzers.realTime.analyze(processedData);
            obj.Visualizers.realTime.update(results);
            obj.ResultsManager.saveTrialResults(results);
        end
        
        function runPostAnalysis(obj, sessionPath)
            % post-analysis (after experiment)
            data = obj.DataLoader.loadSessionData(sessionPath);
            processedData = obj.Preprocessor.processSessionData(data);
            results = obj.Analyzers.postHoc.analyze(processedData);
            obj.Visualizers.postHoc.createFigures(results);
            obj.ResultsManager.saveSessionResults(results);
        end
    end
end