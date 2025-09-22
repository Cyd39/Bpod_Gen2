% Debug script to check Y positions for each intensity group
function debug_y_positions()
    fprintf('Debugging Y positions for each intensity group...\n');
    fprintf('================================================\n\n');
    
    try
        % Initialize analysis manager
        configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
        analysisManager = BehaviorAnalysisManager(configPath);
        
        % Load data
        [SessionData, Session_tbl, filePath] = analysisManager.DataLoader.loadSessionData();
        fprintf('✓ Data loaded from: %s\n', filePath);
        
        % Process data
        data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
        processedData = analysisManager.Preprocessor.processSessionData(data);
        fprintf('✓ Data processed successfully\n');
        
        % Check intensity data
        intensities = processedData.AudIntensity;
        uniqueIntensities = unique(intensities);
        fprintf('\nIntensity groups:\n');
        for i = 1:length(uniqueIntensities)
            intensity = uniqueIntensities(i);
            trials = find(intensities == intensity);
            fprintf('- Intensity %d: %d trials (indices: %s)\n', intensity, length(trials), mat2str(trials(1:min(5, length(trials)))));
        end
        
        % Prepare data for raster plot
        EventT = processedData.LickOnAfterStim;
        Var = processedData.AudIntensity;
        
        % Simulate the Y position calculation
        NVar = size(Var, 2);
        NStim = size(Var, 1);
        UVar = unique(Var, 'rows');
        NUVar = size(UVar, 1);
        
        CVar = unique(Var(:,1));
        NColor = length(CVar);
        
        yinc = flip(10.^[1:NVar]);
        
        % Create raster data (simplified version)
        [SortVar, idx] = sortrows(Var);
        diffVar = SortVar(1:end-1,:) ~= SortVar(2:end,:);
        diffVar = [zeros(1,NVar); diffVar];
        
        Ycnt = 0;
        Ypos = nan(NStim, 1);
        
        fprintf('\nY position calculation:\n');
        for k = 1:NStim
            stimNum = idx(k);
            intensity = Var(stimNum);
            
            % get event times
            X = EventT{stimNum, 1};
            if ~isempty(X) && ~all(isnan(X))
                % calculate next position
                Ycnt = Ycnt + 1;
                for v = 1:NVar  % add offset if stimulus is new
                    if (diffVar(k,v)); Ycnt = Ycnt + yinc(v); end
                end
                
                Ypos(stimNum) = Ycnt;
                fprintf('Trial %d (intensity %d): Y position = %.1f\n', stimNum, intensity, Ycnt);
            else
                fprintf('Trial %d (intensity %d): No valid lick data\n', stimNum, intensity);
            end
        end
        
        % Check Y positions for each intensity group
        fprintf('\nY positions by intensity group:\n');
        for i = 1:length(uniqueIntensities)
            intensity = uniqueIntensities(i);
            trials = find(intensities == intensity);
            validYpos = Ypos(trials);
            validYpos = validYpos(~isnan(validYpos));
            
            if ~isempty(validYpos)
                fprintf('- Intensity %d: Y positions = %s\n', intensity, mat2str(validYpos));
                fprintf('  Mean Y position: %.1f\n', mean(validYpos));
                fprintf('  Min Y position: %.1f\n', min(validYpos));
                fprintf('  Max Y position: %.1f\n', max(validYpos));
            else
                fprintf('- Intensity %d: No valid Y positions\n', intensity);
            end
        end
        
        fprintf('\n✓ Y position debugging completed!\n');
        
    catch ME
        fprintf('\n❌ Debug failed with error:\n');
        fprintf('Error: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end
end
