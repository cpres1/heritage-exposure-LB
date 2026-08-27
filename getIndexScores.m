%--------------------------------------------------------------------------
% NAME
%   getIndexScores.m
% PURPOSE
%   Calculates erosion and flooding heritage exposure index scores
% INPUT DATA
%   tbl1 - table containing the following columns:
%       featID - record identifiers
%       dist - distance to coastline (m)
%       elev - elevation (m)
%       changerate - shoreline change rate (m)
%       geol - surface geology (values = 1, 2, or 3)
%       transectID - Shoreline Monitor transect identifier (for indexing
%       purposes)
%   tbl2 - table containing the following columns:
%       transectID - Shoreline Monitor transect identifiers
%       mWH - mean wave height (m)
%   tbl3 - table containing the following columns:
%       transectID - Shoreline Monitor transect identifiers
%       Ru_capped - 90th percentiles of 2% wave runup elevation (m)
%       relative to 2024 mean still water level and capped to upper
%       adjacent
% RESULTS
%   indexResults - table containing primarily
%       indErosion - erosion index scores for each heritage record
%       indFlooding - flooding index scores for each heritage record
% SEE ALSO
%   getMWH.m (generates tbl2 data)
%   getRunup.m (generates tbl3 data)
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clear,clc,close all;

%% Load data (adjust paths/table names as needed)
tbl1 = readtable("Data\sampleData.xls"); % heritage data including distance, shoreline change rate, elevation, and surface geology

% optional - removes offshore and island records if included in your data
% tbl1 = tbl1(~contains(tbl1.On_Off, 'Offshore'),:);
% tbl1 = tbl1(~contains(tbl1.On_Off, 'Island'),:);

tbl2 = readtable("Data\mwhValues.xls"); % nearest mean wave height to each heritage record
tbl3 = readtable("Data\runupValuesCapped.xls"); % nearest 2% wave runup elevation value to each heritage record

%% Define variables for indicators

% Erosion
dist = tbl1.dist; % distance to coastline
chra = tbl1.changerate; % shoreline change rate
geol = tbl1.geology; % surface geology
mwh = zeros(height(tbl1),1); % mean wave height

for i = 1:height(tbl1)
    % find row in tbl2 that matches heritage record Shoreline Monitor ID
    rowInT2 = find(strcmp(tbl2.transectID, tbl1.transectID{i}));
    mwh(i) = tbl2.mWH(rowInT2);
end

% Flooding
elev = tbl1.elevation; % elevation
esl = 0.593939; % 1-in-100-yr extreme sea level expected 'today' (station 1998)
runup = zeros(heihgt(tbl1),1); % 2% wave runup elevation

for i = 1:height(tbl1)
    % find row in tbl3 that matches heritage record Shoreline Monitor ID
    rowInT2 = find(strcmp(tbl3.transectID, tbl1.transectID{i}));
    runup(i) = tbl3.Ru_capped(rowInT2);
end

% Define indicators for flood index indicators
indWaves = [];
indESLs = [];

for i = 1:height(tbl1)
    if elev(i) == 0 || elev(i) < 0
        indWaves(i) = runup(i)/0.1;
        indESLs(i) = esl/0.1;
    elseif elev(i) > 10 % automatically exclude records at elevations > 10 m
        indWaves(i) = NaN;
        indESLs(i) = NaN;
    else
        indWaves(i) = runup(i)/elev(i);
        indESLs(i) = esl/elev(i);
    end
end

%% Scaling

% Set all dist values > 500 m to null so they don't affect scaling
distExposed = [];

for i = 1:height(tbl1)
    if dist(i) > 500
        distExposed(i) = NaN;
    else
        distExposed(i) = dist(i);
    end
end

distExposed = distExposed(:);
distExposed = (-1)*distExposed;
distScaled = rescale(distExposed,1,5,'InputMin',-500,'InputMax',-10);

chra = (-1)*chra;
chraScaled = rescale(chra,1,5,'InputMin',-0.5,'InputMax',1);

mwhScaled = rescale(mwh,1,5,'InputMin',0.55,'InputMax',1.25);

distScaled = distScaled(:);
chraScaled = chraScaled(:);
geolScaled = geolScaled(:);

for i = 1:height(tbl1)
    if geol(i) == 1
        geolScaled(i) = 5;
    elseif geol(i) == 2
        geolScaled(i) = 3;
    else
        geolScaled(i) = 1;
    end
end

indWaves = indWaves(:);
indWavesScaled = rescale(indWaves,1,5,'InputMin',0,'InputMax',1);
indWavesScaled = indWavesScaled(:);

indESLs = indESLs(:);
indESLsScaled = rescale(indESLs,1,5,'InputMin',0,'InputMax',1);
indESLsScaled = indESLsScaled(:);

%% Calculate index scores

% Erosion
indErosion = []; % array to contain erosion index scores

for i = 1:height(tbl1)
    tf = isnan(distScaled(i));
    if tf == 1
        indErosion(i) = 0;
    else
        indErosion(i) = (distScaled(i)+chraScaled(i)+mwhScaled(i)+geolScaled(i))/4;
    end
end

indErosion = indErosion(:);

% Flooding
indFlooding = []; % array to contain flooding index scores

for i = 1:height(tbl1)
    tf = isnan(indWaves(i));
    if tf == 1
        indFlooding(i) = NaN;
    else
        indFlooding(i) = (indWavesScaled(i)+indESLsScaled(i))/2;
    end
end

indFlooding = indFlooding(:);

for i = 1:height(tbl1)
    tf1 = isnan(indFlooding(i));
    if tf1 == 1
        indFlooding(i) = 0;
    else
        indFlooding(i) = indFlooding(i);
    end
end

%% Save results
esl = repmat(esl,height(tbl1),1);
featID = tbl1.featID; % record ID
indexResults = table(featID,distScaled,chraScaled,geolScaled,mwhScaled,runup,esl,indWaves,indWavesScaled,indESLs,indESLsScaled,indErosion,indFlooding);
writetable(indexResults,"indexResults.csv")
