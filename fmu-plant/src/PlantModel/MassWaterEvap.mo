within PlantModel;

block MassWaterEvap "Computes cumulative water mass evaporated during boiling"

  Modelica.Blocks.Interfaces.BooleanInput boiling   "True when in the boiling regime";
  Modelica.Blocks.Interfaces.RealInput    powerPct  "Heater command [0-100 %]";
  Modelica.Blocks.Interfaces.RealInput    tempExt   "Ambient temperature [degC]";
  Modelica.Blocks.Interfaces.RealOutput   m_evap    "Cumulative evaporated water mass [kg]";

protected
  Real m_evap_state(start = 0.0, fixed = true) "State: integrated evaporated water [kg]";
  Real P_in_boil   "Input power evaluated at boiling temperature [W]";
  Real P_loss_boil "Thermal loss evaluated at boiling temperature [W]";

equation
  P_in_boil   = powerPct / 100.0 * FULL_POWER_COOKER_W;
  P_loss_boil = HEAT_LOSS_W_PER_K * (BOILING_POINT_C - tempExt);
  der(m_evap_state) = if boiling
                      then max(0.0, P_in_boil - P_loss_boil) / LATENT_HEAT_VAPOR_J_PER_KG
                      else 0.0;
  m_evap = m_evap_state;

  annotation(Documentation(info="<html>
    <p>Integrates the evaporation rate during boiling. The rate is driven by the net power
    available at the boiling point divided by the latent heat of vaporisation.</p>
  </html>"));

end MassWaterEvap;
