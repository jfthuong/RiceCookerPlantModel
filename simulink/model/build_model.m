function build_model(modelName)
%BUILD_MODEL Programmatically builds the RiceCookerPlant Simulink model.
%
%   Creates RiceCookerPlant.slx in this script directory with:
%     - 7 inports : tempExt, volWaterInit, volRiceInit,
%                   btnStartStop, btnDelay, btnSetTime, isLidOpen
%     - 8 outports : tempC, massWaterKg, massWaterPct, volRiceM3, volRicePct,
%                    heaterPowerPct, colorLED, displayText (6-element vector)
%     - 1 MATLAB Function block running rice_cooker_physics.m
%     - 3 Integrator blocks: T (IC=20), m_abs (IC=0), m_evap (IC=0)
%     - 1 FMU Co-simulation block: Controller_MainControl (step=1s)
%
%   Wiring:
%     IntegT/m_abs/m_evap outputs -> RicePhysics inputs (T, m_abs, m_evap)
%     tempExt/volWaterInit/volRiceInit  -> RicePhysics inputs
%     Controller.heaterPowerPct        -> RicePhysics powerPct input
%     T_state (integrator) -> Controller.tempPot_Controller
%     button/lid inports   -> Controller inputs
%     RicePhysics derivative outputs   -> integrator inputs
%     RicePhysics passthrough outputs  -> plant outports
%     Controller outputs               -> controller outports

if nargin < 1
    modelName = 'RiceCookerPlant';
end

thisDir = fileparts(mfilename('fullpath'));
slxPath = fullfile(thisDir, [modelName '.slx']);

% --- Clean slate ---------------------------------------------------------
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist(slxPath, 'file')
    delete(slxPath);
end

new_system(modelName, 'Model');
load_system(modelName);

% --- FMU path (relative to this script's directory) ----------------------
fmuDir  = fullfile(thisDir, '..', '..', 'fmu-controller');
addpath(fmuDir);   % required by built-in/FMU: folder must be on path

% --- Inports -------------------------------------------------------------
% tempExt, volWaterInit, volRiceInit: plant continuous inputs
% btnStartStop, btnDelay, btnSetTime, isLidOpen: controller discrete inputs
plantInNames = {'tempExt','volWaterInit','volRiceInit'};
for k = 1:numel(plantInNames)
    y = 30 + 60*(k-1);
    add_block('simulink/Sources/In1', [modelName '/' plantInNames{k}], ...
        'Position', [30 y 60 y+20]);
end
ctrlInNames = {'btnStartStop','btnDelay','btnSetTime','isLidOpen'};
for k = 1:numel(ctrlInNames)
    y = 30 + 60*(numel(plantInNames) + k - 1);
    add_block('simulink/Sources/In1', [modelName '/' ctrlInNames{k}], ...
        'Position', [30 y 60 y+20]);
end

% --- Plant core (RicePhysics + Integrators + Goto/From) -----------------
build_plant_core(modelName);   % scale = 1.0 (compact)

% --- Controller FMU (Co-Simulation, step=1 s) ----------------------------
% FMU inputs  (port order from modelDescription.xml):
%   1: isLidOpen_Controller  2: tempPot_Controller  3: btnStartStop
%   4: btnDelay              5: btnSetTime
% FMU outputs (3 Simulink ports):
%   1: heaterPowerPct (Real)  2: colorLED (Integer)
%   3: displayText (6-element Integer vector for displayText[0..5])
add_block('built-in/FMU', [modelName '/Controller'], ...
    'Position', [430 210 560 380], ...
    'ForegroundColor', 'white', ...
    'BackgroundColor', 'black', ...
    'FMUName', 'Controller_MainControl.fmu');

% Extra From block: feeds T_state (from integrator) to controller.
% Avoids algebraic loop — uses the delayed integrated temperature.
add_block('simulink/Signal Routing/From', [modelName '/FromT_ctrl'], ...
    'GotoTag','T_state', 'Position', [150 220 180 240]);

% --- Outports ------------------------------------------------------------
% Plant physics outputs
outNames = {'tempC','massWaterKg','massWaterPct','volRiceM3','volRicePct'};
for k = 1:numel(outNames)
    y = 200 + 40*(k-1);
    add_block('simulink/Sinks/Out1', [modelName '/' outNames{k}], ...
        'Position', [620 y 650 y+20]);
end
% Controller outputs (3 ports: scalar Real, scalar Integer, 6-elem Integer)
ctrlOutNames = {'heaterPowerPct','colorLED','displayText'};
for k = 1:numel(ctrlOutNames)
    y = 200 + 40*(numel(outNames) + k - 1);
    add_block('simulink/Sinks/Out1', [modelName '/' ctrlOutNames{k}], ...
        'Position', [620 y 650 y+20]);
end

% --- Wiring --------------------------------------------------------------
% Plant inports into RicePhysics inputs 4, 6, 7
% (internal state feedback 1-3 is handled by build_plant_core)
%   input 4: tempExt
%   input 5: powerPct <- Controller.heaterPowerPct (wired below)
%   input 6: volWaterInit
%   input 7: volRiceInit
add_line(modelName, 'tempExt/1',      'RicePhysics/4', 'autorouting','on');
add_line(modelName, 'volWaterInit/1', 'RicePhysics/6', 'autorouting','on');
add_line(modelName, 'volRiceInit/1',  'RicePhysics/7', 'autorouting','on');

% Passthrough outputs -> plant outports (RicePhysics outputs 4..8)
for k = 1:numel(outNames)
    add_line(modelName, sprintf('RicePhysics/%d', 3 + k), ...
        [outNames{k} '/1'], 'autorouting','on');
end

% Controller FMU wiring
% Inputs to FMU:
%   port 1: isLidOpen_Controller <- isLidOpen inport
%   port 2: tempPot_Controller   <- T_state (delayed integrator value)
%   port 3: btnStartStop
%   port 4: btnDelay
%   port 5: btnSetTime
add_line(modelName, 'isLidOpen/1',   'Controller/1', 'autorouting','on');
add_line(modelName, 'FromT_ctrl/1',  'Controller/2', 'autorouting','on');
add_line(modelName, 'btnStartStop/1','Controller/3', 'autorouting','on');
add_line(modelName, 'btnDelay/1',    'Controller/4', 'autorouting','on');
add_line(modelName, 'btnSetTime/1',  'Controller/5', 'autorouting','on');

% FMU output 1 (heaterPowerPct) -> RicePhysics input 5 (powerPct)
add_line(modelName, 'Controller/1', 'RicePhysics/5', 'autorouting','on');

% Controller outputs -> controller outports
for k = 1:numel(ctrlOutNames)
    add_line(modelName, sprintf('Controller/%d', k), ...
        [ctrlOutNames{k} '/1'], 'autorouting','on');
end

% --- Solver / configuration ---------------------------------------------
set_param(modelName, ...
    'Solver',          'ode23', ...
    'StartTime',       '0', ...
    'StopTime',        '3600', ...
    'RelTol',          '1e-5', ...
    'AbsTol',          '1e-7', ...
    'MaxStep',         '5', ...
    'SaveTime',        'off', ...
    'SaveOutput',      'off', ...
    'SaveState',       'off', ...
    'SolverType',      'Variable-step');

% --- Save ----------------------------------------------------------------
save_system(modelName, slxPath);
close_system(modelName, 0);

fprintf('Built %s (%d bytes)\n', slxPath, ...
    getfield(dir(slxPath), 'bytes'));
end
