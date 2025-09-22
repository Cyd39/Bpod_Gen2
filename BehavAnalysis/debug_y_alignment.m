% Debug script to check Y-axis alignment precision
function debug_y_alignment()
    fprintf('Debugging Y-axis alignment precision...\n');
    fprintf('======================================\n\n');
    
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
        
        % Prepare data for raster plot
        EventT = processedData.LickOnAfterStim;
        Var = processedData.AudIntensity;
        
        % Get unique intensities
        uniqueIntensities = unique(Var);
        fprintf('\nUnique intensities: %s\n', mat2str(uniqueIntensities));
        
        % Simulate the exact Y position calculation from plotRaster
        NVar = size(Var, 2);
        NStim = size(Var, 1);
        UVar = unique(Var, 'rows');
        NUVar = size(UVar, 1);
        
        CVar = unique(Var(:,1));
        NColor = length(CVar);
        
        yinc = flip(10.^[1:NVar]);
        
        % Create raster data
        [SortVar, idx] = sortrows(Var);
        diffVar = SortVar(1:end-1,:) ~= SortVar(2:end,:);
        diffVar = [zeros(1,NVar); diffVar];
        
        Ycnt = 0;
        Ypos = nan(NStim, 1);
        
        fprintf('\nDetailed Y position calculation:\n');
        for k = 1:NStim
            stimNum = idx(k);
            intensity = Var(stimNum);
            
            % get event times
            X = EventT{stimNum, 1};
            if ~isempty(X) && ~all(isnan(X))
                % calculate next position
                Ycnt = Ycnt + 1;
                for v = 1:NVar  % add offset if stimulus is new
                    if (diffVar(k,v))
                        Ycnt = Ycnt + yinc(v);
                        fprintf('  Trial %d: Added offset %d, new Ycnt = %d\n', stimNum, yinc(v), Ycnt);
                    end
                end
                
                Ypos(stimNum) = Ycnt;
                fprintf('Trial %d (intensity %d): Final Y position = %.1f\n', stimNum, intensity, Ycnt);
            else
                fprintf('Trial %d (intensity %d): No valid lick data\n', stimNum, intensity);
            end
        end
        
        % Calculate YTick for each intensity group
        fprintf('\nYTick calculation for each intensity:\n');
        for i = 1:length(uniqueIntensities)
            intensity = uniqueIntensities(i);
            trials = find(Var == intensity);
            validYpos = Ypos(trials);
            validYpos = validYpos(~isnan(validYpos));
            
            if ~isempty(validYpos)
                meanY = mean(validYpos);
                minY = min(validYpos);
                maxY = max(validYpos);
                fprintf('Intensity %d: Y positions = %s\n', intensity, mat2str(validYpos));
                fprintf('  Mean: %.1f, Min: %.1f, Max: %.1f, Range: %.1f\n', meanY, minY, maxY, maxY-minY);
            else
                fprintf('Intensity %d: No valid Y positions\n', intensity);
            end
        end
        
        % Check the actual YTick calculation from plotRaster
        fprintf('\nActual YTick calculation from plotRaster:\n');
        tempUVar = unique(Var(:,1:1), 'rows');
        tempNUVar = size(tempUVar, 1);
        tempYTick = nan(tempNUVar, 1);
        
        for k = 1:tempNUVar
            sel = ones(NStim, 1);
            for p = 1:1
                sel = sel & Var(:,p) == tempUVar(k,p);
            end
            if any(sel)
                validYpos = Ypos(sel & ~isnan(Ypos));
                if ~isempty(validYpos)
                    tempYTick(k) = mean(validYpos);
                    fprintf('Group %d (intensity %d): Mean Y = %.1f\n', k, tempUVar(k,1), tempYTick(k));
                end
            end
        end
        
        % Remove NaN values
        validIdx = ~isnan(tempYTick);
        finalYTick = tempYTick(validIdx);
        finalYTickLab = tempUVar(validIdx, 1);
        
        fprintf('\nFinal YTick: %s\n', mat2str(finalYTick));
        fprintf('Final YTickLab: %s\n', mat2str(finalYTickLab));
        
        fprintf('\n✓ Y-axis alignment debugging completed!\n');
        
    catch ME
        fprintf('\n❌ Debug failed with error:\n');
        fprintf('Error: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end
end
