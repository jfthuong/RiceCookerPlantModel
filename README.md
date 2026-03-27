# RiceCookerPlantModel

A Modelica plant model of a rice cooker, compatible with OpenModelica.

## Overview

`PlantModel` models the thermal behaviour of the cooker and the progressive swelling of the rice.
It is designed to be coupled with a controller during system simulation and can be exported as an
FMU (FMI 2.0) for co-simulation.

## Project structure

```
PlantModel/                 Modelica package (open package.mo in OpenModelica)
  package.mo                Package declaration and physical/cooker constants
  package.order             Class ordering for OpenModelica
  ChangeTemp.mo             Block: temperature rate of change outside boiling
  MassWaterAbsorbed.mo      Block: cumulative water absorption by rice
  MassWaterEvap.mo          Block: cumulative water evaporation during boiling
  VolumeRice.mo             Block: rice volume swelling from absorption + temperature
  ComputeHeight.mo          Block: volume-to-bowl-height conversion (visualisation)
  PhysicalModel.mo          Main plant block – FMU export target
  TestPhysicalModel.mo      Simulation scenario: 1-hour cook at 80 % heater power
build/
  PlantModel.PhysicalModel.fmu  Pre-built FMU (win64 + linux64, FMI 2.0 ME+CS)
tests/
  conftest.py               Pytest session fixture that locates / builds the FMU
  test_physical_model.py    Physics-based pytest test suite
  requirements.txt          Python test dependencies (fmpy, pytest)
build_fmu.mos               OpenModelica script to export the FMU into build/
build_fmu.bat               Windows batch wrapper for omc
build_fmu.sh                Linux / macOS shell wrapper for omc
```

## Opening in OpenModelica (OMEdit)

1. Launch **OMEdit** (OpenModelica Connection Editor).
2. Go to **File → Open Model/Library File** and open `PlantModel/package.mo`.
3. The entire package (all sub-classes) loads automatically.
4. To run the included test simulation, open `PlantModel.TestPhysicalModel` in the diagram
   view and click **Simulate**.

## Building the FMU

### Windows

Run from the repository root:

```bat
build_fmu.bat
```

### Linux / macOS

```bash
bash build_fmu.sh
```

Both scripts call `omc` with `build_fmu.mos` and produce
`build/PlantModel.PhysicalModel.fmu`.

**Prerequisite:** [OpenModelica](https://openmodelica.org) must be installed and `omc` must be
on the system `PATH`.

## Running the tests

Install the test dependencies and run pytest from the repository root:

```bash
pip install -r tests/requirements.txt
pytest tests/
```

The session-scoped `fmu_path` fixture checks whether
`build/PlantModel.PhysicalModel.fmu` already exists.  If it does, the
pre-built FMU is used immediately.  If `omc` is available on the PATH it is
rebuilt first.

The test suite covers:

| Group | What is verified |
|-------|-----------------|
| `TestFmuStructure` | FMI version, model name, causality of every I/O port |
| `TestThermalDynamics` | No-power equilibrium, analytical heating rate, boiling clamping |
| `TestWaterEvaporation` | Evaporation during boiling, percentage consistency, absorption-only bound |
| `TestRiceAbsorptionAndVolume` | Volume growth, physical upper/lower bounds, pct-vs-m³ consistency |

## PhysicalModel – interface

| Port | Direction | Unit | Description |
|------|-----------|------|-------------|
| `tempExt` | Input | °C | Ambient temperature |
| `powerPct` | Input | % | Heater command (0–100) |
| `volWaterInit` | Input | kg | Initial water mass scale |
| `volRiceInit` | Input | m³ | Initial rice volume |
| `tempC` | Output | °C | Pot temperature |
| `massWaterKg` | Output | kg | Remaining free water mass |
| `massWaterPct` | Output | % | Remaining water relative to initial |
| `volRiceM3` | Output | m³ | Rice volume |
| `volRicePct` | Output | % | Rice volume relative to initial |

## Physical constants

| Constant | Value | Unit | Meaning |
|----------|------:|------|---------|
| `BOILING_POINT_C` | 100 | °C | Water boiling point |
| `TEMP_GEL_LOW_C` | 60 | °C | Lower gelatinisation bound |
| `TEMP_GEL_HIGH_C` | 80 | °C | Upper gelatinisation bound |
| `HEAT_LOSS_W_PER_K` | 0.5 | W/K | Lumped thermal loss |
| `LATENT_HEAT_VAPOR_J_PER_KG` | 2 257 000 | J/kg | Latent heat of vaporisation |
| `C_P_ALU` | 900 | J/(kg·K) | Specific heat of aluminium |
| `C_P_WATER` | 4184 | J/(kg·K) | Specific heat of water |
| `C_P_DRY_RICE` | 1200 | J/(kg·K) | Specific heat of dry rice |
| `DENSITY_RICE_KG_PER_M3` | 900 | kg/m³ | Dry rice density |
| `MAX_RATIO_WATER_ABSORB_BY_MASS` | 2 | — | Max hydrated-to-dry mass ratio |
| `MAX_RATIO_WATER_ABSORB_BY_VOL` | 3 | — | Max swollen-to-initial volume ratio |
| `S0_BASELINE_SWELLING` | 0.35 | — | Baseline swelling below gelatinisation |
| `MASS_BOWL_KG` | 0.160 | kg | Aluminium bowl mass |
| `DIAMETER_BOWL_CM` | 12.5 | cm | Bowl diameter |
| `FULL_POWER_COOKER_W` | 300 | W | Heater full power |

## Physical behaviour modelled

The model distinguishes three main regimes:

* **Before boiling** – temperature rises while rice absorbs water.
* **During boiling** – temperature is clamped to 100 °C while water evaporates and is still
  absorbed.
* **After free water is gone** – only temperature evolves.

Heat loss to the environment is applied throughout all phases.
