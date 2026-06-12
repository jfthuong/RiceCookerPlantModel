%DEMO_COSIM  Run a 2-hour rice-cooker co-simulation and plot key signals.
%
%   Signals plotted
%   ---------------
%   1. Pot temperature  [degC]
%   2. Heater power     [%]
%   3. Water remaining  [% of initial mass]
%
%   Usage:
%       cd Simulink
%       demo_cosim

%% ---- Setup -------------------------------------------------------------
MODEL_NAME   = 'RiceCookerPlant';
STOP_TIME    = 9000;   % 2.5 hours [s]
STEP_SIZE    = 1;      % [s] — matches FMU period

thisDir = fileparts(mfilename('fullpath'));
% FMU folder must be on path before sim() runs.
fmuDir  = fullfile(thisDir, '..', 'fmu');
addpath(fmuDir);
addpath(thisDir);
slxFile = fullfile(thisDir, [MODEL_NAME '.slx']);
if ~exist(slxFile, 'file')
    fprintf('Building %s.slx ...\n', MODEL_NAME);
    orig = cd(thisDir);
    build_model(MODEL_NAME);
    cd(orig);
end
addpath(thisDir);

%% ---- Simulation input --------------------------------------------------
simIn = Simulink.SimulationInput(MODEL_NAME);
simIn = setModelParameter(simIn, ...
    'StartTime',      '0', ...
    'StopTime',       num2str(STOP_TIME), ...
    'Solver',         'ode23', ...
    'MaxStep',        num2str(STEP_SIZE), ...
    'SaveOutput',     'on', ...
    'SaveFormat',     'Dataset', ...
    'OutputSaveName', 'yout');

% All inports — btnStartStop=1 at second cycle, then released: controller is
% edge-sensitive (one-shot press to toggle heater on).
% Dataset ordered by port index (positional, not name-matched).
boolPorts = {'btnStartStop','btnDelay','btnSetTime','isLidOpen'};
inportOrder = { ...
    'tempExt',      20; ...
    'volWaterInit', 0.5; ...
    'volRiceInit',  3e-4; ...
    'btnStartStop', 1; ...
    'btnDelay',     0; ...
    'btnSetTime',   0; ...
    'isLidOpen',    0};

ds = Simulink.SimulationData.Dataset;
for k = 1:size(inportOrder, 1)
    name = inportOrder{k,1};
    val  = inportOrder{k,2};
    if ismember(name, boolPorts)
        if strcmp(name, 'btnStartStop')
            % Press only at second cycle, then release
            data = logical([0; 1; 0]);
            times = [0; STEP_SIZE; 2*STEP_SIZE];
        else
            % Other boolean ports held constant
            data = logical([val; val]);
            times = [0; STOP_TIME];
        end
    else
        data = double([val; val]);
        times = [0; STOP_TIME];
    end
    ts   = timeseries(data, times);
    ts.Name = name;
    ds = addElement(ds, ts);   % positional
end
simIn = setExternalInput(simIn, ds);

%% ---- Run ---------------------------------------------------------------
fprintf('Running co-simulation (%g s) ...\n', STOP_TIME);
out = sim(simIn);
fprintf('Done.\n');

%% ---- Extract signals ---------------------------------------------------
% Outport order: 1:tempC 2:massWaterKg 3:massWaterPct 4:volRiceM3
%                5:volRicePct 6:heaterPowerPct 7:colorLED 8:displayText
t         = out.yout{1}.Values.Time / 60;   % minutes
tempC     = out.yout{1}.Values.Data;
heaterPct = out.yout{6}.Values.Data;
waterPct  = out.yout{3}.Values.Data;

%% ---- Plot --------------------------------------------------------------
fig = figure('Name', 'Rice Cooker Co-Simulation', 'NumberTitle', 'off', ...
    'Position', [100 100 900 700]);

subplot(3,1,1);
plot(t, tempC, 'r-', 'LineWidth', 1.5);
yline(100, 'k--', '100 °C boiling',  'LabelHorizontalAlignment','left');
yline(70,  'g--', '~70 °C keep warm', 'LabelHorizontalAlignment','left');
xlabel('Time (min)');
ylabel('Temperature (°C)');
title('Pot Temperature');
grid on;

subplot(3,1,2);
plot(t, heaterPct, 'b-', 'LineWidth', 1.5);
ylim([-5 105]);
xlabel('Time (min)');
ylabel('Power (%)');
title('Heater Power');
grid on;

subplot(3,1,3);
plot(t, waterPct * 100, 'c-', 'LineWidth', 1.5);
xlabel('Time (min)');
ylabel('Water remaining (%)');
title('Water Remaining');
grid on;

sgtitle('Rice Cooker — Controller + Plant Co-Simulation');

%% ---- Export -----------------------------------------------------------
pngFile = fullfile(thisDir, 'cosim_result.png');
exportgraphics(fig, pngFile, 'Resolution', 150);
fprintf('Plot saved to: %s\n', pngFile);
