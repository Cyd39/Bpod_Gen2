% hit rate analyzer
classdef HitRateAnalyzer < BaseAnalyzer
    properties
        AnalyzerName = 'hit_rate'
        RequiredParameters = {'Hit', 'Intensity'}
    end
    
    methods
        function results = analyze(obj, data)
            % Calculate hit rate analysis
            results = struct();
            
            % Validate input data
            if ~obj.validateData(data)
                error('Invalid data for hit rate analysis');
            end
            
            % Extract intensity levels
            if isfield(data, 'AudIntensity')
                intensities = data.AudIntensity;
            elseif isfield(data, 'Intensity')
                intensities = data.Intensity;
            else
                error('No intensity data found');
            end
            
            % Calculate hit rates
            hitRateTable = obj.calculateHitRateTable(data.Hit, intensities);
            results.hitRateTable = hitRateTable;
            
            % Calculate overall statistics
            results.overallHitRate = mean(data.Hit);
            results.totalTrials = length(data.Hit);
            results.hitTrials = sum(data.Hit);
            
            % Calculate psychometric curve parameters
            results.psychometricParams = obj.fitPsychometricCurve(hitRateTable);
            
            % Display results
            obj.displayResults(results);
        end
        
        function hitRateTable = calculateHitRateTable(obj, hitData, intensities)
            % Calculate hit rate for each intensity level
            uInt = unique(intensities);
            nInt = length(uInt);
            
            % Initialize output table
            hitRateTable = table();
            hitRateTable.Intensity = uInt;
            hitRateTable.TotalTrials = zeros(nInt, 1);
            hitRateTable.HitTrials = zeros(nInt, 1);
            hitRateTable.HitRate = zeros(nInt, 1);
            hitRateTable.SEM = zeros(nInt, 1);
            
            % Calculate hit rate for each intensity
            for i = 1:nInt
                currentInt = uInt(i);
                
                % Find trials with this intensity
                intensityMask = intensities == currentInt;
                trialsForIntensity = hitData(intensityMask);
                
                % Count total trials for this intensity
                totalTrials = length(trialsForIntensity);
                
                % Count trials with Hit = 1
                hitTrials = sum(trialsForIntensity == 1);
                
                % Calculate hit rate
                hitRate = hitTrials / totalTrials;
                
                % Calculate standard error of proportion
                if totalTrials > 1
                    sem = sqrt(hitRate * (1 - hitRate) / totalTrials);
                else
                    sem = 0;
                end
                
                % Store results
                hitRateTable.TotalTrials(i) = totalTrials;
                hitRateTable.HitTrials(i) = hitTrials;
                hitRateTable.HitRate(i) = hitRate;
                hitRateTable.SEM(i) = sem;
            end
        end
        
        function psychometricParams = fitPsychometricCurve(obj, hitRateTable)
            % Fit psychometric curve to hit rate data
            psychometricParams = struct();
            
            % Filter out -inf and NaN values for curve fitting
            validIdx = ~isinf(hitRateTable.Intensity) & ~isnan(hitRateTable.Intensity) & ...
                      ~isnan(hitRateTable.HitRate);
            
            if sum(validIdx) < 3
                psychometricParams.valid = false;
                psychometricParams.message = 'Insufficient data for curve fitting';
                return;
            end
            
            x = hitRateTable.Intensity(validIdx);
            y = hitRateTable.HitRate(validIdx);
            n = hitRateTable.TotalTrials(validIdx);
            
            try
                % Simple logistic fit (can be enhanced with more sophisticated models)
                % y = 1 / (1 + exp(-(x - threshold) / slope))
                
                % Initial guess
                threshold = median(x);
                slope = std(x) / 4;
                
                % Fit logistic function
                options = optimoptions('fmincon', 'Display', 'off');
                params = fmincon(@(p) obj.logisticError(p, x, y, n), ...
                    [threshold, slope], [], [], [], [], ...
                    [min(x), 0.1], [max(x), 10*std(x)], [], options);
                
                psychometricParams.valid = true;
                psychometricParams.threshold = params(1);
                psychometricParams.slope = params(2);
                psychometricParams.r2 = obj.calculateR2(x, y, params);
                
            catch ME
                psychometricParams.valid = false;
                psychometricParams.message = ['Curve fitting failed: ' ME.message];
            end
        end
        
        function error = logisticError(obj, params, x, y, n)
            % Calculate error for logistic fitting
            threshold = params(1);
            slope = params(2);
            
            % Predicted values
            y_pred = 1 ./ (1 + exp(-(x - threshold) / slope));
            
            % Weighted least squares error
            weights = n / sum(n);
            error = sum(weights .* (y - y_pred).^2);
        end
        
        function r2 = calculateR2(obj, x, y, params)
            % Calculate R-squared for curve fit
            threshold = params(1);
            slope = params(2);
            y_pred = 1 ./ (1 + exp(-(x - threshold) / slope));
            
            ss_res = sum((y - y_pred).^2);
            ss_tot = sum((y - mean(y)).^2);
            r2 = 1 - ss_res / ss_tot;
        end
        
        function displayResults(obj, results)
            % Display analysis results
            fprintf('\nHit Rate Analysis:\n');
            fprintf('==================\n');
            fprintf('Overall Hit Rate: %.2f%% (%d/%d trials)\n', ...
                results.overallHitRate * 100, results.hitTrials, results.totalTrials);
            
            fprintf('\nHit Rate by Intensity:\n');
            for i = 1:height(results.hitRateTable)
                intensity = results.hitRateTable.Intensity(i);
                if isinf(intensity) && intensity < 0
                    intensityStr = '-∞';
                else
                    intensityStr = sprintf('%.1f', intensity);
                end
                
                fprintf('Intensity %s: %d/%d trials = %.2f%% ± %.2f%%\n', ...
                    intensityStr, ...
                    results.hitRateTable.HitTrials(i), ...
                    results.hitRateTable.TotalTrials(i), ...
                    results.hitRateTable.HitRate(i) * 100, ...
                    results.hitRateTable.SEM(i) * 100);
            end
            
            if results.psychometricParams.valid
                fprintf('\nPsychometric Curve:\n');
                fprintf('Threshold: %.2f\n', results.psychometricParams.threshold);
                fprintf('Slope: %.2f\n', results.psychometricParams.slope);
                fprintf('R²: %.3f\n', results.psychometricParams.r2);
            else
                fprintf('\nPsychometric Curve: %s\n', results.psychometricParams.message);
            end
        end
        
        function isValid = validateData(obj, data)
            % Validate input data
            isValid = true;
            
            if ~isfield(data, 'Hit') || isempty(data.Hit)
                isValid = false;
                return;
            end
            
            if ~isfield(data, 'AudIntensity') && ~isfield(data, 'Intensity')
                isValid = false;
                return;
            end
            
            % Check data consistency
            if isfield(data, 'AudIntensity')
                if length(data.Hit) ~= length(data.AudIntensity)
                    isValid = false;
                end
            elseif isfield(data, 'Intensity')
                if length(data.Hit) ~= length(data.Intensity)
                    isValid = false;
                end
            end
        end
    end
end
