%--------------------------------------------------------------------------
% NAME
%   getRunup.m
% PURPOSE
%   Calculates nearest 90th percentile of 2% wave runup elevation values relative to still water level for points in a
%   given dataset
% INPUT DATA
%   shorelinePoints - table containing the following columns:
%       lat - latitude coordinates of points for which nearest runup values
%       are to be calculated
%       lon - longitude coordinates of points for which... "
%       bs - beach slope at location (degrees), here calculated from Slope 
%       raster layer in ArcGIS Pro from SRTM 1-Arc second DEM
%   waves - nc file containing time series of following parameters (hourly,
%   1950-2024):
%       TI - time (any units - will be converted as part of data preparation)
%       Hs - significant wave height (m)
%       Tp - peak wave period (s)
%   waveGridLocations - table containing the following columns:
%       wavesLat - latitude coordinates of gird points in waves nc data
%       wavesLon - longitude coordinates... "
%       depth - depth (m) at grid point locations, here calculated using
%       GEBCO_2024 Grid bathymetric data
%   constants -
%       g - gravity (m/s^2)
%       swl - mean still water level (m), calculated as mean level of 2024
%       from grid point '1998' in Muis et al. (2020) dataset (see
%       processData.m)
% RESULTS
%   runupValues - results table
%   runupValuesCapped - results table capped to upper adjacent
% REFERENCES
%   The code from lines 123-156 is taken almost entirely from
%   ct_beachvulnerability.m, published June 2020 by Ian Townend as part of
%   CoastalSEA (available at: https://github.com/CoastalSEA).
%   For more details, see: 
%       Townend, I.H., 2021, CoastalTools manual, CoastalSEA, UK, pp83,
%       www.coastalsea.uk.
% SEE ALSO
%   calls the following functions, also available as part of
%   CoastalSEA:
%       shoaling.m (calls embedded celerity.m)
%       runup.m
%           line 26 originally: beta = 1./bs
%           replaced with: bsRad = deg2rad(bs);
%                          beta = tan(bsRad);
%           to work with project slope data
%   results used in getIndexScores.m
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clear; clc; close all;

%% Load data (adjust paths/table names as needed)

shorelinePoints = readtable("Data\shorelinePoints.xls"); % Shoreline Monitor transect coordinates (lat, lon) and beach slope at location
waveGridLocations = readtable("Data\waveDataFinal.xls"); % Grid coordinates (lat, lon) and depth at location
waveGridLocations = waveGridLocations(~isnan(waveGridLocations.depth), :);
waves = "\Data\med-hcmr-wav-rean-h_VHM0-VMDR-VTPK_34.58E-36.29E_32.40N-34.90N_1985-01-01-2023-05-31_(1).nc"; % significant wave height, peak wave period
ncdisp(waves)

lon = ncread(waves,"longitude");
lat = ncread(waves,"latitude");

[LonGrid, LatGrid] = meshgrid(lon,lat);
LonGrid_d = double(LonGrid);
LatGrid_d = double(LatGrid);

%% Prepare wave data
wavesTime = ncread(waves,"time"); 
TI = datetime(wavesTime,'ConvertFrom','posixtime');
Hs = ncread(waves,'VHM0');

% for each lon/lat pair, check if first Hs value is NaN (i.e. land cell)
Hs_first = Hs(:,:,1)';
validMask = ~isnan(Hs_first); % true if Hs has data.

% create depth grid matching nc grid
latVec = double(waveGridLocations.wavesLat(:));
lonVec = double(waveGridLocations.wavesLon(:));
depthVec = double(-waveGridLocations.depth(:));

F = scatteredInterpolant(lonVec, latVec, depthVec, 'nearest', 'nearest');

depthGrid = F(LonGrid_d,LatGrid_d);

%% For each Shoreline Monitor transect, calculate 2% wave runup elevation + still water level for each wave timestep

% initialise arrays to store final results
Ru_pct = zeros(height(shorelinePoints),1);
bs = zeros(height(shorelinePoints),1);
waveDepth = zeros(height(shorelinePoints),1);

g = 9.81; % gravity
swl = 0.25909; % still water level

nRows1 = height(shorelinePoints);

for i = 1:nRows1

    targetLon = shorelinePoints.Intersect_lon(i);
    targetLat = shorelinePoints.Intersect_lat(i);

    dist = hypot(LonGrid - targetLon, LatGrid - targetLat);
    dist(~validMask) = Inf; % if validMask is false, set dist to Inf
    
    % find distance to nearest valid grid point
    [~, idx] = min(dist(:));
    [iy, ix] = ind2sub(size(dist), idx);

    Hsi = ncread(waves,"VHM0",[ix iy 1],[1 1 Inf]); Hsi = Hsi(:); % significant wave height
    Tp = ncread(waves,"VTPK",[ix iy 1],[1 1 Inf]); Tp = Tp(:); % peak period
    
    bs(i) = shorelinePoints.Slope(i); % beach slope

    waveDepth(i) = depthGrid(iy,ix); % depth at lat(iy), lon(ix)

    % join all variables in timetable
    TT = timetable(TI,Hsi,Tp,'VariableNames',["Significant wave height (m)","Peak wave period (s)"]);
    TT.Depth = repmat(waveDepth(i),height(TT),1);
    TT.Slope = repmat(bs(i),height(TT),1);
    TT.swl = repmat(swl,height(TT),1);

    % compute runup for every timestep

    nRows2 = height(TT);

    % initialise arrays to store results
    Hs0 = zeros(nRows2,1); % 'effective' deepwater wave height (m)
    Ru2 = zeros(nRows2,1); % 2% runup (m)
    Ru2_swl = zeros(nRows2,1); % 2% runup made relative to swl (m)

    for j = 1:nRows2

        % calculate 'effective' deep water wave height Hs1
        Hs_j = TT.("Significant wave height (m)")(j);
        Tp_j = TT.("Peak wave period (s)")(j);
        dep = TT.Depth(j);
        dep_offshore = 100; % assumed deep water depth
        Hs0(j) = shoaling(Hs_j,Tp_j,dep,dep_offshore); % effective deep water wave height (at 100 m)

        % compute 2% runup
        bs_j = TT.Slope(j);
        swl_j = TT.swl(j);
        Ru2(j) = runup(bs_j,Hs0(j),Tp_j);

        % make relative to swl
        Ru2_swl(j) = Ru2(j)+swl_j;
    end
    
    % store results in existing timetable
    TT = addvars(TT,Hs0,Ru2,Ru2_swl);

    % compute 90th percentile of Ru2_swl
    Ru_pct(i) = prctile(Ru2_swl,90,1);
    disp(['Row ',num2str(i),': Done. bs: ',num2str(bs(i)),'. Wave depth: ',num2str(waveDepth(i)),' Runup value: ',num2str(Ru_pct(i)),'.'])
end

%% save final results table
transectID = shorelinePoints.transect_id;

Ru_results = table(transectID,Ru_pct);
writetable(Ru_results,"\Data\runupValues.xls")

%% Cap runup values after upper adjacent
Ru_results = readtable("Data\runupValues.xls");
%upper adjacent = 1.515 m (adjust according to your results)
Ru_capped = zeros(height(Ru_results.Ru_pct),1);

for i = 1:height(Ru_results)
    Ru = Ru_results.Ru_pct(i);
    if Ru > 1.515
        Ru_capped(i) = 1.515;
    else
        Ru_capped(i) = Ru;
    end
end

transectID = shorelinePoints.transect_id;

T = table(transect,Ru_results.Ru_pct,Ru_capped);
writetable(T,"\Data\runupValuesCapped.xls");