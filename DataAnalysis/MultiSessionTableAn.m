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

% calculation of response rate for each stimulus(including catch trial as false alarm rate)
n_response = T.N_ValidRT; 
n_trial = T.NTrials; % NTrials is number of trials for each stimulus/catch trial
res_rate = n_response ./ n_trial; % response rate for each stimulus/catch trial
T.ResRate = res_rate;

animals = unique(T.AnimalID);
nAnimals = length(animals);
% sl: session list
[sl, ~] = unique(T(:, {'AnimalID', 'DateTime'}), 'rows');
% remove NaT DateTime
validRows = ~isnat(sl.DateTime);
sl = sl(validRows, :);

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
%% Plotting
% false alarm rate
figure('Position', [100, 100, 1300, 600]);
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
    x = sl.NumSession(mask);
    y = sl.FalseAlarmRate(mask);
    
    % sort by NumSession
    [x_sorted, sort_idx] = sort(x);
    y_sorted = y(sort_idx);
    
    plot(x_sorted, y_sorted, 'o-', ...
         'Color',animalColors(i, :),...
         'MarkerSize', 3, ...
         'MarkerFaceColor', animalColors(i, :), ...
         'LineWidth', 2, ...
         'DisplayName', char(animals{i}));
end

subplot(2, 1, 1);
xlabel('Session Number', 'FontSize', 14);
ylabel('False Alarm Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;

subplot(2, 1, 2);
xlabel('Session Number', 'FontSize', 14);
ylabel('False Alarm Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;

sgtitle('False Alarm Rate Progression', 'FontSize', 14);
%% overall response rate
figure('Position', [100, 100, 1500, 600]);
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
    x = sl.NumSession(mask);
    y = sl.ResponseRate(mask);
    
    % sort by NumSession
    [x_sorted, sort_idx] = sort(x);
    y_sorted = y(sort_idx);
    
    plot(x_sorted, y_sorted, 'o-', ...
         'Color', animalColors(i, :), ...
         'MarkerSize', 3, ...
         'MarkerFaceColor', animalColors(i, :), ...
         'LineWidth', 2, ...
         'DisplayName', char(animals{i}));
end

subplot(2, 1, 1);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;

subplot(2, 1, 2);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);

hold off;
sgtitle('Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% "easy" stimuli response rate
figure('Position', [100, 100, 1500, 800]);

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
    x = sl.NumSession(mask);
    y = sl.ResponseRateEasy(mask);
    
    % sort by NumSession
    [x_sorted, sort_idx] = sort(x);
    y_sorted = y(sort_idx);
    
    plot(x_sorted, y_sorted, 'o-', ...
         'Color', animalColors(i, :), ...
         'MarkerSize', 3, ...
         'MarkerFaceColor', animalColors(i, :), ...
         'LineWidth', 2, ...
         'DisplayName', char(animals{i}));
end

subplot(2, 1, 1);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;

subplot(2, 1, 2);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;
sgtitle('Easiest Stimuli(All Freq) Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% "easiest stimuli response rate"
figure('Position', [100, 100, 1500, 800]);

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
    x = sl.NumSession(mask);
    y = sl.ResponseRateEasiest(mask);
    
    % sort by NumSession
    [x_sorted, sort_idx] = sort(x);
    y_sorted = y(sort_idx);
    
    plot(x_sorted, y_sorted, 'o-', ...
         'Color', animalColors(i, :), ...
         'MarkerSize', 3, ...
         'MarkerFaceColor', animalColors(i, :), ...
         'LineWidth', 2, ...
         'DisplayName', char(animals{i}));
end

subplot(2, 1, 1);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;

subplot(2, 1, 2);
xlabel('Session Number', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);
hold off;
sgtitle('Easiest Stimulus(Hightest Freq) Response Rate Progression', 'FontSize', 14, 'FontWeight', 'bold');
%% Plot by DateTime
figure('Position', [100, 100, 1500, 800]);

animalColors = lines(nAnimals);  

subplot(2, 1, 1);
ax1 = gca;
hold(ax1, 'on');

subplot(2, 1, 2);
ax2 = gca;
hold(ax2, 'on');

allDatetimes = [];

for i = 1:nAnimals
    if i == 1 || i == 3 
        axes(ax1);
        currentAx = ax1;
    else
        axes(ax2);
        currentAx = ax2;
    end

    mask = strcmp(sl.AnimalID, animals{i});
    
    x = sl.DateTime(mask);
    y = sl.ResponseRateEasy(mask);
    
    % 收集所有DateTime
    allDatetimes = [allDatetimes; x];
    
    [x_sorted, sort_idx] = sort(x);
    y_sorted = y(sort_idx);
    
    plot(x_sorted, y_sorted, 'o-', ...
         'Color', animalColors(i, :), ...
         'MarkerSize', 3, ...
         'MarkerFaceColor', animalColors(i, :), ...
         'LineWidth', 2, ...
         'DisplayName', char(animals{i}));
end

% 设置子图1
axes(ax1);
xlabel('Date & Time', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);

% 优化日期显示
datetick('x', 'mm/dd', 'keepticks');
xlim([min(allDatetimes)-hours(12), max(allDatetimes)+hours(12)]);
hold off;

% 设置子图2
axes(ax2);
xlabel('Date & Time', 'FontSize', 14);
ylabel('Response Rate', 'FontSize', 14);
grid on;
legend('Location', 'best', 'FontSize', 10);

% 优化日期显示
datetick('x', 'mm/dd', 'keepticks');
xlim([min(allDatetimes)-hours(12), max(allDatetimes)+hours(12)]);
hold off;

sgtitle('Easiest Stimuli Response Rate Progression (by DateTime)', 'FontSize', 14, 'FontWeight', 'bold');

%%  Latency analysis


