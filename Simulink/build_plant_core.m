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
    'InitialCondition', '20', 'Position', P(430,  30, 460,  60));
add_block('simulink/Continuous/Integrator', [modelName '/IntegMabs'], ...
    'InitialCondition', '0',  'Position', P(430,  90, 460, 120));
add_block('simulink/Continuous/Integrator', [modelName '/IntegMevap'], ...
    'InitialCondition', '0',  'Position', P(430, 150, 460, 180));

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
