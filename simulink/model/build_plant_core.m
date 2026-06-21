function build_plant_core(modelName, scale)
%BUILD_PLANT_CORE  Add the rice-cooker plant core blocks to an existing model.
%
%   Adds: RicePhysics (MATLAB Function), IntegT/IntegMabs/IntegMevap,
%         Goto tags T_state/Mabs_state/Mevap_state, and corresponding
%         From blocks (state feedback into RicePhysics inputs 1-3).
%   Wires all internal feedback loops.
%
%   Caller must wire the following EXTERNAL signals afterwards:
%     RicePhysics input 4 : tempExt
%     RicePhysics input 5 : powerPct   (from controller)
%     RicePhysics input 6 : volWaterInit
%     RicePhysics input 7 : volRiceInit
%
%   Available EXTERNAL outputs (right side of plant block):
%     RicePhysics output 4 : tempC
%     RicePhysics output 5 : massWaterKg
%     RicePhysics output 6 : massWaterPct
%     RicePhysics output 7 : volRiceM3
%     RicePhysics output 8 : volRicePct
%     Goto tag 'T_state'   : delayed temperature  (for controller)
%
%   scale (optional, default 1.0) – multiply all positions by this factor.
%     Use 1.0 for the compact standalone model, 1.2 for the panels model.

if nargin < 2
    scale = 1.0;
end

thisDir = fileparts(mfilename('fullpath'));
s = scale;
P = @(l,t,r,b) round([l*s, t*s, r*s, b*s]);   % position scaler

% -------------------------------------------------------------------------
% MATLAB Function block (RicePhysics)
% -------------------------------------------------------------------------
fcnBlock = [modelName '/RicePhysics'];
add_block('simulink/User-Defined Functions/MATLAB Function', fcnBlock, ...
    'Position', P(200, 30, 360, 350));

codeFile = fullfile(thisDir, 'rice_cooker_physics.m');
code  = fileread(codeFile);
sf    = sfroot();
chart = sf.find('-isa', 'Stateflow.EMChart', 'Path', fcnBlock);
assert(~isempty(chart), 'Could not find MATLAB Function chart for RicePhysics.');
chart.Script = code;

% -------------------------------------------------------------------------
% Integrators  (IC: T=20 °C, m_abs=0, m_evap=0)
% -------------------------------------------------------------------------
add_block('simulink/Continuous/Integrator', [modelName '/IntegT'], ...
    'InitialConditionSource', 'external', ...
    'ExternalReset', 'rising', ...
    'Position', P(430,  30, 460,  60));
add_block('simulink/Continuous/Integrator', [modelName '/IntegMabs'], ...
    'InitialCondition', '0',  'Position', P(430,  90, 460, 120));
add_block('simulink/Continuous/Integrator', [modelName '/IntegMevap'], ...
    'InitialCondition', '0',  'Position', P(430, 150, 460, 180));

% External IC schedule for IntegT:
%   t=0      -> 20 degC (initial condition)
%   t>1e-6 s -> 100 degC (reset target used on boiling onset)
add_block('simulink/Sources/Step', [modelName '/TInitResetValue'], ...
    'Time', '1e-6', ...
    'Before', '20', ...
    'After', '100', ...
    'Position', P(330,  5, 390, 35));

% Boiling onset detector: rising edge of (T_state >= 100 && massWaterKg > 0)
add_block('simulink/Logic and Bit Operations/Relational Operator', [modelName '/IsAtBoiling'], ...
    'Operator', '>=', ...
    'Position', P(585,  15, 640, 45));
add_block('simulink/Sources/Constant', [modelName '/BoilingPointConst'], ...
    'Value', '100', ...
    'Position', P(510,   0, 565, 25));

add_block('simulink/Logic and Bit Operations/Relational Operator', [modelName '/HasFreeWater'], ...
    'Operator', '>', ...
    'Position', P(585,  60, 640, 90));
add_block('simulink/Sources/Constant', [modelName '/ZeroConst'], ...
    'Value', '0', ...
    'Position', P(510,  90, 565, 115));

add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName '/BoilingCond'], ...
    'Operator', 'AND', ...
    'Inputs', '2', ...
    'Position', P(675,  35, 730, 85));

add_block('simulink/Logic and Bit Operations/Detect Rise Positive', [modelName '/BoilingOnset'], ...
    'Position', P(760,  45, 820, 75));
add_block('simulink/Signal Attributes/Data Type Conversion', [modelName '/BoilingOnsetToDouble'], ...
    'OutDataTypeStr', 'double', ...
    'Position', P(845,  45, 905, 75));

% -------------------------------------------------------------------------
% Goto tags (integrator outputs → named tags)
% -------------------------------------------------------------------------
add_block('simulink/Signal Routing/Goto', [modelName '/GotoT'], ...
    'GotoTag', 'T_state',    'Position', P(510,  30, 540,  60));
add_block('simulink/Signal Routing/Goto', [modelName '/GotoMabs'], ...
    'GotoTag', 'Mabs_state', 'Position', P(510,  90, 540, 120));
add_block('simulink/Signal Routing/Goto', [modelName '/GotoMevap'], ...
    'GotoTag', 'Mevap_state','Position', P(510, 150, 540, 180));

% -------------------------------------------------------------------------
% From tags (feed state back into RicePhysics inputs 1-3)
% -------------------------------------------------------------------------
add_block('simulink/Signal Routing/From', [modelName '/FromT'], ...
    'GotoTag', 'T_state',    'Position', P(150,  30, 180,  50));
add_block('simulink/Signal Routing/From', [modelName '/FromMabs'], ...
    'GotoTag', 'Mabs_state', 'Position', P(150,  60, 180,  80));
add_block('simulink/Signal Routing/From', [modelName '/FromMevap'], ...
    'GotoTag', 'Mevap_state','Position', P(150,  90, 180, 110));

% -------------------------------------------------------------------------
% Internal wiring
% -------------------------------------------------------------------------
% State feedback → RicePhysics inputs 1, 2, 3
add_line(modelName, 'FromT/1',     'RicePhysics/1', 'autorouting','on');
add_line(modelName, 'FromMabs/1',  'RicePhysics/2', 'autorouting','on');
add_line(modelName, 'FromMevap/1', 'RicePhysics/3', 'autorouting','on');

% Derivative outputs → integrators
add_line(modelName, 'RicePhysics/1', 'IntegT/1',     'autorouting','on');
add_line(modelName, 'RicePhysics/2', 'IntegMabs/1',  'autorouting','on');
add_line(modelName, 'RicePhysics/3', 'IntegMevap/1', 'autorouting','on');

% Integrators → Goto tags
add_line(modelName, 'IntegT/1',    'GotoT/1',    'autorouting','on');
add_line(modelName, 'IntegMabs/1', 'GotoMabs/1', 'autorouting','on');
add_line(modelName, 'IntegMevap/1','GotoMevap/1','autorouting','on');

% Temperature reset wiring (Modelica reinit parity)
add_line(modelName, 'TInitResetValue/1', 'IntegT/2', 'autorouting','on');
add_line(modelName, 'BoilingOnset/1',    'BoilingOnsetToDouble/1', 'autorouting','on');
add_line(modelName, 'BoilingOnsetToDouble/1', 'IntegT/3', 'autorouting','on');
add_line(modelName, 'FromT/1',           'IsAtBoiling/1', 'autorouting','on');
add_line(modelName, 'BoilingPointConst/1','IsAtBoiling/2', 'autorouting','on');
add_line(modelName, 'RicePhysics/5',     'HasFreeWater/1', 'autorouting','on');
add_line(modelName, 'ZeroConst/1',       'HasFreeWater/2', 'autorouting','on');
add_line(modelName, 'IsAtBoiling/1',     'BoilingCond/1', 'autorouting','on');
add_line(modelName, 'HasFreeWater/1',    'BoilingCond/2', 'autorouting','on');
add_line(modelName, 'BoilingCond/1',     'BoilingOnset/1', 'autorouting','on');
