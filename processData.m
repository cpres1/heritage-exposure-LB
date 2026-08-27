%--------------------------------------------------------------------------
% NAME
%   processData.m
% PURPOSE
%   Creates timetables of total water levels de-trended total water levels,
%   and non-tidal (storm surge) residuals for set of given grid points
% INPUT DATA
%   filein - nc file containing following water level parameters:
%       TI - time (any units - will be converted to datetime)
%       WL - total water level (m)
%       SU - non-tidal residual (m)
%       stations - grid point identifiers
% RESULTS
%   .mat files in format [grid point ID]_CODEC_ESLdata_dailymax.mat" for
%   each specified grid point
% SEE ALSO
%   results used in heatMaps.m and eslAnalysis.m
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clc;clear;close all

% Load data (adjust paths as needed)
filein = "reanalysis_surge_dailymax_1950_01_v2.nc";
ncdisp(filein)
stations_all = ncread(filein,'stations');

% Stations on the continental shelf
stations_LB = [1994; 1995; 1996; 1997; 1998; 1999; 2000; 2001; 2002; 2003; 12605; 28315; 28383; 41759];

%% Find mean WL from 2024 (for de-trending total water levels later).

mean_WL=[];
for i = 1:length(stations_LB)
    station = stations_LB(i);
    ind = find(stations_all == station);
    
    TT_2024 = [];
    for y = 2024
        for m = 1:12
            filein = "Data\reanalysis_waterlevel_dailymax_" + num2str(y) + "_" + sprintf('%02d',m) +"_v2.nc";

            WL_2024 = ncread(filein, 'waterlevel',[ind 1],[1 Inf]);

            d = ncread(filein,'time');
            TI = datetime(y,m,1)+ double(d);

            tt = timetable(TI,WL_2024','VariableNames',"WL");

            TT_2024 = [TT_2024; tt];
        end
    end

    % eliminate warm-up periods, first week of 2024. 
    t1 = datetime(2024,1,7,23,59,59);
    TT_2024(TT_2024.TI <= t1,:) = [];

    mean_WL_2024 = mean(TT_2024.WL);
    disp("Mean WL for station "+num2str(station)+" is "+num2str(mean_WL_2024)+".")

    mean_WL = [mean_WL,mean_WL_2024];
end

mean_WL = mean_WL(:);

%% Create timetables for each station.

for i = 1:length(stations_LB)
    station = stations_LB(i);
    ind = find(stations_all == station);

    TT = [];

    for y = 1950:2024
        for m = 1:12
            filein_su = "dailymax-v2-1950-2024\reanalysis_surge_dailymax_"+num2str(y)+"_"+sprintf('%02d',m)+"_v2.nc";
            filein_wl = "dailymax-v2-1950-2024\reanalysis_waterlevel_dailymax_"+num2str(y)+"_"+sprintf('%02d',m)+"_v2.nc";

            SU = ncread(filein_su,'surge',[ind 1],[1 Inf]); SU = SU(:);
            WL = ncread(filein_wl,'waterlevel',[ind 1],[1 Inf]); WL = WL(:);
            
            WLd = detrend(WL, 'omitnan');
            WLd = WLd + mean_WL(i);

            d = ncread(filein_su,'time');
            TI = datetime(y,m,1)+ double(d);

            tt = timetable(TI,SU,WL,WLd,'VariableNames',["Surge","Water Level","De-trended Water Level"]);

            TT = [TT;tt];

        end
    end
    % eliminate warm-up periods, first week of 1950. 
    t1 = datetime(1950,1,7,23,59,59);
    TT(TT.TI <= t1,:) = [];
    
    save("Data\"+num2str(station)+"_CODEC_ESLdata_dailymax.mat","TT")
    disp("Timetable for station "+num2str(station)+" done.")
end