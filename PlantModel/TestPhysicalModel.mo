within PlantModel;

model TestPhysicalModel
  "Simulation scenario: cook 0.3 L rice with 0.5 kg water at 80 % heater power"

  PhysicalModel plant "Plant model under test";
  ComputeHeight waterHeight "Water level display";
  ComputeHeight riceHeight  "Rice level display";

equation
  // ---- Constant inputs ----
  plant.tempExt      = 20.0;   // Ambient temperature 20 degC
  plant.powerPct     = 80.0;   // Heater at 80 %
  plant.volWaterInit = 0.5;    // 0.5 kg initial water
  plant.volRiceInit  = 3.0e-4; // 0.3 L = 3e-4 m3 initial rice volume

  // ---- Bowl height visualisation ----
  waterHeight.volume = plant.massWaterKg / 1000.0; // Approx volume [m3] assuming rho_water ~ 1000 kg/m3
  riceHeight.volume  = plant.volRiceM3;

  annotation(
    experiment(StopTime = 3600, Interval = 1.0),
    Documentation(info="<html>
      <p>Open-loop test simulation cooking rice with constant 80 % heater power from ambient
      temperature 20 degC. Simulation runs for 3600 s (1 hour).</p>
      <p>Observe:
      <ul>
        <li><em>plant.tempC</em> – temperature ramp, plateau at 100 degC, then rise again.</li>
        <li><em>plant.massWaterPct</em> – water percentage decreasing as water evaporates.</li>
        <li><em>plant.volRicePct</em> – rice volume increasing as rice swells.</li>
      </ul></p>
    </html>")
  );

end TestPhysicalModel;
