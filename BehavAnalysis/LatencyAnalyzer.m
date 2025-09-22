% latency analyzer
classdef LatencyAnalyzer < BaseAnalyzer
    properties
        AnalyzerName = 'latency'
        RequiredParameters = {'Latency', 'Hit', 'Intensity'}
    end
    
    methods
        function results = analyze(obj, data)
            % Calculate latency analysis
            results = struct();
            
            % Validate input data
            if ~obj.validateData(data)
                error('Invalid data for latency analysis');
            end
            
            % Extract intensity levels
            if isfield(data, 'AudIntensity')
                intensities = data.AudIntensity;
            elseif isfield(data, 'Intensity')
                intensities = data.Intensity;
            else
                error('No intensity data found');
            end
            
            % Calculate latency statistics by intensity
            results.latencyByIntensity = obj.calculateLatencyByIntensity(data.Latency, data.Hit, intensities);
            
            % Calculate overall latency statistics
            results.overallStats = obj.calculateOverallStats(data.Latency, data.Hit);
            
            % Perform statistical tests
            results.statisticalTests = obj.performStatisticalTests(results.latencyByIntensity);
            
            % Display results
            obj.displayResults(results);
        end
        
        function latencyByIntensity = calculateLatencyByIntensity(obj, latencies, hits, intensities)
            % Calculate latency statistics for each intensity level
            uInt = unique(intensities);
            nInt = length(uInt);
            
            % Initialize structure
            latencyByIntensity = struct();
            latencyByIntensity.intensities = uInt;
            latencyByIntensity.data = cell(nInt, 1);
            latencyByIntensity.stats = struct();
            
            % Calculate statistics for each intensity
            for i = 1:nInt
                currentInt = uInt(i);
                
                % Find hit trials with this intensity
                intensityMask = intensities == currentInt;
                hitMask = hits == 1;
                validMask = intensityMask & hitMask;
                
                % Extract latencies for this intensity
                validLatencies = [];
                for j = 1:length(latencies)
                    if validMask(j) && ~isempty(latencies{j}) && ~isnan(latencies{j})
                        validLatencies = [validLatencies; latencies{j}];
                    end
                end
                
                % Store data
                latencyByIntensity.data{i} = validLatencies;
                
                % Calculate statistics
                if ~isempty(validLatencies)
                    stats = struct();
                    stats.n = length(validLatencies);
                    stats.mean = mean(validLatencies);
                    stats.median = median(validLatencies);
                    stats.std = std(validLatencies);
                    stats.sem = stats.std / sqrt(stats.n);
                    stats.min = min(validLatencies);
                    stats.max = max(validLatencies);
                    stats.q25 = quantile(validLatencies, 0.25);
                    stats.q75 = quantile(validLatencies, 0.75);
                    
                    latencyByIntensity.stats.(['intensity_' num2str(i)]) = stats;
                else
                    % No valid data for this intensity
                    stats = struct();
                    stats.n = 0;
                    stats.mean = NaN;
                    stats.median = NaN;
                    stats.std = NaN;
                    stats.sem = NaN;
                    stats.min = NaN;
                    stats.max = NaN;
                    stats.q25 = NaN;
                    stats.q75 = NaN;
                    
                    latencyByIntensity.stats.(['intensity_' num2str(i)]) = stats;
                end
            end
        end
        
        function overallStats = calculateOverallStats(obj, latencies, hits)
            % Calculate overall latency statistics
            overallStats = struct();
            
            % Extract all valid latencies from hit trials
            allLatencies = [];
            for i = 1:length(latencies)
                if hits(i) == 1 && ~isempty(latencies{i}) && ~isnan(latencies{i})
                    allLatencies = [allLatencies; latencies{i}];
                end
            end
            
            if ~isempty(allLatencies)
                overallStats.n = length(allLatencies);
                overallStats.mean = mean(allLatencies);
                overallStats.median = median(allLatencies);
                overallStats.std = std(allLatencies);
                overallStats.sem = overallStats.std / sqrt(overallStats.n);
                overallStats.min = min(allLatencies);
                overallStats.max = max(allLatencies);
                overallStats.q25 = quantile(allLatencies, 0.25);
                overallStats.q75 = quantile(allLatencies, 0.75);
            else
                overallStats.n = 0;
                overallStats.mean = NaN;
                overallStats.median = NaN;
                overallStats.std = NaN;
                overallStats.sem = NaN;
                overallStats.min = NaN;
                overallStats.max = NaN;
                overallStats.q25 = NaN;
                overallStats.q75 = NaN;
            end
        end
        
        function statisticalTests = performStatisticalTests(obj, latencyByIntensity)
            % Perform statistical tests on latency data
            statisticalTests = struct();
            
            % Extract data for statistical tests
            validData = {};
            validIntensities = [];
            
            for i = 1:length(latencyByIntensity.data)
                data = latencyByIntensity.data{i};
                if ~isempty(data)
                    validData{end+1} = data;
                    validIntensities(end+1) = latencyByIntensity.intensities(i);
                end
            end
            
            if length(validData) < 2
                statisticalTests.valid = false;
                statisticalTests.message = 'Insufficient data for statistical tests';
                return;
            end
            
            statisticalTests.valid = true;
            
            % Kruskal-Wallis test (non-parametric ANOVA)
            try
                [p_kw, tbl_kw, stats_kw] = kruskalwallis(cell2mat(validData'), ...
                    arrayfun(@(x) sprintf('Int_%.1f', x), validIntensities, 'UniformOutput', false), 'off');
                statisticalTests.kruskalWallis.p = p_kw;
                statisticalTests.kruskalWallis.table = tbl_kw;
                statisticalTests.kruskalWallis.stats = stats_kw;
            catch ME
                statisticalTests.kruskalWallis.p = NaN;
                statisticalTests.kruskalWallis.message = ME.message;
            end
            
            % Pairwise comparisons (if more than 2 groups)
            if length(validData) > 2
                try
                    [p_mc, tbl_mc] = multcompare(stats_kw, 'Display', 'off');
                    statisticalTests.multipleComparisons.p = p_mc;
                    statisticalTests.multipleComparisons.table = tbl_mc;
                catch ME
                    statisticalTests.multipleComparisons.p = NaN;
                    statisticalTests.multipleComparisons.message = ME.message;
                end
            end
        end
        
        function displayResults(obj, results)
            % Display analysis results
            fprintf('\nLatency Analysis:\n');
            fprintf('================\n');
            
            % Overall statistics
            if results.overallStats.n > 0
                fprintf('Overall Latency (Hit trials only):\n');
                fprintf('  n = %d, mean = %.3f ± %.3f s, median = %.3f s\n', ...
                    results.overallStats.n, results.overallStats.mean, ...
                    results.overallStats.sem, results.overallStats.median);
                fprintf('  range: %.3f - %.3f s\n', ...
                    results.overallStats.min, results.overallStats.max);
            else
                fprintf('No hit trials found for latency analysis\n');
            end
            
            % Statistics by intensity
            fprintf('\nLatency by Intensity (Hit trials only):\n');
            for i = 1:length(results.latencyByIntensity.intensities)
                intensity = results.latencyByIntensity.intensities(i);
                fieldName = ['intensity_' num2str(i)];
                
                if isfield(results.latencyByIntensity.stats, fieldName)
                    stats = results.latencyByIntensity.stats.(fieldName);
                    
                    if stats.n > 0
                        if isinf(intensity) && intensity < 0
                            intensityStr = '-∞';
                        else
                            intensityStr = sprintf('%.1f', intensity);
                        end
                        
                        fprintf('Intensity %s: n=%d, mean=%.3f±%.3f s, median=%.3f s\n', ...
                            intensityStr, stats.n, stats.mean, stats.sem, stats.median);
                    end
                end
            end
            
            % Statistical tests
            if results.statisticalTests.valid
                fprintf('\nStatistical Tests:\n');
                if ~isnan(results.statisticalTests.kruskalWallis.p)
                    fprintf('Kruskal-Wallis test: p = %.4f\n', ...
                        results.statisticalTests.kruskalWallis.p);
                end
            else
                fprintf('\nStatistical Tests: %s\n', results.statisticalTests.message);
            end
        end
        
        function isValid = validateData(obj, data)
            % Validate input data
            isValid = true;
            
            if ~isfield(data, 'Latency') || isempty(data.Latency)
                isValid = false;
                return;
            end
            
            if ~isfield(data, 'Hit') || isempty(data.Hit)
                isValid = false;
                return;
            end
            
            if ~isfield(data, 'AudIntensity') && ~isfield(data, 'Intensity')
                isValid = false;
                return;
            end
            
            % Check data consistency
            if length(data.Latency) ~= length(data.Hit)
                isValid = false;
                return;
            end
        end
    end
end
