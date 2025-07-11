function hitRateTable = CalculateHitRate(Session_tbl)
% CALCULATEHITRATE - Calculate hit rate for each intensity level
% 
% Input:
%   Session_tbl - Session table with trial data
%
% Output:
%   hitRateTable - Table with intensity levels and corresponding hit rates
%
% Hit rate is calculated as: (Number of trials with Reward=1) / (Total trials for that intensity)

% Get unique intensity levels
uInt = unique(Session_tbl.AudIntensity);
nInt = length(uInt);

% Initialize output table
hitRateTable = table();
hitRateTable.Intensity = uInt;
hitRateTable.TotalTrials = zeros(nInt, 1);
hitRateTable.HitTrials = zeros(nInt, 1);
hitRateTable.HitRate = zeros(nInt, 1);

% Calculate hit rate for each intensity
for i = 1:nInt
    currentInt = uInt(i);
    
    % Find trials with this intensity
    intensityMask = Session_tbl.AudIntensity == currentInt;
    trialsForIntensity = Session_tbl(intensityMask, :);
    
    % Count total trials for this intensity
    totalTrials = height(trialsForIntensity);
    
    % Count trials with Hit = 1
    hitTrials = sum(trialsForIntensity.Hit == 1);
    
    % Calculate hit rate
    hitRate = hitTrials / totalTrials;
    
    % Store results
    hitRateTable.TotalTrials(i) = totalTrials;
    hitRateTable.HitTrials(i) = hitTrials;
    hitRateTable.HitRate(i) = hitRate;
end

% Display results
fprintf('\nHit Rate Analysis:\n');
fprintf('==================\n');
for i = 1:height(hitRateTable)
    fprintf('Intensity %.1f: %d/%d trials = %.2f%% hit rate\n', ...
        hitRateTable.Intensity(i), ...
        hitRateTable.HitTrials(i), ...
        hitRateTable.TotalTrials(i), ...
        hitRateTable.HitRate(i) * 100);
end

end 