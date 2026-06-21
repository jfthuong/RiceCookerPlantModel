within PlantModel;

block PhysicalModel
  "Main rice cooker plant model – couples thermal dynamics and water/rice mass evolution"

  // ---- Inputs ---------------------------------------------------------------

  Modelica.Blocks.Interfaces.RealInput tempExt
    "Ambient temperature [degC]";
  Modelica.Blocks.Interfaces.RealInput powerPct
    "Heater command [0-100 %]";
  Modelica.Blocks.Interfaces.RealInput volWaterInit
    "Initial water mass scale [kg]  (named 'vol' for compatibility with SWAN source)";
  Modelica.Blocks.Interfaces.RealInput volRiceInit
    "Initial rice volume [m3]";

  // ---- Outputs --------------------------------------------------------------

  Modelica.Blocks.Interfaces.RealOutput tempC
    "Pot temperature [degC]";
  Modelica.Blocks.Interfaces.RealOutput massWaterKg
    "Remaining free water mass [kg]";
  Modelica.Blocks.Interfaces.RealOutput massWaterPct
    "Remaining water percentage relative to initial [%]";
  Modelica.Blocks.Interfaces.RealOutput volRiceM3
    "Rice volume [m3]";
  Modelica.Blocks.Interfaces.RealOutput volRicePct
    "Rice volume relative to initial [%]";

  // ---- Sub-components -------------------------------------------------------

  ChangeTemp        changeTemp    "Temperature rate block";
  MassWaterAbsorbed massWaterAbs  "Water absorption block";
  MassWaterEvap     massWaterEvap "Water evaporation block";
  VolumeRice        volumeRice    "Rice volume block";

protected
  Real    T(start = 20.0, fixed = true) "Pot temperature state [degC]";
  Boolean boiling                       "True when in the boiling regime";
  Real    m_rice                        "Dry rice mass [kg]";
  Real    m_water_init                  "Initial water mass [kg]";
  Real    m_water_free                  "Remaining free water mass [kg]";
  Real    m_water_total                 "Total water in pot: free + absorbed [kg]";

equation
  // ---- Derived quantities ---------------------------------------------------
  m_rice       = DENSITY_RICE_KG_PER_M3 * volRiceInit;
  m_water_init = volWaterInit;
  m_water_free  = max(0.0, m_water_init - massWaterAbs.m_absorbed - massWaterEvap.m_evap);
  m_water_total = m_water_free + massWaterAbs.m_absorbed;

  // ---- Boiling regime -------------------------------------------------------
  boiling = T >= BOILING_POINT_C and m_water_free > 0.0;

  // ---- Connect sub-block inputs ---------------------------------------------
  changeTemp.T             = T;
  changeTemp.tempExt       = tempExt;
  changeTemp.powerPct      = powerPct;
  changeTemp.m_rice        = m_rice;
  changeTemp.m_water_total = m_water_total;

  massWaterAbs.T      = T;
  massWaterAbs.m_rice = m_rice;

  massWaterEvap.boiling  = boiling;
  massWaterEvap.powerPct = powerPct;
  massWaterEvap.tempExt  = tempExt;

  volumeRice.T               = T;
  volumeRice.volRiceInit     = volRiceInit;
  volumeRice.m_water_absorbed = massWaterAbs.m_absorbed;

  // ---- Temperature ODE ------------------------------------------------------
  // Outside boiling: integrate dT/dt.
  // During boiling: temperature is held at the boiling point (der = 0).
  der(T) = if boiling then 0.0 else changeTemp.dTdt;

  // Snap temperature exactly to the boiling point at the onset of boiling
  // to prevent drift above it.
  when T >= BOILING_POINT_C and m_water_free > 0.0 then
    reinit(T, BOILING_POINT_C);
  end when;

  // ---- Outputs --------------------------------------------------------------
  tempC        = T;
  massWaterKg  = m_water_free;
  massWaterPct = if m_water_init > 0.0 then 100.0 * m_water_free / m_water_init else 0.0;
  volRiceM3    = volumeRice.volRiceM3;
  volRicePct   = volumeRice.volRicePct;

  annotation(Documentation(info="<html>
    <p><b>PhysicalModel</b> is the plant model that approximates the thermal behaviour of the
    rice cooker and the progressive swelling of the rice.</p>
    <h4>Inputs</h4>
    <ul>
      <li><em>tempExt</em> – ambient temperature [degC]</li>
      <li><em>powerPct</em> – heater command [0-100 %]</li>
      <li><em>volWaterInit</em> – initial water mass scale [kg]</li>
      <li><em>volRiceInit</em> – initial rice volume [m3]</li>
    </ul>
    <h4>Outputs</h4>
    <ul>
      <li><em>tempC</em> – pot temperature [degC]</li>
      <li><em>massWaterKg</em> – remaining free water mass [kg]</li>
      <li><em>massWaterPct</em> – remaining water relative to initial [%]</li>
      <li><em>volRiceM3</em> – rice volume [m3]</li>
      <li><em>volRicePct</em> – rice volume relative to initial [%]</li>
    </ul>
    <h4>Three main regimes</h4>
    <ol>
      <li>Before boiling – temperature rises, rice absorbs water.</li>
      <li>During boiling – temperature is clamped to 100 degC, water evaporates.</li>
      <li>After free water is gone – only temperature evolves (no more evaporation).</li>
    </ol>
    <p>Heat loss to the environment is applied throughout all phases.</p>
  </html>"));

end PhysicalModel;
