function [dTdt, dmAbs, dmEvap, tempC, massWaterKg, massWaterPct, ...
          volRiceM3, volRicePct] = rice_cooker_physics(T, m_abs, m_evap, ...
                                                 tempExt, powerPct, ...
                                                 volWaterInit, volRiceInit)
%RICE_PHYSICS  All algebraic equations of the rice-cooker plant model.
%
%   Mirrors the Modelica package PlantModel (see PlantModel/*.mo and the
%   constants in PlantModel/package.mo). Used as the body of a single
%   MATLAB Function block inside the Simulink model RiceCookerPlant.slx.
%
%   Inputs
%       T            - pot temperature state [degC]
%       m_abs        - absorbed-water state [kg]
%       m_evap       - evaporated-water state [kg]
%       tempExt      - ambient temperature [degC]
%       powerPct     - heater command [0-100 %]
%       volWaterInit - initial water mass scale [kg]
%       volRiceInit  - initial rice volume [m^3]
%
%   Outputs (derivatives fed into 3 Integrator blocks)
%       dTdt   - dT/dt   [degC/s]
%       dmAbs  - dm_abs/dt [kg/s]
%       dmEvap - dm_evap/dt [kg/s]
%
%   Outputs (exposed as FMU outputs)
%       tempC, massWaterKg, massWaterPct, volRiceM3, volRicePct
%#codegen

% ---- Physical constants (PlantModel/package.mo) -------------------------
BOILING_POINT_C              = 100.0;
TEMP_GEL_LOW_C               =  60.0;
TEMP_GEL_HIGH_C              =  80.0;
HEAT_LOSS_W_PER_K            =   0.5;
LATENT_HEAT_VAPOR_J_PER_KG   = 2257000.0;
C_P_ALU                      = 900.0;
C_P_WATER                    = 4184.0;
C_P_DRY_RICE                 = 1200.0;
DENSITY_RICE_KG_PER_M3       = 900.0;
MAX_RATIO_WATER_ABSORB_BY_MASS = 2.0;
MAX_RATIO_WATER_ABSORB_BY_VOL  = 3.0;
S0_BASELINE_SWELLING         = 0.35;
ABSORPTION_RATE_COEFF        = 1.0e-4;
ABSORPTION_SAT_DENOM_FACTOR  = 0.5;
MASS_BOWL_KG                 = 0.160;
FULL_POWER_COOKER_W          = 300.0;

% ---- Derived masses -----------------------------------------------------
m_rice        = DENSITY_RICE_KG_PER_M3 * volRiceInit;
m_water_init  = volWaterInit;
m_water_free  = max(0.0, m_water_init - m_abs - m_evap);
m_water_total = m_water_free + m_abs;
boiling       = (T >= BOILING_POINT_C) && (m_water_free > 0.0);

% ---- Temperature derivative --------------------------------------------
P_in   = powerPct / 100.0 * FULL_POWER_COOKER_W;
P_loss = HEAT_LOSS_W_PER_K * (T - tempExt);
C_th   = MASS_BOWL_KG * C_P_ALU + m_rice * C_P_DRY_RICE + ...
         m_water_total * C_P_WATER;
if C_th > 0.0
    dTdt_raw = (P_in - P_loss) / C_th;
else
    dTdt_raw = 0.0;
end
% Clamp T at the boiling point while free water remains. Only positive
% drift is suppressed: temperature can still fall (e.g. cooling).
if boiling && dTdt_raw > 0.0
    dTdt = 0.0;
else
    dTdt = dTdt_raw;
end

% ---- Absorption rate ----------------------------------------------------
absorb_limit = m_rice * (MAX_RATIO_WATER_ABSORB_BY_MASS - 1.0);
if m_abs < absorb_limit
    dmAbs = ABSORPTION_RATE_COEFF * T / BOILING_POINT_C;
else
    dmAbs = 0.0;
end

% ---- Evaporation rate ---------------------------------------------------
P_in_boil   = powerPct / 100.0 * FULL_POWER_COOKER_W;
P_loss_boil = HEAT_LOSS_W_PER_K * (BOILING_POINT_C - tempExt);
if boiling
    dmEvap = max(0.0, P_in_boil - P_loss_boil) / LATENT_HEAT_VAPOR_J_PER_KG;
else
    dmEvap = 0.0;
end

% ---- Rice volume --------------------------------------------------------
if T < TEMP_GEL_LOW_C
    f_phase = S0_BASELINE_SWELLING;
elseif T < TEMP_GEL_HIGH_C
    f_phase = S0_BASELINE_SWELLING + (1.0 - S0_BASELINE_SWELLING) * ...
              max(0.0, min(1.0, ...
                  (T - TEMP_GEL_LOW_C) / (TEMP_GEL_HIGH_C - TEMP_GEL_LOW_C)));
else
    f_phase = 1.0;
end

denom = m_abs + ABSORPTION_SAT_DENOM_FACTOR * ...
        DENSITY_RICE_KG_PER_M3 * volRiceInit;
if denom > 0.0
    r_abs = max(0.0, min(1.0, m_abs / denom));
else
    r_abs = 0.0;
end

volRiceM3 = volRiceInit * (1.0 + (MAX_RATIO_WATER_ABSORB_BY_VOL - 1.0) * ...
                                   r_abs * f_phase);
if volRiceInit > 0.0
    volRicePct = 100.0 * volRiceM3 / volRiceInit;
else
    volRicePct = 100.0;
end

% ---- Outputs ------------------------------------------------------------
tempC       = T;
massWaterKg = m_water_free;
if m_water_init > 0.0
    massWaterPct = 100.0 * m_water_free / m_water_init;
else
    massWaterPct = 0.0;
end
end
