% Analysis and plotting of multisession table data
T = resultsTable;
mouseList = unique(T.AnimalID);
subTable = T(:, {'AnimalID', 'Time'});
[sessionList, ~] = unique(subTable, 'rows');
%% Calculation of hit rate, false alarm rate by session per mouse



%% Ploting
% Response rate by session



%%  Latency analysis


