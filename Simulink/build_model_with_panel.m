function build_model_with_panel(modelName)
%BUILD_MODEL_WITH_PANEL  Builds RiceCookerWithPanel.slx.
%
%   Creates a self-contained co-simulation model containing:
%     - Plant core   : RicePhysics MATLAB Function + 3 Integrators
%                      (shared with RiceCookerPlant via build_plant_core)
%     - Controller   : Controller_MainControl.fmu (FMI2 Co-Sim)
%     - Scope        : 3-subplot scope (tempC / heaterPowerPct / waterMassKg)
%     - Panel I/O    : RiceCookerPanel.fmu      (buttons in, LED+text out)
%
%
%   Connections (harness_ControlPhysicsPanel equivalent):
%     Constants -> plant inputs (tempExt=20, volWater=0.33, volRice=0.33)
%     Controller heaterPowerPct -> plant powerPct + Scope port 2
%     RicePhysics tempC / waterMassKg -> Scope ports 1 / 3
%     Controller colorLED -> RiceCookerPanel ColorLED
%     Controller displayText (6-elem int vector, port 3) -> RiceCookerPanel
%     RiceCookerPanel buttons -> Controller (via Goto/From tags)
%
%   Layout (left -> right):
%     Constants | Plant core | Controller | Scope | PanelCtrl

if nargin < 1
    modelName = 'RiceCookerWithPanel';
end

thisDir = fileparts(mfilename('fullpath'));
slxPath = fullfile(thisDir, [modelName '.slx']);

% -------------------------------------------------------------------------
% Setup
% -------------------------------------------------------------------------
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
try_delete_file(slxPath);

new_system(modelName, 'Model');
load_system(modelName);

fmuDir  = fullfile(thisDir, '..', 'fmu');
addpath(fmuDir);   % FMU block requires folder on path

% =========================================================================
% BLOCKS
% =========================================================================

% -------------------------------------------------------------------------
% Plant core
% -------------------------------------------------------------------------
build_plant_core(modelName, 1.2);

% Match the saved RiceCookerWithPanel.slx layout exactly.
set_param([modelName '/RicePhysics'], 'Position', [240 46 430 434]);
set_param([modelName '/IntegT'], 'Position', [515 32 550 68]);
set_param([modelName '/IntegMabs'], 'Position', [515 97 550 133]);
set_param([modelName '/IntegMevap'], 'Position', [515 162 550 198]);
set_param([modelName '/GotoT'], 'Position', [610 32 650 68]);
set_param([modelName '/GotoMabs'], 'Position', [610 97 650 133]);
set_param([modelName '/GotoMevap'], 'Position', [610 162 650 198]);
set_param([modelName '/FromT'], 'Position', [180 63 215 87]);
set_param([modelName '/FromMabs'], 'Position', [180 118 215 142]);
set_param([modelName '/FromMevap'], 'Position', [180 173 215 197]);

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
    'Position', [45 225 125 255]);

add_block('simulink/Sources/Constant', [modelName '/volWater_const'], ...
    'Value', '0.33', ...
    'Position', [45 335 125 365]);

add_block('simulink/Sources/Constant', [modelName '/volRice_const'], ...
    'Value', '3.3e-4', ...
    'Position', [45 390 125 420]);

add_block('simulink/Sources/Constant', [modelName '/isLidOpen_const'], ...
    'Value', '0', ...
    'OutDataTypeStr', 'boolean', ...
    'Position', [630 490 700 520]);

% -------------------------------------------------------------------------
% Extra From block: delayed temperature for Controller input 2
% Avoids algebraic loop (same pattern as RiceCookerPlant.slx)
% -------------------------------------------------------------------------
add_block('simulink/Signal Routing/From', [modelName '/FromT_ctrl'], ...
    'GotoTag', 'T_state', ...
    'Position', [665 555 700 585]);

% -------------------------------------------------------------------------
% Controller FMU (Co-Simulation, step=1 s)
%   Inputs  : isLidOpen(1), tempPot(2), btnStartStop(3), btnDelay(4), btnSetTime(5)
%   Outputs : heaterPowerPct(1), colorLED(2), displayText[0..5] vector(3)
% -------------------------------------------------------------------------
add_block('built-in/FMU', [modelName '/Controller'], ...
    'Position', [740 470 940 800], ...
    'ForegroundColor', 'white', ...
    'BackgroundColor', 'black');
% FMUName must be a filename; folder location is provided via addpath(fmuDir).
set_param([modelName '/Controller'], 'FMUName', 'Controller_MainControl.fmu');

% -------------------------------------------------------------------------
% Button feedback Goto/From (RiceCookerPanel -> Controller)
%   Goto blocks placed right of RiceCookerPanel (signals leave panel).
%   From blocks placed left of Controller (signals enter controller).
% -------------------------------------------------------------------------
btnTags = {'BtnStartStop', 'BtnDelay', 'BtnSetTime'};

% From blocks (controller side)
fromBtnY = [620 685 750];
for k = 1:3
    add_block('simulink/Signal Routing/From', ...
        [modelName '/FromBtn' num2str(k)], ...
        'GotoTag', btnTags{k}, ...
        'Position', [660 fromBtnY(k) 710 fromBtnY(k)+30]);
end

% Goto blocks (panel side) — placed right of RiceCookerPanel
gotoBtnY = [535 635 735];
for k = 1:3
    add_block('simulink/Signal Routing/Goto', ...
        [modelName '/GotoBtn' num2str(k)], ...
        'GotoTag', btnTags{k}, ...
        'Position', [1470 gotoBtnY(k) 1550 gotoBtnY(k)+30]);
end

% -------------------------------------------------------------------------
% Unit Delay on colorLED: breaks the algebraic loop between Controller and
% RiceCookerPanel (both FMUs are discrete at 1 s, creating a direct loop).
% A 1-step delay on the LED signal is physically correct: the display
% updates one cycle after the controller computes a new value.
% -------------------------------------------------------------------------
add_block('simulink/Discrete/Unit Delay', [modelName '/ColorLED_Delay'], ...
    'SampleTime', '1', ...
    'InitialCondition', '1', ...  % 1 = GREEN (ready/standby); 0=OFF shows as white
    'Position', [1015 517 1055 553]);

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
    'Position', [1015 675 1055 705]);

% -------------------------------------------------------------------------
% Scope: tempC (port 1) / heaterPowerPct (port 2) / waterMassKg (port 3)
% Replaces VisualizationPanel GUI FMU which hangs on fmi2Terminate.
% -------------------------------------------------------------------------
add_block('simulink/Sinks/Scope', [modelName '/PlantScope'], ...
    'NumInputPorts', '3', ...
    'Position', [1080 180 1180 300]);

% -------------------------------------------------------------------------
% RiceCookerPanel FMU  (2 inputs, 3 outputs)
%   Inputs  : ColorLED (Integer, port 1), ScreenText (String, port 2)
%   Outputs : Button1Pressed (1), Button2Pressed (2), Button3Pressed (3)
% -------------------------------------------------------------------------
add_block('built-in/FMU', [modelName '/RiceCookerPanel'], ...
    'Position', [1135 500 1325 800], ...
    'ForegroundColor', 'white');
set_param([modelName '/RiceCookerPanel'], 'FMUName', 'RiceCookerPanel.fmu');

% -------------------------------------------------------------------------
% ScreenText converter: Controller displayText[0..5] (6-element int32 vector,
% port 3) -> FMI2 String for RiceCookerPanel ScreenText (port 2).
% Requires Simulink R2021b+ for string signal support.
% ASCII 0 (null) chars are replaced with space before conversion.
% -------------------------------------------------------------------------
add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [modelName '/ScreenTextConv'], ...
    'Position', [1005 750 1095 790]);

sfObj   = sfroot();
convChart = sfObj.find('-isa', 'Stateflow.EMChart', 'Path', [modelName '/ScreenTextConv']);
convChart.Script = sprintf('%s\n%s\n%s\n%s\n%s\n%s\n', ...
    'function screenText = ScreenTextConv(chars)', ...
    '%#codegen', ...
    'if isempty(chars), screenText = string("      "); return; end', ...
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
% Controller output 1 (heaterPowerPct) -> plant + Scope (port 2)
% -------------------------------------------------------------------------
add_line(modelName, 'Controller/1', 'RicePhysics/5',  'autorouting','on');
add_line(modelName, 'Controller/1', 'PlantScope/2',   'autorouting','on');

% -------------------------------------------------------------------------
% RicePhysics -> Scope (tempC -> port 1, waterMassKg -> port 3)
%   Output port mapping (rice_physics.m):
%     4:tempC  5:massWaterKg  6:massWaterPct  7:volRiceM3
% -------------------------------------------------------------------------
add_line(modelName, 'RicePhysics/4', 'PlantScope/1', 'autorouting','on');  % tempC
add_line(modelName, 'RicePhysics/5', 'PlantScope/3', 'autorouting','on');  % waterMassKg

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
% NOTE: Fixed-step solver is CRITICAL with discrete FMU blocks (1 s period).
% Variable-step solvers (ode23, ode45) can hang when synchronizing multiple
% discrete FMUs at simulation end. Use fixed-step Runge-Kutta (ode4) for
% robustness and clean termination.
set_param(modelName, ...
    'Solver',      'ode4', ...
    'SolverType',  'Fixed-step', ...
    'FixedStep',   '0.1', ...
    'StartTime',   '0', ...
    'StopTime',    '7000', ...
    'RelTol',      '1e-5', ...
    'AbsTol',      '1e-7', ...
    'SaveTime',    'off', ...
    'SaveOutput',  'off', ...
    'SaveState',   'off');

% =========================================================================
% SAVE
% =========================================================================
% Remove the previous .slx right before save so Simulink does not need to
% create/rename backup files (which often fails when the old file is locked).
try_delete_file(slxPath);

saveTarget = slxPath;
try
    save_system(modelName, saveTarget);
catch ME
    if contains(ME.message, 'Permission denied', 'IgnoreCase', true)
        % Fallback to a unique file if overwrite is blocked by another process.
        saveTarget = fullfile(thisDir, sprintf('%s_%s.slx', modelName, datestr(now, 'yyyymmdd_HHMMSS')));
        warning('Could not overwrite %s. Saving to %s instead.', slxPath, saveTarget);
        save_system(modelName, saveTarget);
    else
        rethrow(ME);
    end
end
close_system(modelName, 0);

info = dir(saveTarget);
fprintf('Built %s (%d bytes)\n', saveTarget, info.bytes);
end

function try_delete_file(filePath)
if ~exist(filePath, 'file')
    return;
end

% Best effort: clear read-only attribute before deleting.
fileattrib(filePath, '+w');

try
    delete(filePath);
catch
    % Leave deletion failures to be handled by save fallback logic.
end
end
