package PlantModel "Rice Cooker Plant Model"
  annotation(
    Documentation(info="<html>
      <p>Modelica plant model for a rice cooker, compatible with OpenModelica.</p>
      <p>Models the thermal behaviour of the cooker and the progressive swelling of the rice.</p>
      <p>The main block for simulation or FMU export is <b>PhysicalModel</b>.</p>
    </html>")
  );

  // ---- Physical and rice characteristics constants ----

  constant Real BOILING_POINT_C             = 100.0    "Boiling point [degC]";
  constant Real TEMP_GEL_LOW_C              =  60.0    "Lower bound of the gelatinisation range [degC]";
  constant Real TEMP_GEL_HIGH_C             =  80.0    "Upper bound of the gelatinisation range [degC]";
  constant Real HEAT_LOSS_W_PER_K           =   0.5    "Lumped thermal loss coefficient [W/K]";
  constant Real LATENT_HEAT_VAPOR_J_PER_KG  = 2257000.0 "Latent heat of vaporisation of water [J/kg]";
  constant Real C_P_ALU                     =  900.0   "Specific heat capacity of aluminium [J/(kg.K)]";
  constant Real C_P_WATER                   = 4184.0   "Specific heat capacity of water [J/(kg.K)]";
  constant Real C_P_DRY_RICE                = 1200.0   "Specific heat capacity of dry rice [J/(kg.K)]";
  constant Real DENSITY_RICE_KG_PER_M3      =  900.0   "Dry rice density [kg/m3]";
  constant Real MAX_RATIO_WATER_ABSORB_BY_MASS = 2.0   "Maximum final mass ratio: hydrated rice / dry rice";
  constant Real MAX_RATIO_WATER_ABSORB_BY_VOL  = 3.0   "Maximum final volume ratio: swollen rice / initial rice";
  constant Real S0_BASELINE_SWELLING        =   0.35   "Baseline swelling factor before gelatinisation";
  constant Real ABSORPTION_RATE_COEFF       =   1.0e-4 "Water absorption rate coefficient at boiling point [kg/s]";
  constant Real ABSORPTION_SAT_DENOM_FACTOR =   0.5    "Scaling factor for the saturation reference mass in the r_abs formula [-]";

  // ---- Rice cooker constants ----

  constant Real MASS_BOWL_KG      =   0.160  "Aluminium bowl mass [kg]";
  constant Real DIAMETER_BOWL_CM  =  12.5    "Bowl diameter used to derive displayed liquid/rice heights [cm]";
  constant Real FULL_POWER_COOKER_W = 300.0  "Heater full power [W]";

end PlantModel;
