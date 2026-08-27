%--------------------------------------------------------------------------
% NAME
%   eslAnalysis.m
% PURPOSE
%   Estimate the effect of sea-level rise on the return period of a
%   1-in-100-year extreme sea level by 2050
% INPUT DATA
%   TT - timetables for specified grid points containing:
%       TI - time (datetime)
%       dWL - de-trended total water levels (m)
%   projf - table containing the following columns:
%       Year - years (2020 to 2050)
%       x5th percentile - 5th percentile of sea-level rise projection (m)
%       x50th percentile - 5th percentile of sea-level rise projection (m)
%       x95th percentile - 5th percentile of sea-level rise projection (m)
% RESULTS
%   RPslr - array containing return periods of current 1-in-100-year
%   extreme sea level event under 5th, 50th, and 95th percentiles of
%   sea-level rise projection
% REFERENCES
%   based on standard methods for extreme value analysis in flood risk 
%   assessment
%   code specifically based on SOES6011 Practical 5 (tutorial available at:
%   http://www.youtube.com/@Ivanhaigh123)
% SEE ALSO
%   timetables prepared in processData.m
%
% Author: Celia Prescott
%--------------------------------------------------------------------------

clc;clear;close all;

station = 1995; % choose station
load ("Data\"+num2str(station)+"_CODEC_ESLdata_dailymax.mat");

% extract annual maxima
TTam = retime(TT,'yearly','max');

RP = [0.5 1 2 5 10 25 50 100 200 1000 10000]; % define return periods

P = 1-exp(-1./RP); 

% fit to GEV distribution
par_GEV = fitdist(-TTam.(3),'gev');

RLgev = gevinv(P,par_GEV.k,par_GEV.sigma,par_GEV.mu);

RLgev = RLgev*-1;

% load SLR projection data (uncomment for scenario you want)
% projf = "Data\IPCC_AR6_SLR_Projection_SSP126.csv"; 
projf = "Data\IPCC_AR6_SLR_Projection_SSP245.csv";
% projf = "Data\IPCC_AR6_SLR_Projection_SSP370.csv"; 
% projf = "Data\IPCC_AR6_SLR_Projection_SSP585.csv";

opts = detectImportOptions(projf);
preview(projf,opts)

T = readtable(projf,opts);

% Extract years variable
TEN_YR = T.(1);

% Extract all other variables to an array PR
PR = T{:,2:4};

% Extract SLR magnitude for all percentiles for 2050
i = TEN_YR == 2050;
idx = find(i);

SLR(1,1) = PR(idx,1);
SLR(2,1) = PR(idx,2);
SLR(3,1) = PR(idx,3);

% plot return level curves, and how the frequency of a 1 in 100 event changes with SLR by 2050
figure('units','normalized','position',[0.1 0.1 0.8 0.8]); clf, set(gcf,'Color',[1 1 1])
tiledlayout(1,1)
nexttile
semilogx(RP,RLgev, 'Color','#4477aa', 'linewidth', 2);
hold on
semilogx(RP,RLgev+SLR(1,1), 'Color','#ccbb44','linewidth', 2)
semilogx(RP,RLgev+SLR(2,1),'color','#ee6677','linewidth', 2)
semilogx(RP,RLgev+SLR(3,1), 'Color', '#aa3377','linewidth', 2)
i = RP == 100;
yline(RLgev(i),'linewidth',2,'LineStyle','--','Color','black')
hold on
plot(5.7971,0.5223,'kx','MarkerSize',20,'LineWidth',1.5)  % adds a marker at the point (x_pos,y_pos)
hold on
plot(100,0.5223,'kx','MarkerSize',20,'LineWidth',1.5)
xlabel('Return Period (yr)','FontSize',16,'FontWeight','bold')
ylabel('Return Level (m)','FontSize',16,'FontWeight','bold')
xlim([0,250])
xticks([1 10 100])
xticklabels([1 10 100])
box on
grid on
set(findobj(gcf,'type','axes'),'fontsize',16,'linewidth',2,'fontweight','bold')

legend('Today','5th percentile - 2050','50th percentile - 2050','95th percentile - 2050','1-in-100-year event','location','best','fontsize',16)
