
% ExtractTimeStamps
Session_tbl = ExtractTimeStamps(SessionData);

% align timing to stimulus onset
n_stim = height(Session_tbl);
LickOn = cell(n_stim,1);
LickOff = cell(n_stim,1);

for ii = 1:height(Session_tbl)
    LickOn{ii} = Session_tbl.LickOn{ii} - Session_tbl.Stimulus(ii,1);
    LickOff{ii} = Session_tbl.LickOff{ii} - Session_tbl.Stimulus(ii,1);
end

% histogram
histogram([LickOn{:}],-5:0.05:2)

%% raster plot
fig = figure;
ax = axes("Parent",fig);
uInt = unique(Session_tbl.AudIntensity);
nInt= length(uInt);
Colour = turbo(nInt);%[0,0,0];
[ax,YTick,YTickLab] = plotraster(ax, LickOn,Session_tbl.AudIntensity, Colour,[10],1);
ax.YTick = YTick{1};
ax.YTickLabel = YTickLab;
xlim(ax,[0,1])