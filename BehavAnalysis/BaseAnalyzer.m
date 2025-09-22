% base analyzer
classdef BaseAnalyzer < handle
    properties (Abstract)
        AnalyzerName
        RequiredParameters
    end
    
    methods (Abstract)
        results = analyze(obj, data)
    end
    
    methods
        function isValid = validateParameters(obj, parameters)
            isValid = all(isfield(parameters, obj.RequiredParameters));
        end
    end
end

% specific analyzer example - PerformanceAnalyzer.m
classdef PerformanceAnalyzer < BaseAnalyzer
    properties
        AnalyzerName = 'performance'
        RequiredParameters = {'correct_trials', 'total_trials'}
    end
    
    methods
        function results = analyze(obj, data)
            results.accuracy = mean(data.correct_trials);
            results.total_trials = length(data.correct_trials);
            results.bias = obj.calculateBias(data);
        end
        
        function bias = calculateBias(obj, data)
            % calculate reaction bias
            % specific implementation...
        end
    end
end