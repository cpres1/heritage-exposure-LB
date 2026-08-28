%--------------------------------------------------------------------------
% NAME
%   getMWH.m
% PURPOSE
%   Calculates mean wave height values for points in a given dataset
% INPUT DATA
%   shorelinePoints - table containing the following columns:
%       transectID - point identifier
%       lat - latitude coordinates of points for which nearest runup values
%       are to be calculated
%       lon - longitude coordinates of points for which... "
%   waves - nc file containing time series of following parameters (hourly,
%   1950-2024):
%       TI - time (any units - will be converted as part of data preparation)
%       Hs - significant wave height (m)
%   waveGridLocations - table containing the following columns:
%       wavesLat - latitude coordinates of gird points in waves nc data
%       wavesLon - longitude coordinates... "
% RESULTS
%   mwhValues - table containing the following columns:
%       transectID - Shoreline Monitor transect identifiers
%       mWH - mean wave height (m)
% SEE ALSO
%   results used in getIndexScores.m
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clear; clc; close all;

%% Load data (adjust paths/table names as needed)

shorelinePoints = readtable("Data\shorelinePoints.xls"); % Shoreline Monitor transect coordinates (lat, lon)
waveGridLocations = readtable("Data\waveCoordinates.xls"); % Grid coordinates (lat, lon)
waves = "Data\med-hcmr-wav-rean-h_VHM0-VMDR-VTPK_34.58E-36.29E_32.40N-34.90N_1985-01-01-2023-05-31_(1).nc"; % significant wave height, peak wave period
ncdisp(waves)

%% Define significant wave height variable Hs
lon = ncread(waves,"longitude");
lat = ncread(waves,"latitude");

[LonGrid, LatGrid] = meshgrid(lon,lat);

Hs = ncread(waves,'VHM0');

% for each lon/lat pair (grid cell), check if the first Hs value is NaN
% (i.e. land cell)
Hs_first = Hs(:,:,1)';
validMask = ~isnan(Hs_first); % true if Hs has data

%% For each Shoreline Monitor transect, calculate nearest mean wave height
mWH = zeros(height(shorelinePoints),1);

nRows1 = height(shorelinePoints);
for i = 1:nRows1
    targetLon = shorelinePoints.Intersect_lon(i);
    targetLat = shorelinePoints.Intersect_lat(i);

    dist = hypot(LonGrid - targetLon, LatGrid - targetLat);
    dist(~validMask) = Inf; % if validMask is false, set dist to Inf

    % find distance to nearest valid grid point
    [~, idx] = min(dist(:));
    [iy, ix] = ind2sub(size(dist), idx);

    Hsi = ncread(waves,"VHM0",[ix iy 1],[1 1 Inf]); Hsi = Hsi(:); % extract Hs time series at nearest valid location
    mWH(i) = mean(Hsi); % calculate mean Hs
    disp(['Row ',num2str(i),': Done.'])
end

%% Save results
transectID = shorelinePoints.transectID;
mwhValues = table(transectID,mWH);
writetable(mwhValues,"Data\mwhValues.xls")

