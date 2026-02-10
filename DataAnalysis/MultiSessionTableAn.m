% Analysis and plotting of multisession table data
%% Data loading
clearvars
%load('')
%% Data proccessiong
T = resultsTable;
bf = 250; % boundary frequency

% convert date string to datetime
T.DateTime = datetime(resultsTable.Time, ...
        'InputFormat', 'yyyyMMdd_HHmmss');

% Only keep sessions with >= 40 trials
validRows = T.Session_nTrials >= 40;
T = T(validRows, :);

% calculation of response rate for each stimulus(including catch trial as false alarm rate)
n_response = T.N_ValidRT; 
n_trial = T.NTrials; % NTrials is number of trials for each stimulus/catch trial
res_rate = n_response ./ n_trial; % response rate for each stimulus/catch trial
T.ResRate = res_rate;

animals = unique(T.AnimalID);
nAnimals = length(animals);
% sl: session list
[sl, idx] = unique(T(:, {'AnimalID', 'DateTime'}), 'rows');
sl.Protocol = T.Protocol(idx);

% remove NaT DateTime
validRows = ~isnat(sl.DateTime);
sl = sl(validRows, :);
validRows = ~isnat(T.DateTime);
T = T(validRows, :);

% Calculation of ground hit rate, ground response rate and false alarm rate by session per mouse
nSessions = height(sl);
falseAlarm = NaN(nSessions, 1);
resRate = NaN(nSessions, 1);
resRateEasy = NaN(nSessions, 1);
resRateEasiest = NaN(nSessions, 1);
sessionHitRate = NaN(nSessions, 1);
sessionLeftHitRate = NaN(nSessions, 1);
sessionRightHitRate = NaN(nSessions, 1);

for i = 1:nSessions
    animal = sl.AnimalID(i);
    time = sl.DateTime(i);
    % false alarm rate
    rowIdx = find(T.DateTime == time & ...
              strcmp(T.AnimalID, animal)& ...
              T.VibFreq == 0);
    if rowIdx
        falseAlarm(i) =  T.ResRate(rowIdx);
    end
    % response rate
    rowIdx = find(T.DateTime == time & ...
              strcmp(T.AnimalID, animal)& ...
              T.VibFreq ~= 0);
    if rowIdx
        notCatchTrials = sum(T.NTrials(rowIdx));
        notCatchTrialRes = sum(T.N_ValidRT(rowIdx));
        resRate(i) = notCatchTrialRes / notCatchTrials;
    end
    % response rate for "easiest" stimuli(highest amp for each freq)
    easyTrials =  0;
    easyTrialsRes = 0;
    easiestTrials = 0;
    easiestTrialsRes = 0;
    iseasiest = false;

    rowIdx = find(T.DateTime == time & ...
              strcmp(T.AnimalID, animal)& ...
              T.VibFreq ~= 0);
    freqs = unique(T.VibFreq(rowIdx));
    easiestFreq = max(freqs);
    for f = 1:length(freqs)
        targetFreq = freqs(f);
        mask = T.DateTime == time & strcmp(T.AnimalID, animal) & T.VibFreq == targetFreq;
        if any(mask)
            maxAmp = max(T.VibAmp(mask));
            nEasyTrials = T.NTrials(find(T.DateTime == time & ...
                                        strcmp(T.AnimalID, animal) & ...
                                        T.VibFreq == targetFreq & ...
                                        T.VibAmp == maxAmp, 1));
            nEasyTrialsRes = T.N_ValidRT(find(T.DateTime == time & ...
                                        strcmp(T.AnimalID, animal) & ...
                                        T.VibFreq == targetFreq & ...
                                        T.VibAmp == maxAmp, 1));
            if targetFreq == easiestFreq
               resRateEasiest(i)  = nEasyTrialsRes/nEasyTrials;
            end
            easyTrials = easyTrials + nEasyTrials;
            easyTrialsRes = easyTrialsRes + nEasyTrialsRes;
        end
    end
    if easyTrials ~= 0
        resRateEasy(i) = easyTrialsRes /easyTrials;
    end
end
sl.FalseAlarmRate = falseAlarm;
sl.ResponseRate = resRate;
sl.ResponseRateEasy = resRateEasy;
sl.ResponseRateEasiest = resRateEasiest;

% sorting and index sessions by time for each mouse 
sl = sortrows(sl,{'AnimalID','DateTime'});
for i = 1:nAnimals
    animalMask = strcmp(sl.AnimalID, animals{i});
    % number the sessions for this animal
    sl.NumSession(animalMask) = (1:sum(animalMask))';
end
T = sortrows(T,{'AnimalID','DateTime','VibFreq','VibAmp'});
for i = 1:nAnimals
    animalMask = strcmp(T.AnimalID, animals{i});
    animalDateTimes = T.DateTime(animalMask);
    % number the sessions for this animal
    T.NumSession(animalMask) = (1:sum(animalMask))';
    [~, ~, idx] = unique(animalDateTimes);
    T.NumSession(animalMask) = idx;
end
%% Plotting
% % false alarm rate [not used]
% figure('Position', [100, 100, 1300, 600]);
% % colors for each animal
% animalColors  = lines(nAnimals); 
% 
% subplot(2, 1, 1);
% hold on;
% 
% subplot(2, 1, 2);
% hold on;
% 
% for i = 1:nAnimals
%     if i == 1 || i == 3 
%         subplot(2,1,1);
%     else
%         subplot(2,1,2);
%     end
%     mask = strcmp(sl.AnimalID, animals{i});
%     x = sl.NumSession(mask);
%     y = sl.FalseAlarmRate(mask);
% 
%     % sort by NumSession
%     [x_sorted, sort_idx] = sort(x);
%     y_sorted = y(sort_idx);
% 
%     plot(x_sorted, y_sorted, 'o-', ...
%          'Color',animalColors(i, :),...
%          'MarkerSize', 3, ...
%          'MarkerFaceColor', animalColors(i, :), ...
%          'LineWidth', 2, ...
%          'DisplayName', char(animals{i}));
% end
% 
% subplot(2, 1, 1);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('False Alarm Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% 
% subplot(2, 1, 2);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('False Alarm Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% 
% sgtitle('False Alarm Rate Progression', 'FontSize', 14);
%% overall response rate [not used]
% figure('Position', [100, 100, 1500, 600]);
% % colors for each animal
% animalColors  = lines(nAnimals); 
% 
% subplot(2, 1, 1);
% hold on;
% 
% subplot(2, 1, 2);
% hold on;
% 
% for i = 1:nAnimals
%     if i == 1 || i == 3 
%         subplot(2,1,1);
%     else
%         subplot(2,1,2);
%     end
%     mask = strcmp(sl.AnimalID, animals{i});
%     x = sl.NumSession(mask);
%     y = sl.ResponseRate(mask);
% 
%     % sort by NumSession
%     [x_sorted, sort_idx] = sort(x);
%     y_sorted = y(sort_idx);
% 
%     plot(x_sorted, y_sorted, 'o-', ...
%          'Color', animalColors(i, :), ...
%          'MarkerSize', 3, ...
%          'MarkerFaceColor', animalColors(i, :), ...
%          'LineWidth', 2, ...
%          'DisplayName', char(animals{i}));
% end
% 
% subplot(2, 1, 1);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% 
% subplot(2, 1, 2);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% 
% hold off;
% sgtitle('Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% "easy" stimuli response rate [not used]
% figure('Position', [100, 100, 1500, 800]);
% 
% % colors for each animal
% animalColors  = lines(nAnimals);  
% 
% subplot(2, 1, 1);
% hold on;
% 
% subplot(2, 1, 2);
% hold on;
% for i = 1:nAnimals
%     if i == 1 || i == 3 
%         subplot(2,1,1);
%     else
%         subplot(2,1,2);
%     end
% 
%     mask = strcmp(sl.AnimalID, animals{i});
%     x = sl.NumSession(mask);
%     y = sl.ResponseRateEasy(mask);
% 
%     % sort by NumSession
%     [x_sorted, sort_idx] = sort(x);
%     y_sorted = y(sort_idx);
% 
%     plot(x_sorted, y_sorted, 'o-', ...
%          'Color', animalColors(i, :), ...
%          'MarkerSize', 3, ...
%          'MarkerFaceColor', animalColors(i, :), ...
%          'LineWidth', 2, ...
%          'DisplayName', char(animals{i}));
% end
% 
% subplot(2, 1, 1);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% 
% subplot(2, 1, 2);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% sgtitle('Easiest Stimuli(All Freq) Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% "easiest stimuli response rate" [not used]
% figure('Position', [100, 100, 1500, 800]);
% 
% % colors for each animal
% animalColors  = lines(nAnimals);  
% 
% subplot(2, 1, 1);
% hold on;
% 
% subplot(2, 1, 2);
% hold on;
% for i = 1:nAnimals
%     if i == 1 || i == 3 
%         subplot(2,1,1);
%     else
%         subplot(2,1,2);
%     end
% 
%     mask = strcmp(sl.AnimalID, animals{i});
%     x = sl.NumSession(mask);
%     y = sl.ResponseRateEasiest(mask);
% 
%     % sort by NumSession
%     [x_sorted, sort_idx] = sort(x);
%     y_sorted = y(sort_idx);
% 
%     plot(x_sorted, y_sorted, 'o-', ...
%          'Color', animalColors(i, :), ...
%          'MarkerSize', 3, ...
%          'MarkerFaceColor', animalColors(i, :), ...
%          'LineWidth', 2, ...
%          'DisplayName', char(animals{i}));
% end
% 
% subplot(2, 1, 1);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% 
% subplot(2, 1, 2);
% xlabel('Session Number', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% hold off;
% sgtitle('Easiest Stimulus(Hightest Freq) Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% Response Rate and False Alarm Rate by Session Number and Date
% Response rate is for the easiest stimulus(highest amp for highest freq)
op = {'DateTime', 'SessionNumber'}; % options for plotting
for o = 1:length(op)
    plotBy = op{o}; % 'DateTime'; 'SessionNumber'
    figure('Position', [100, 100, 1300, 800]);
    % colors for each animal
    animalColors  = lines(nAnimals); 
    
    subplot(2, 1, 1);
    hold on;
    
    subplot(2, 1, 2);
    hold on;
    
    for i = 1:nAnimals
        if i == 1 || i == 3 
            subplot(2,1,1);
        else
            subplot(2,1,2);
        end
        mask = strcmp(sl.AnimalID, animals{i});
    
        % ResponseRateEasiest
        switch plotBy
            case 'DateTime'
                x = sl.DateTime(mask);
            case 'SessionNumber'
                x = sl.NumSession(mask);
            otherwise
                x = sl.NumSession(mask);
        end
        y = sl.ResponseRateEasiest(mask);
        
        % sort by NumSession
        [x_sorted, sort_idx] = sort(x);
        y_sorted = y(sort_idx);
        
        plot(x_sorted, y_sorted, 'o-', ...
             'Color',animalColors(i, :),...
             'MarkerSize', 3, ...
             'MarkerFaceColor', animalColors(i, :), ...
             'LineWidth', 2, ...
             'DisplayName', [char(animals{i}),'(RR)']);
    
        % False Alarm
        y = sl.FalseAlarmRate(mask);
        
        % sort by NumSession
        y_sorted = y(sort_idx);
        
        plot(x_sorted, y_sorted, 'o:', ...
             'Color', animalColors(i, :), ...
             'MarkerSize', 3, ...
             'MarkerFaceColor', 'none', ...
             'LineWidth', 2, ...
             'DisplayName', [char(animals{i}),'(FA)']);
    end
    
    % xlabel
    switch plotBy
        case 'DateTime'
            xLabel = "Date";
        case 'SessionNumber'
            xLabel = "Session Number";    
        otherwise
            xLabel = "Session Number";
    end

    for i = 1:2
        subplot(2, 1, i);
        xlabel(xLabel, 'FontSize', 14);
        ylabel('Response or False Alarm Rate', 'FontSize', 14);
        grid on;
        legend('Location', 'eastoutside', 'FontSize', 10);
        if strcmp(plotBy,'DateTime')
            xticks(x_sorted(1) + caldays(0:7:360));
            xtickformat('MMM-dd')
        end
        hold off;
    end
    
    sgtitle('Response & False Alarm Rate Progression', 'FontSize', 14);
    saveFigAsPNG(['Res&FalseAlarmRate_by_',plotBy]);
end
%% Plot by DateTime
% figure('Position', [100, 100, 1500, 800]);
% 
% animalColors = lines(nAnimals);  
% 
% subplot(2, 1, 1);
% ax1 = gca;
% hold(ax1, 'on');
% 
% subplot(2, 1, 2);
% ax2 = gca;
% hold(ax2, 'on');
% 
% allDatetimes = [];
% 
% for i = 1:nAnimals
%     if i == 1 || i == 3 
%         axes(ax1);
%         currentAx = ax1;
%     else
%         axes(ax2);
%         currentAx = ax2;
%     end
% 
%     mask = strcmp(sl.AnimalID, animals{i});
% 
%     x = sl.DateTime(mask);
%     y = sl.ResponseRateEasy(mask);
% 
%     % collect all DateTime
%     allDatetimes = [allDatetimes; x];
% 
%     [x_sorted, sort_idx] = sort(x);
%     y_sorted = y(sort_idx);
% 
%     plot(x_sorted, y_sorted, 'o-', ...
%          'Color', animalColors(i, :), ...
%          'MarkerSize', 3, ...
%          'MarkerFaceColor', animalColors(i, :), ...
%          'LineWidth', 2, ...
%          'DisplayName', char(animals{i}));
% end
% 
% % settings for subplot 1
% axes(ax1);
% xlabel('Date & Time', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% 
% % refine date demonstration
% datetick('x', 'mm/dd', 'keepticks');
% xlim([min(allDatetimes)-hours(12), max(allDatetimes)+hours(12)]);
% hold off;
% 
% % settings for subplot 2
% axes(ax2);
% xlabel('Date & Time', 'FontSize', 14);
% ylabel('Response Rate', 'FontSize', 14);
% grid on;
% legend('Location', 'best', 'FontSize', 10);
% 
% % refine date demonstration
% datetick('x', 'mm/dd', 'keepticks');
% xlim([min(allDatetimes)-hours(12), max(allDatetimes)+hours(12)]);
% hold off;
% 
% sgtitle('Easiest Stimuli Response Rate Progression (by DateTime)', 'FontSize', 14, 'FontWeight', 'bold');

%% Stimuli and protocol used Version2
vibFreqs = unique(T.VibFreq);
nFreqs = length(vibFreqs);


colors = lines(nFreqs);  % colormap: lines, parula, hsv, jet, turbo etc.
figure('Position', [100, 100, 1400, 800]);
rows = ceil(sqrt(nAnimals));
cols = ceil(nAnimals / rows);
protocolChanges = {};  
changeHandles = [];  
scatterSize = 8;

for i = 1:nAnimals
    subplot(rows, cols, i);
    hold on;
    
    animalMask = strcmp(T.AnimalID, animals{i});
    T_animal = T(animalMask, :);
    T_animal = sortrows(T_animal, 'NumSession');
    
    [uniqueSessions, ~, idx] = unique(T_animal.NumSession);
    sessionProtocols = cell(length(uniqueSessions), 1);
    
    for s = 1:length(uniqueSessions)
        sessionMask = T_animal.NumSession == uniqueSessions(s);
        % first session of a protocol
        firstIdx = find(sessionMask, 1);
        sessionProtocols{s} = T_animal.Protocol{firstIdx};
    end
    
    % build legend only in the first subplot
    if i == 1
        for s = 2:length(sessionProtocols)
            if ~strcmp(sessionProtocols{s}, sessionProtocols{s-1})
                % plot line and save the handle
                h = xline(uniqueSessions(s) - 0.5, '--', ...
                         'Color', [0.3 0.3 0.3], ...
                         'LineWidth', 1.5);
                
                % description of changing protocol
                changeDesc = sprintf('%s → %s', ...
                    sessionProtocols{s-1}, sessionProtocols{s});
                
                % add to list
                protocolChanges{end+1} = changeDesc;
                changeHandles(end+1) = h;
                
                % name for legend
                set(h, 'DisplayName', changeDesc);
            end
        end
    else
        % no legend for other animals
        for s = 2:length(sessionProtocols)
            if ~strcmp(sessionProtocols{s}, sessionProtocols{s-1})
                xline(uniqueSessions(s) - 0.5, '--', ...
                     'Color', [0.3 0.3 0.3], ...
                     'LineWidth', 1.5, ...
                     'HandleVisibility', 'off');  
            end
        end
    end
    
    % plot for each Freq
    for f = 1:nFreqs
        freqMask = T_animal.VibFreq == vibFreqs(f);
        if any(freqMask)
            x = T_animal.NumSession(freqMask);
            y = T_animal.VibAmp(freqMask);

            x_jitter = x + 0.3 * (rand(size(x)) - 0.5);
            
            % plot raster
            % build legend only in the first subplot
            if i == 1
                scatter(x_jitter, y, scatterSize, 'filled', ...
                       'MarkerFaceColor', colors(f, :), ...
                       'MarkerEdgeColor', colors(f, :), ...
                       'MarkerFaceAlpha', 0.7, ...
                       'DisplayName', sprintf('Freq=%g', vibFreqs(f)));
            else
                scatter(x_jitter, y, scatterSize, 'filled', ...
                       'MarkerFaceColor', colors(f, :), ...
                       'MarkerEdgeColor', colors(f, :), ...
                       'MarkerFaceAlpha', 0.7, ...
                       'HandleVisibility', 'off');
            end
        end
    end
    
    hold off;
    title(sprintf('Animal: %s', animals{i}));
    xlabel('NumSession');
    ylabel('VibAmp');
    grid on;
    
end

sgtitle('VibAmp by Session');
% save without legend
saveFigAsPNG('Stimuli_BySession_NoLegend');

% show legend only once
subplot(rows, cols, 1);
legend('show', 'Location', 'best');

% save with legend
saveFigAsPNG('Stimuli_BySession_WithLegend');

%Plot By DateTime
vibFreqs = unique(T.VibFreq);
nFreqs = length(vibFreqs);


colors = lines(nFreqs);  % colormap: lines, parula, hsv, jet, turbo etc.
figure('Position', [100, 100, 1400, 800]);
rows = ceil(sqrt(nAnimals));
cols = ceil(nAnimals / rows);
protocolChanges = {};  
changeHandles = [];  
scatterSize = 10;

for i = 1:nAnimals
    subplot(rows, cols, i);
    hold on;
    
    animalMask = strcmp(T.AnimalID, animals{i});
    T_animal = T(animalMask, :);
    T_animal = sortrows(T_animal, 'DateTime');
    
    [uniqueSessions, ~, idx] = unique(T_animal.DateTime);
    sessionProtocols = cell(length(uniqueSessions), 1);
    
    for s = 1:length(uniqueSessions)
        sessionMask = T_animal.DateTime == uniqueSessions(s);
        % first session of a protocol
        firstIdx = find(sessionMask, 1);
        sessionProtocols{s} = T_animal.Protocol{firstIdx};
    end
    
    % build legend only in the first subplot
    if i == 1
        for s = 2:length(sessionProtocols)
            if ~strcmp(sessionProtocols{s}, sessionProtocols{s-1})
                % plot line and save the handle
                h = xline(uniqueSessions(s) - 0.5, '--', ...
                         'Color', [0.3 0.3 0.3], ...
                         'LineWidth', 1.5);
                
                % description of changing protocol
                changeDesc = sprintf('%s → %s', ...
                    sessionProtocols{s-1}, sessionProtocols{s});
                
                % add to list
                protocolChanges{end+1} = changeDesc;
                changeHandles(end+1) = h;
                
                % name for legend
                set(h, 'DisplayName', changeDesc);
            end
        end
    else
        % no legend for other animals
        for s = 2:length(sessionProtocols)
            if ~strcmp(sessionProtocols{s}, sessionProtocols{s-1})
                xline(uniqueSessions(s) - 0.5, '--', ...
                     'Color', [0.3 0.3 0.3], ...
                     'LineWidth', 1.5, ...
                     'HandleVisibility', 'off');  
            end
        end
    end
    
    % plot for each Freq
    for f = 1:nFreqs
        freqMask = T_animal.VibFreq == vibFreqs(f);
        if any(freqMask)
            x = T_animal.DateTime(freqMask);
            y = T_animal.VibAmp(freqMask);

            x_jitter = x + 0.3 * (rand(size(x)) - 0.5);
            
            % plot raster
            % build legend only in the first subplot
            if i == 1
                scatter(x_jitter, y, scatterSize, 'filled', ...
                       'MarkerFaceColor', colors(f, :), ...
                       'MarkerEdgeColor', colors(f, :), ...
                       'MarkerFaceAlpha', 0.7, ...
                       'DisplayName', sprintf('Freq=%g', vibFreqs(f)));
            else
                scatter(x_jitter, y, scatterSize, 'filled', ...
                       'MarkerFaceColor', colors(f, :), ...
                       'MarkerEdgeColor', colors(f, :), ...
                       'MarkerFaceAlpha', 0.7, ...
                       'HandleVisibility', 'off');
            end
        end
    end
    
    hold off;
    title(sprintf('Animal: %s', animals{i}));
    xlabel('Date & Time');
    ylabel('VibAmp');
    grid on;
    
end

sgtitle('VibAmp by Date');

% save without legend
saveFigAsPNG('Stimuli_ByDay_NoLegend');

% show legend only once
subplot(rows, cols, 1);
legend('show', 'Location', 'best');

% save with legend
saveFigAsPNG('Stimuli_ByDay_WithLegend');
%%  "easiest stimuli“(all Freq) Latency plotting
T_sorted = sortrows(T, {'AnimalID', 'NumSession', 'VibFreq', 'VibAmp'}, {'ascend', 'ascend', 'ascend', 'descend'});

% remove catch trials
notCatchTrialIdx = T_sorted.VibFreq ~= 0;
T_sorted = T_sorted(notCatchTrialIdx, :);

% find max amp for each freq
notCatchTrial_T = T_sorted ;
summaryLatency = table();
currentCombo = '';

for i = 1:height(T_sorted)
    % combination for current row
    comboStr = sprintf('%s_%d_%g', ...
        T_sorted.AnimalID{i}, ...
        T_sorted.NumSession(i), ...
        T_sorted.VibFreq(i));
    
    % keep the row if new combination
    if ~strcmp(comboStr, currentCombo)
        currentCombo = comboStr;
        
        % extract data
        newRow = T_sorted(i, {'AnimalID', 'NumSession', 'VibFreq', 'VibAmp', 'RT_Median'});
        newRow.Properties.VariableNames{'VibAmp'} = 'VibAmp_Max';
        
        summaryLatency = [summaryLatency; newRow];
    end
end
% all unique values
animals = unique(summaryLatency.AnimalID);
vibFreqs = unique(summaryLatency.VibFreq);
nAnimals = length(animals);
nFreqs = length(vibFreqs);

% colors
if nFreqs <= 8
    colors = lines(nFreqs);  
else
    colors = turbo(nFreqs);  
end

figure('Position', [100, 100, 1400, 800]);

% subplot positions
rows = ceil(sqrt(nAnimals));
cols = ceil(nAnimals / rows);

for i = 1:nAnimals
    subplot(rows, cols, i);
    hold on;
    
    currentAnimal = animals{i};
    
    % filter for animal
    animalMask = strcmp(summaryLatency.AnimalID, currentAnimal);
    animalData = summaryLatency(animalMask, :);
    
    % sort by NumSession
    animalData = sortrows(animalData, 'NumSession');
    
    % data for each freq
    legendHandles = [];
    legendLabels = {};
    
    for f = 1:nFreqs
        currentFreq = vibFreqs(f);
        freqMask = animalData.VibFreq == currentFreq;
        
        if any(freqMask)
            % get data for this freq
            freqData = animalData(freqMask, :);
            freqData = sortrows(freqData, 'NumSession');
            
            x = freqData.NumSession;
            y = freqData.RT_Median;
            amp = freqData.VibAmp_Max;
            
            % plotting
            h = plot(x, y, 'o-', ...
                     'Color', colors(f, :), ...
                     'MarkerSize', 4, ...
                     'MarkerFaceColor', colors(f, :), ...
                     'LineWidth', 1.5);
            
            % add amp labels over scatters 
            % for j = 1:length(x)
            %     text(x(j), y(j), sprintf('%.1f', amp(j)), ...
            %          'FontSize', 7, 'HorizontalAlignment', 'center', ...
            %          'VerticalAlignment', 'bottom');
            %end
            
            % save handles
            if f <= 6  % only show first 6 legends
                legendHandles(end+1) = h;
                legendLabels{end+1} = sprintf('%g Hz', currentFreq);
            end
        end
    end
    
    hold off;
    
    title(sprintf(currentAnimal), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Session Number', 'FontSize', 9);
    ylabel('Response Latency Median', 'FontSize', 9);
    grid on;
    
    
    
    % only show legend in the first subplot
    if i == 1 && ~isempty(legendHandles)
        legend(legendHandles, legendLabels, ...
               'Location', 'best', ...
               'NumColumns', min(3, ceil(nFreqs/3)), ...
               'FontSize', 8);
    end
end

sgtitle('Median Response Latency for Maximum Amplitude at Each Frequency', ...
        'FontSize', 14, 'FontWeight', 'bold');

% save zoom out
saveFigAsPNG("ResLatency_ZoomOut");

for i = 1:nAnimals
    subplot(rows, cols, i);
    ylim([0,0.5]) % Comment to zoom out, uncomment to zoom in
end

% save zoom in
saveFigAsPNG("ResLatency_ZoomIn");


%% Helper: Save Figure As PNG
function saveFigAsPNG(prefix)
% SAVE FIGURE AS PNG
% Save current MATLAB figure as PNG format with timestamp in filename
% 
% INPUTS:
%   prefix    - Optional prefix for filename (optional)
%
% OUTPUT:
%   Saves figure as PNG file with format: YYMMDD_HHMMSS.png
%   Example: 240123_143022.png

    figHandle = gcf;  % Use current figure
    savePath = "G:\Data\ProcessedData\Yudi\OperantConditioning";   % Default save path
    
    if nargin < 1
        prefix = '';
    end
    
    % Generate timestamp for filename using datetime
    % Format: YYMMDD_HHMMSS
    currentTime = datetime('now', 'Format', 'yyMMdd_HHmmss');
    timestampStr = char(currentTime);  % Convert datetime to char array
    
    % Build complete filename
    if isempty(prefix)
        filename = sprintf('%s.png', timestampStr);
    else
        filename = sprintf('%s_%s.png', prefix, timestampStr);
    end
    
    fullPath = fullfile(savePath, filename);
    
    % Ensure save directory exists
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end
    
    % Set figure export parameters
    set(figHandle, 'PaperPositionMode', 'auto');  % Maintain screen display size
    
    % Save as PNG format
    print(figHandle, fullPath, '-dpng', '-r300');  % 300 DPI resolution
    
    % Display confirmation message
    fprintf('Figure saved as: %s\n', fullPath);
end