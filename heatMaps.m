%--------------------------------------------------------------------------
% NAME
%   heatMaps.m
% PURPOSE
%   Generates heat maps of annual non-tidal (storm surge) residual
%   variation for specified grid points
% INPUT DATA
%   TT - timetables for specified grid points containing:
%       TI - time (datetime)
%       SU - non-tidal residual (m)
% RESULTS
%   heat map figures
% SEE ALSO
%   requires package cbrewer2 available at: https://github.com/scottclowe/cbrewer2
%   timetables prepared in processData.m
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clear;clc;close all

stations_LB = [1994; 1995; 1996; 1997; 1998; 1999; 2000; 2001; 2002; 2003; 12605; 28315; 28383; 41759];

CT_RdBu = flipud(cbrewer2('div', 'RdBu', 36, 'spline'));
CT_RdBu(CT_RdBu<0) = 0;

for i = 1:length(stations_LB)
    station = stations_LB(i);

    load ("Data\"+num2str(station)+"_CODEC_ESLdata_dailymax.mat");
    TT = removevars(TT,["Water Level" "De-trended Water Level"]);

    x=linspace(1,366,366);

    Date_months = (datetime(1950,01,01 ):calmonths(1):datetime(2024,12,31))'; %lists all months from Jan 1979 - Dec 2018
    Date_years = (datetime(1950,01,01):calyears(1):datetime(2024,12,31))'; %lists all years from 1979-2018

    date_days = (datetime(1950,01,01 ):caldays(1):datetime(2024,12,31))'; %lists all days... 

    Date_months.Format = 'yyyy, MMM';
    Date_years.Format = 'yyyy'; 

    index = month(date_days) ==2 & day(29); 
    leapdates = date_days;

    TT_padded = [NaN(7,1); TT.Surge];
    TT_padded(index)=[];

    Stripes_Surges = reshape(TT_padded, [], length(Date_years));

    figure(i), clf, set(gcf, 'Color', [1 1 1]); %clears figure and sets background to white. 

    date_yearsvec = datevec(Date_years);

    imagesc(x',date_yearsvec(:,1) ,  Stripes_Surges') % 2D image with scaled colour plot

    colormap([0.4 0.4 0.4; CT_RdBu])  % need to have defined the Colour Map CT_RdBu earlier, or replace with , e.g. Parula
    clim([-0.35 0.36]) % colorbar axis limis

    shading flat

    h= colorbar;
    set(get(h,'label'),'string','Surge (m)');
    h.Title.Rotation = 90;  % rotate the colorbar title by 90 
    h.FontSize =12;
    h.TickDirection ='out';
    h.TickLength = 0.02;
    h.Ticks = [-0.3 -0.2 -0.1 -0.05 0 0.05 0.1 0.2 0.3];

    xlabel('Time (Days)', 'FontSize', 16, 'FontWeight', 'bold');
    ylabel('Time (Years)', 'FontSize', 16, 'FontWeight', 'bold');
    title("Seasonal Variation in Surge Values at Station "+num2str(station)+", for Years 1950-2024",'FontSize',16,'FontWeight','bold')
end