within PlantModel;

block ChangeTemp "Computes the temperature rate of change outside the boiling plateau"
  "Energy balance: dT/dt = (P_in - P_loss) / C_thermal"

  Modelica.Blocks.Interfaces.RealInput  T            "Current pot temperature [degC]";
  Modelica.Blocks.Interfaces.RealInput  tempExt       "Ambient temperature [degC]";
  Modelica.Blocks.Interfaces.RealInput  powerPct      "Heater command [0-100 %]";
  Modelica.Blocks.Interfaces.RealInput  m_rice        "Dry rice mass [kg]";
  Modelica.Blocks.Interfaces.RealInput  m_water_total "Total water mass (free + absorbed) [kg]";
  Modelica.Blocks.Interfaces.RealOutput dTdt          "Temperature rate of change [degC/s]";

protected
  Real P_in      "Input power [W]";
  Real P_loss    "Thermal loss [W]";
  Real C_thermal "Effective thermal capacity [J/K]";

equation
  P_in      = powerPct / 100.0 * FULL_POWER_COOKER_W;
  P_loss    = HEAT_LOSS_W_PER_K * (T - tempExt);
  C_thermal = MASS_BOWL_KG * C_P_ALU + m_rice * C_P_DRY_RICE + m_water_total * C_P_WATER;
  dTdt      = if C_thermal > 0.0 then (P_in - P_loss) / C_thermal else 0.0;

  annotation(Documentation(info="<html>
    <p>Computes <em>dT/dt = (P_in - P_loss) / C_thermal</em> when the cooker is not in the boiling
    regime. This rate is consumed by <b>PhysicalModel</b>, which integrates it to advance the
    temperature state.</p>
  </html>"));

end ChangeTemp;
