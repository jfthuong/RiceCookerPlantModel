within PlantModel;

block MassWaterAbsorbed "Computes cumulative water mass absorbed by the rice"

  Modelica.Blocks.Interfaces.RealInput  T          "Current pot temperature [degC]";
  Modelica.Blocks.Interfaces.RealInput  m_rice     "Dry rice mass [kg]";
  Modelica.Blocks.Interfaces.RealOutput m_absorbed "Cumulative absorbed water mass [kg]";

protected
  Real m_abs_state(start = 0.0, fixed = true) "State: integrated absorbed water [kg]";
  Real absorb_limit                            "Maximum absorbable water mass [kg]";

equation
  absorb_limit  = m_rice * (MAX_RATIO_WATER_ABSORB_BY_MASS - 1.0);
  der(m_abs_state) = if m_abs_state < absorb_limit
                     then ABSORPTION_RATE_COEFF * T / BOILING_POINT_C
                     else 0.0;
  m_absorbed = m_abs_state;

  annotation(Documentation(info="<html>
    <p>Integrates the water absorption rate over time. The rate scales with temperature
    (relative to the boiling point) and is clamped once the absorbed mass reaches
    <em>m_rice * (MAX_RATIO_WATER_ABSORB_BY_MASS - 1)</em>.</p>
  </html>"));

end MassWaterAbsorbed;
