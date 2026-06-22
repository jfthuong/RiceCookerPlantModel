within PlantModel;

block VolumeRice "Computes rice swelling volume from absorbed water and temperature"

  Modelica.Blocks.Interfaces.RealInput  T               "Current pot temperature [degC]";
  Modelica.Blocks.Interfaces.RealInput  volRiceInit      "Initial rice volume [m3]";
  Modelica.Blocks.Interfaces.RealInput  m_water_absorbed "Absorbed water mass [kg]";
  Modelica.Blocks.Interfaces.RealOutput volRiceM3        "Current rice volume [m3]";
  Modelica.Blocks.Interfaces.RealOutput volRicePct       "Rice volume relative to initial [%]";

protected
  Real f_phase "Gelatinisation phase factor [0-1]";
  Real r_abs   "Absorption swelling ratio [0-1]";
  Real denom   "Denominator used in r_abs [kg]";

equation
  // Gelatinisation phase factor (piecewise linear in T)
  f_phase = if T < TEMP_GEL_LOW_C then
              S0_BASELINE_SWELLING
            else if T < TEMP_GEL_HIGH_C then
              S0_BASELINE_SWELLING + (1.0 - S0_BASELINE_SWELLING) *
              max(0.0, min(1.0, (T - TEMP_GEL_LOW_C) / (TEMP_GEL_HIGH_C - TEMP_GEL_LOW_C)))
            else
              1.0;

  // Absorption-driven swelling ratio
  denom  = m_water_absorbed + ABSORPTION_SAT_DENOM_FACTOR * DENSITY_RICE_KG_PER_M3 * volRiceInit;
  r_abs  = if denom > 0.0 then max(0.0, min(1.0, m_water_absorbed / denom)) else 0.0;

  // Swollen rice volume
  volRiceM3  = volRiceInit * (1.0 + (MAX_RATIO_WATER_ABSORB_BY_VOL - 1.0) * r_abs * f_phase);
  volRicePct = if volRiceInit > 0.0 then 100.0 * volRiceM3 / volRiceInit else 100.0;

  annotation(Documentation(info="<html>
    <p>Computes the current rice volume accounting for water absorption and gelatinisation.
    This output is for visualisation only and is not fed back into the controller.</p>
  </html>"));

end VolumeRice;
