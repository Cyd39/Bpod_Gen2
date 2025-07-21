function [ax,YTick,YTickLab,varargout] = plotraster(ax, EventT,Var, Colour,yinc,ticklevel,varargin)
%RASTER creates a raster plot of aligned time-events (spikes, licks etc).

%       Inputs:
%       ax           = handle of axes for plotting raster plot
%       EventT      =   1-D cell array of NStim/NTrl x 1, each cell containing
%                       event time (in seconds) of one trial/stim
%       Var         =   nTrls x nVar matrix of stimuli variables (1st Var
%                       is outermost grouping variable (and grouped by colour)
%       Colour      =   matrix (n x 3) of RGB codes for colouring of the
%                       outermost grouping variable
%       yinc        = 1-D numerical array or empty array, indicating how
%                     many lines should be used to separate variables at
%                     different levels.
%       ticklevel   = integer index for YTickLab. Determine which variable
%                     will be outputted to YTickLab. 
%       Outputs:
%       ax           = handle of axes for plotted raster plot
%       YTick       = cell array with NVar + 1 cells
%                     each containing vector with tick mark indices at
%                     different levels (1, 2, 3, etc. variables)
%       YTickLab    = numerical array of nGroups x 1 of one of the stimulus 
%                     variables selected by `ticklevel`
%                     nGroup is the number of unique combinations of
%                     stimulus variables from Var
%       varargout:
%           - SortVar   = a sorted version of Var, which the order of the
%                           raster is based on.
%           - diffVar   = a 0/1 array with the same dimension as Var and
%                         SortVar, marking the trials in which a variable 
%                         changes with 1.
%           - YTickLim = numerical array of nGroups x 2, where (i,1) is the
%                       minimum y-position the ith group and (i,2) the maximum
%                       y-position. Great for illustrating separation
%                       between trials of different groups.

%  written on 31/01/2020 (Maurits van den Berg & Aaron Wong) 

NVar        =   size(Var,2);
NStim       =   size(Var,1);
UVar        =   unique(Var,'rows');
NUVar       =   size(UVar,1);

CVar        =   unique(Var(:,1));
NColor      =   length(CVar);

mksz        =   1;

if nargin < 5; yinc =  flip(10.^[1:NVar]);end
if isempty(yinc); yinc = flip(10.^[1:NVar]); end

for i =  1 : 2 : (nargin - 6)
    eval([num2str(varargin{i}),' = ', num2str(varargin{i+1}),';']);
end
%% Creating raster data
[SortVar,idx]     = sortrows(Var);
if nargout > 3; varargout{1} = SortVar; end
diffVar = SortVar(1:end-1,:)~=SortVar(2:end,:);
diffVar = [zeros(1,NVar);diffVar];
if nargout > 4; varargout{2} = diffVar; end

XX = [];YY = [];CC = [];

Ycnt	=	0;

Ypos    = nan(NStim,1);


for k=1:NStim

    stimNum =   idx(k);
    
    % get spike times and append to XX
    X		=	EventT{stimNum,1};
    XX      =   [XX; X(:)];

    % calculate next position
    Ycnt = Ycnt + 1;
    for v = 1:NVar  % add offset if stimulus is new
        if (diffVar(k,v)); Ycnt = Ycnt + yinc(v); end
    end
    
    % append y points to YY
    Y		=	ones(size(X)) * Ycnt;
    YY      =   [YY; Y(:)];
    Ypos(stimNum) = Ycnt;

    % index for color
    C       =   ones(size(X)) * find(CVar == Var(stimNum,1));
    CC      =   [CC; C(:)];
    
end

%% Plotting 
if (size(Colour,1) > 1) % plotting each color
    hold(ax,'off');
    for k=1:NColor
        pColour     =  Colour(k,:);
        sel = (CC == k);
        plot(ax,XX(sel),YY(sel),'.','MarkerFaceColor',pColour,'MarkerEdgeColor',pColour,'MarkerSize',mksz);hold(ax,'on');
    end
else % plotting single color
    if isempty(Colour)
        pColour     =  'k';
    else
        pColour     =  Colour;
    end
    plot(ax,XX,YY,'.','MarkerFaceColor',pColour,'MarkerEdgeColor',pColour,'MarkerSize',mksz)
end

%% Calculate YTicks at each level

YTick       =   cell(NVar+1,1);
YTickLim =   cell(NVar,1);

for v = 1:NVar
    tempUVar        =   unique(Var(:,1:v),'rows');
    tempNUVar       =   size(tempUVar,1);
    tempYTick       =   nan(tempNUVar,1);
    tempYTickLim    =   nan(tempNUVar,2);
    for k=1:tempNUVar
        sel = ones(NStim,1);
        for p = 1:v
            sel         =   sel & Var(:,p) == tempUVar(k,p);% & Var2 == UVar(k,2);
        end
        tempYTick(k) = mean(Ypos(sel));
        tempYTickLim(k,1) = min(Ypos(sel));
        tempYTickLim(k,2) = max(Ypos(sel));
    end
    YTick{v} = tempYTick;
    YTickLim{v} = tempYTickLim;
end
YTickLab = tempUVar(:,ticklevel);
YTick{end} = sort(Ypos);

if nargout > 5; varargout{3} = YTickLim{end}; end
end

