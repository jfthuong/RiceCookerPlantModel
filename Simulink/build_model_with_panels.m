function build_model_with_panels(modelName)
%BUILD_MODEL_WITH_PANELS  Builds RiceCookerWithPanels.slx.
%
%   Creates a self-contained co-simulation model containing:
%     - Plant core   : RicePhysics MATLAB Function + 3 Integrators
%                      (shared with RiceCookerPlant via build_plant_core)
%     - Controller   : Controller_MainControl.fmu (FMI2 Co-Sim)
%     - Height compu.: two Gain blocks (mass/volume -> bowl height)
%     - Visualization: VisualizationPanel.fmu  (7 inputs, display only)
%     - Panel I/O    : RiceCookerPanel.fmu      (buttons in, LED+text out)
%
%   Connections (harness_ControlPhysicsPanel equivalent):
%     Constants -> plant inputs (tempExt=20, volWater=0.33, volRice=0.33)
%     Controller heaterPowerPct -> plant powerPct + VisuPanel powerPct
%     Plant outputs -> VisualizationPanel inputs
%     Height gains -> VisualizationPanel waterHeight / riceHeight
%     Controller colorLED -> RiceCookerPanel ColorLED
%     Controller displayText (6-elem int vector, port 3) -> RiceCookerPanel
%     RiceCookerPanel buttons -> Controller (via Goto/From tags)
%
%   Layout (left -> right):
%     Constants | Plant core | Controller+Height | VisuPanel | PanelCtrl

if nargin < 1
    modelName = 'RiceCookerWithPanels';
end

% -------------------------------------------------------------------------
% Setup
% -------------------------------------------------------------------------
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
slxFile = [modelName '.slx'];
if exist(slxFile, 'file')
    delete(slxFile);
end

new_system(modelName, 'Model');
load_system(modelName);

thisDir = fileparts(mfilename('fullpath'));
fmuDir  = fullfile(thisDir, '..', 'fmu');
addpath(fmuDir);   % FMU block requires folder on path

% =========================================================================
% BLOCKS
% =========================================================================

% -------------------------------------------------------------------------
% Plant core (scale=1.2 for generous spacing)
% Occupies approximately: x=180-648, y=36-420
% -------------------------------------------------------------------------
build_plant_core(modelName, 1.2);

% -------------------------------------------------------------------------
% Constant sources (replace inports for standalone simulation)
%   tempExt    = 20  °C   (ambient temperature)
%   volWaterInit = 0.33 L (initial water volume)
%   volRiceInit  = 0.33 L (initial rice volume in m^3 ≈ 0.33e-3, kept as 0.33)
%   isLidOpen  = false    (lid is closed)
%
%   NOTE: volWaterInit is used as 'mass' in kg (water density ≈ 1 kg/L),
%         volRiceInit  is initial rice volume in m^3.
% -------------------------------------------------------------------------
add_block('simulink/Sources/Constant', [modelName '/tempExt_const'], ...
    'Value', '20', ...
    'Position', [30 200 110 230]);

add_block('simulink/Sources/Constant', [modelName '/volWater_const'], ...
    'Value', '0.33', ...
    'Position', [30 310 110 340]);

add_block('simulink/Sources/Constant', [modelName '/volRice_const'], ...
    'Value', '3.3e-4', ...
    'Position', [30 400 110 430]);

add_block('simulink/Sources/Constant', [modelName '/isLidOpen_const'], ...
    'Value', '0', ...
    'OutDataTypeStr', 'boolean', ...
    'Position', [30 510 100 540]);

% -------------------------------------------------------------------------
% Extra From block: delayed temperature for Controller input 2
% Avoids algebraic loop (same pattern as RiceCookerPlant.slx)
% -------------------------------------------------------------------------
add_block('simulink/Signal Routing/From', [modelName '/FromT_ctrl'], ...
    'GotoTag', 'T_state', ...
    'Position', [180 500 216 530]);

% -------------------------------------------------------------------------
% Controller FMU (Co-Simulation, step=1 s)
%   Inputs  : isLidOpen(1), tempPot(2), btnStartStop(3), btnDelay(4), btnSetTime(5)
%   Outputs : heaterPowerPct(1), colorLED(2), displayText[0..5] vector(3)
% -------------------------------------------------------------------------
add_block('built-in/FMU', [modelName '/Controller'], ...
    'Position', [740 470 940 800]);
set_param([modelName '/Controller'], 'FMUName', 'Controller_MainControl.fmu');

% -------------------------------------------------------------------------
% Button feedback Goto/From (RiceCookerPanel -> Controller)
%   Goto blocks placed right of RiceCookerPanel (signals leave panel).
%   From blocks placed left of Controller (signals enter controller).
% -------------------------------------------------------------------------
btnTags = {'BtnStartStop', 'BtnDelay', 'BtnSetTime'};

% From blocks (controller side)
fromBtnY = [590 655 720];
for k = 1:3
    add_block('simulink/Signal Routing/From', ...
        [modelName '/FromBtn' num2str(k)], ...
        'GotoTag', btnTags{k}, ...
        'Position', [660 fromBtnY(k) 710 fromBtnY(k)+30]);
end

% Goto blocks (panel side) — placed right of RiceCookerPanel
gotoBtnY = [555 630 705];
for k = 1:3
    add_block('simulink/Signal Routing/Goto', ...
        [modelName '/GotoBtn' num2str(k)], ...
        'GotoTag', btnTags{k}, ...
        'Position', [1310 gotoBtnY(k) 1390 gotoBtnY(k)+30]);
end

% -------------------------------------------------------------------------
% Height computation: mass/volume -> height in cylindrical bowl
%   Bowl diameter = 12.5 cm  ->  radius = 0.0625 m
%   waterHeight [m] = massWaterKg [kg] / (rho_water * pi * r^2)
%                   = massWaterKg / 1000 / (pi * 0.0625^2)
%   riceHeight  [m] = volRiceM3  [m^3] / (pi * r^2)
% -------------------------------------------------------------------------
r_bowl = 0.0625;   % bowl radius [m]  (12.5 cm diameter, PlantModel package.mo)
waterH_gain = 100 / (1000 * pi * r_bowl^2);  % (kg -> cm)  [VisualizationPanel expects cm]
riceH_gain  = 100 / (pi * r_bowl^2);          % (m^3 -> cm) [VisualizationPanel expects cm]

add_block('simulink/Math Operations/Gain', [modelName '/WaterHeightGain'], ...
    'Gain', num2str(waterH_gain, 15), ...
    'Position', [660 360 750 390]);

add_block('simulink/Math Operations/Gain', [modelName '/RiceHeightGain'], ...
    'Gain', num2str(riceH_gain, 15), ...
    'Position', [660 410 750 440]);

% -------------------------------------------------------------------------
% Unit Delay on colorLED: breaks the algebraic loop between Controller and
% RiceCookerPanel (both FMUs are discrete at 1 s, creating a direct loop).
% A 1-step delay on the LED signal is physically correct: the display
% updates one cycle after the controller computes a new value.
% -------------------------------------------------------------------------
add_block('simulink/Discrete/Unit Delay', [modelName '/ColorLED_Delay'], ...
    'SampleTime', '1', ...
    'InitialCondition', '1', ...  % 1 = GREEN (ready/standby); 0=OFF shows as white
    'Position', [960 510 1000 545]);

% -------------------------------------------------------------------------
% Unit Delay on displayText: breaks the algebraic loop
%   Controller/3 (int32[6]) -> ScreenTextConv -> RiceCookerPanel ->
%   buttons -> FromBtn -> Controller.
% Placed BEFORE ScreenTextConv so the delay operates on the int32 vector
% (Simulink Unit Delay does not support string signals).
% InitialCondition 'IDLE  ' = [73 68 76 69 32 32] shown at t=0.
% -------------------------------------------------------------------------
add_block('simulink/Discrete/Unit Delay', [modelName '/DisplayText_Delay'], ...
    'SampleTime', '1', ...
    'InitialCondition', '[73 68 76 69 32 32]', ...  % 'IDLE  '
    'Position', [870 735 910 765]);

% -------------------------------------------------------------------------
% VisualizationPanel FMU  (7 inputs, no outputs)
%   Ports (from modelDescription.xml):
%     1: waterPct    2: waterMassKg  3: waterHeight  4: tempC
%     5: riceVolM3   6: riceHeight   7: powerPct
% -------------------------------------------------------------------------
add_block('built-in/FMU', [modelName '/VisualizationPanel'], ...
    'Position', [1010 30 1200 460]);
set_param([modelName '/VisualizationPanel'], 'FMUName', 'VisualizationPanel.fmu');

% -------------------------------------------------------------------------
% RiceCookerPanel FMU  (2 inputs, 3 outputs)
%   Inputs  : ColorLED (Integer, port 1), ScreenText (String, port 2)
%   Outputs : Button1Pressed (1), Button2Pressed (2), Button3Pressed (3)
% -------------------------------------------------------------------------
add_block('built-in/FMU', [modelName '/RiceCookerPanel'], ...
    'Position', [1060 510 1250 810]);
set_param([modelName '/RiceCookerPanel'], 'FMUName', 'RiceCookerPanel.fmu');

% -------------------------------------------------------------------------
% ScreenText converter: Controller displayText[0..5] (6-element int32 vector,
% port 3) -> FMI2 String for RiceCookerPanel ScreenText (port 2).
% Requires Simulink R2021b+ for string signal support.
% ASCII 0 (null) chars are replaced with space before conversion.
% -------------------------------------------------------------------------
add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [modelName '/ScreenTextConv'], ...
    'Position', [960 730 1045 770]);

sfObj   = sfroot();
convChart = sfObj.find('-isa', 'Stateflow.EMChart', 'Path', [modelName '/ScreenTextConv']);
convChart.Script = sprintf('%s\n%s\n%s\n%s\n%s\n', ...
    'function screenText = ScreenTextConv(chars)', ...
    '%#codegen', ...
    'v = int32(chars(:)'');', ...
    'v(v <= 0) = int32(32);  %% replace null/ctrl chars with space', ...
    'screenText = string(char(v));');

% =========================================================================
% WIRING
% =========================================================================

% -------------------------------------------------------------------------
% Constants -> RicePhysics external inputs (4, 6, 7)
% -------------------------------------------------------------------------
add_line(modelName, 'tempExt_const/1',  'RicePhysics/4', 'autorouting','on');
add_line(modelName, 'volWater_const/1', 'RicePhysics/6', 'autorouting','on');
add_line(modelName, 'volRice_const/1',  'RicePhysics/7', 'autorouting','on');

% -------------------------------------------------------------------------
% Controller inputs
% -------------------------------------------------------------------------
add_line(modelName, 'isLidOpen_const/1', 'Controller/1', 'autorouting','on');
add_line(modelName, 'FromT_ctrl/1',      'Controller/2', 'autorouting','on');
add_line(modelName, 'FromBtn1/1',        'Controller/3', 'autorouting','on');
add_line(modelName, 'FromBtn2/1',        'Controller/4', 'autorouting','on');
add_line(modelName, 'FromBtn3/1',        'Controller/5', 'autorouting','on');

% -------------------------------------------------------------------------
% Controller output 1 (heaterPowerPct) -> plant + VisualizationPanel
% -------------------------------------------------------------------------
add_line(modelName, 'Controller/1', 'RicePhysics/5',         'autorouting','on');
add_line(modelName, 'Controller/1', 'VisualizationPanel/7',  'autorouting','on');

% -------------------------------------------------------------------------
% RicePhysics -> VisualizationPanel (waterPct, waterMassKg, tempC, riceVolM3)
%   Output port mapping (rice_physics.m):
%     4:tempC  5:massWaterKg  6:massWaterPct  7:volRiceM3  8:volRicePct
% -------------------------------------------------------------------------
add_line(modelName, 'RicePhysics/6', 'VisualizationPanel/1', 'autorouting','on');  % waterPct
add_line(modelName, 'RicePhysics/5', 'VisualizationPanel/2', 'autorouting','on');  % waterMassKg
add_line(modelName, 'RicePhysics/4', 'VisualizationPanel/4', 'autorouting','on');  % tempC
add_line(modelName, 'RicePhysics/7', 'VisualizationPanel/5', 'autorouting','on');  % riceVolM3

% -------------------------------------------------------------------------
% Height gains -> VisualizationPanel (3:waterHeight, 6:riceHeight)
% -------------------------------------------------------------------------
add_line(modelName, 'RicePhysics/5',    'WaterHeightGain/1',      'autorouting','on');
add_line(modelName, 'WaterHeightGain/1','VisualizationPanel/3',   'autorouting','on');

add_line(modelName, 'RicePhysics/7',   'RiceHeightGain/1',       'autorouting','on');
add_line(modelName, 'RiceHeightGain/1','VisualizationPanel/6',   'autorouting','on');

% -------------------------------------------------------------------------
% Controller -> RiceCookerPanel
%   Port 2: colorLED  ->  RiceCookerPanel ColorLED (port 1)
%   Port 3: displayText (6-elem int vector) -> ScreenText (port 2, if exposed)
% -------------------------------------------------------------------------
add_line(modelName, 'Controller/2', 'ColorLED_Delay/1',   'autorouting','on');
add_line(modelName, 'ColorLED_Delay/1', 'RiceCookerPanel/1', 'autorouting','on');

% ScreenText: wire Controller/3 (6-element int32, displayText ASCII codes)
% through DisplayText_Delay (breaks algebraic loop) then ScreenTextConv
% MATLAB Function -> RiceCookerPanel port 2.
add_line(modelName, 'Controller/3',        'DisplayText_Delay/1', 'autorouting','on');
add_line(modelName, 'DisplayText_Delay/1', 'ScreenTextConv/1',    'autorouting','on');
add_line(modelName, 'ScreenTextConv/1',    'RiceCookerPanel/2',   'autorouting','on');

% -------------------------------------------------------------------------
% RiceCookerPanel button outputs -> Goto tags
% -------------------------------------------------------------------------
add_line(modelName, 'RiceCookerPanel/1', 'GotoBtn1/1', 'autorouting','on');
add_line(modelName, 'RiceCookerPanel/2', 'GotoBtn2/1', 'autorouting','on');
add_line(modelName, 'RiceCookerPanel/3', 'GotoBtn3/1', 'autorouting','on');

% =========================================================================
% SOLVER CONFIGURATION
% =========================================================================
set_param(modelName, ...
    'Solver',      'ode23', ...
    'SolverType',  'Variable-step', ...
    'StartTime',   '0', ...
    'StopTime',    '7000', ...
    'MaxStep',     '1', ...
    'RelTol',      '1e-5', ...
    'AbsTol',      '1e-7', ...
    'SaveTime',    'off', ...
    'SaveOutput',  'off', ...
    'SaveState',   'off');

% =========================================================================
% SAVE
% =========================================================================
save_system(modelName, slxFile);
close_system(modelName, 0);

fprintf('Built %s (%d bytes)\n', slxFile, getfield(dir(slxFile), 'bytes'));
end
