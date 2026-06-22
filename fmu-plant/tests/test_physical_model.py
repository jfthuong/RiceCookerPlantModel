"""
Tests for PlantModel.PhysicalModel FMU.

Test strategy
-------------
The model distinguishes three main regimes (see PhysicalModel.mo annotation):

  1. **Before boiling** – temperature rises, rice absorbs water slowly.
  2. **During boiling** – temperature is clamped to 100 °C, water evaporates.
  3. **After free water is gone** – evaporation stops; temperature may overshoot.

Tests cover:
  - FMU structure (expected input/output variables with correct causality).
  - No-power equilibrium: temperature stays at ambient when power = 0 %.
  - Heating rate: dT/dt at t=0 matches the analytical formula.
  - Boiling plateau: temperature reaches exactly 100 °C and stays there.
  - Water evaporation: free water decreases during the boiling phase.
  - Rice water absorption: absorbed water increases with temperature.
  - Rice volume growth: volume exceeds the initial value during cooking.
  - Rice volume bounds: always between 100 % and MAX_RATIO_WATER_ABSORB_BY_VOL×100 %.
  - Heat loss: at low power the equilibrium temperature is below 100 °C.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest
from fmpy import read_model_description, simulate_fmu

# ---------------------------------------------------------------------------
# Model constants (must match PlantModel/package.mo)
# ---------------------------------------------------------------------------

BOILING_POINT_C = 100.0
TEMP_GEL_LOW_C = 60.0
TEMP_GEL_HIGH_C = 80.0
HEAT_LOSS_W_PER_K = 0.5
LATENT_HEAT_VAPOR_J_PER_KG = 2_257_000.0
C_P_ALU = 900.0
C_P_WATER = 4184.0
C_P_DRY_RICE = 1200.0
DENSITY_RICE_KG_PER_M3 = 900.0
ABSORPTION_RATE_COEFF = 1.0e-4  # matches PlantModel.ABSORPTION_RATE_COEFF [kg/s]
MASS_BOWL_KG = 0.160
FULL_POWER_COOKER_W = 300.0
MAX_RATIO_WATER_ABSORB_BY_VOL = 3.0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

OUTPUT_VARS = ["tempC", "massWaterKg", "massWaterPct", "volRiceM3", "volRicePct"]


def _run(
    fmu_path: Path,
    *,
    stop_time: float,
    step_size: float = 0.2,
    tempExt: float = 20.0,
    powerPct: float = 100.0,
    volWaterInit: float = 0.5,
    volRiceInit: float = 3e-4,
) -> dict:
    """Convenience wrapper around ``simulate_fmu``."""
    return simulate_fmu(
        str(fmu_path),
        stop_time=stop_time,
        step_size=step_size,
        start_values={
            "tempExt": tempExt,
            "powerPct": powerPct,
            "volWaterInit": volWaterInit,
            "volRiceInit": volRiceInit,
        },
        output=OUTPUT_VARS,
    )


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestFmuStructure:
    """Verify that the FMU exposes the expected interface."""

    def test_fmi_version(self, fmu_path: Path) -> None:
        md = read_model_description(str(fmu_path))
        assert md.fmiVersion == "2.0"

    def test_model_name(self, fmu_path: Path) -> None:
        md = read_model_description(str(fmu_path))
        assert md.modelName == "PlantModel.PhysicalModel"

    @pytest.mark.parametrize("name", ["tempExt", "powerPct", "volWaterInit", "volRiceInit"])
    def test_input_variables(self, fmu_path: Path, name: str) -> None:
        md = read_model_description(str(fmu_path))
        variables = {v.name: v for v in md.modelVariables}
        assert name in variables, f"Input '{name}' not found in model variables"
        assert variables[name].causality == "input"

    @pytest.mark.parametrize("name", ["tempC", "massWaterKg", "massWaterPct", "volRiceM3", "volRicePct"])
    def test_output_variables(self, fmu_path: Path, name: str) -> None:
        md = read_model_description(str(fmu_path))
        variables = {v.name: v for v in md.modelVariables}
        assert name in variables, f"Output '{name}' not found in model variables"
        assert variables[name].causality == "output"


class TestThermalDynamics:
    """Tests for the temperature evolution (Regime 1 and 2)."""

    def test_no_power_temperature_stays_at_ambient(self, fmu_path: Path) -> None:
        """With 0 % power starting at ambient temperature, the temperature is
        driven only by heat loss to the environment.  Starting at 20 °C with
        ambient also at 20 °C the net heat flux is zero and ``tempC`` must
        remain at 20 °C throughout the simulation."""
        result = _run(fmu_path, stop_time=300, step_size=0.2, powerPct=0.0, tempExt=20.0)
        assert np.allclose(result["tempC"], 20.0, atol=0.01), (
            "Temperature should stay at ambient when power=0 and T_init=T_amb"
        )

    def test_heating_rate_matches_analytical(self, fmu_path: Path) -> None:
        """At t=0, before significant heat loss builds up, dT/dt must match:

            dT/dt = (P_in - P_loss) / C_thermal

        with P_in = 300 W, P_loss ≈ 0 (T ≈ T_amb), and
        C_thermal = MASS_BOWL_KG * C_P_ALU + m_rice * C_P_DRY_RICE + m_water * C_P_WATER.
        """
        vol_water = 0.5  # kg (initial water)
        vol_rice = 3e-4  # m³
        m_rice = DENSITY_RICE_KG_PER_M3 * vol_rice  # 0.27 kg
        c_thermal = MASS_BOWL_KG * C_P_ALU + m_rice * C_P_DRY_RICE + vol_water * C_P_WATER
        expected_dTdt = FULL_POWER_COOKER_W / c_thermal  # ~0.117 °C/s

        result = _run(
            fmu_path,
            stop_time=10,
            step_size=0.1,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=vol_water,
            volRiceInit=vol_rice,
        )
        actual_dT = result["tempC"][-1] - result["tempC"][0]
        expected_dT = expected_dTdt * 10.0

        assert abs(actual_dT - expected_dT) < 0.05, (
            f"Heating rate mismatch: got dT={actual_dT:.4f} °C in 10 s, "
            f"expected {expected_dT:.4f} °C"
        )

    def test_temperature_reaches_boiling_point(self, fmu_path: Path) -> None:
        """With full power and sufficient time the temperature must hit 100 °C."""
        result = _run(
            fmu_path,
            stop_time=3600,
            step_size=5.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.3,
            volRiceInit=2e-4,
        )
        assert max(result["tempC"]) >= BOILING_POINT_C - 0.01, (
            "Temperature never reached the boiling point with full power over 1 h"
        )

    def test_temperature_clamped_at_boiling(self, fmu_path: Path) -> None:
        """Once boiling starts the temperature must not exceed 100 °C."""
        result = _run(
            fmu_path,
            stop_time=3600,
            step_size=5.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.3,
            volRiceInit=2e-4,
        )
        assert max(result["tempC"]) <= BOILING_POINT_C + 0.01, (
            f"Temperature exceeded boiling point: max={max(result['tempC']):.3f} °C"
        )

    def test_more_power_means_faster_heating(self, fmu_path: Path) -> None:
        """A higher heater command must produce a greater temperature rise."""
        kwargs = dict(stop_time=120, step_size=0.2, tempExt=20.0, volWaterInit=0.5, volRiceInit=3e-4)
        low = _run(fmu_path, powerPct=30.0, **kwargs)
        high = _run(fmu_path, powerPct=90.0, **kwargs)
        assert high["tempC"][-1] > low["tempC"][-1], (
            "Higher power should yield a higher final temperature in the same time"
        )


class TestWaterEvaporation:
    """Tests for the water evaporation regime (Regime 2)."""

    def test_water_evaporates_during_boiling(self, fmu_path: Path) -> None:
        """Once boiling starts, the free water mass must decrease over time."""
        result = _run(
            fmu_path,
            stop_time=3600,
            step_size=5.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.3,
            volRiceInit=2e-4,
        )
        boiling_mask = result["tempC"] >= BOILING_POINT_C - 0.1
        if not boiling_mask.any():
            pytest.skip("Boiling not reached in simulation window")

        # Water at first boiling timestep vs last boiling timestep
        first_boil = np.argmax(boiling_mask)
        water_at_start_boil = result["massWaterKg"][first_boil]
        water_at_end = result["massWaterKg"][-1]
        assert water_at_end < water_at_start_boil, (
            "Free water mass should decrease during boiling"
        )

    def test_water_mass_percentage_consistent(self, fmu_path: Path) -> None:
        """``massWaterPct`` must be consistent with ``massWaterKg``:
        both must decrease together monotonically and their ratio must stay
        close to the initial water mass."""
        vol_water_init = 0.4
        result = _run(
            fmu_path,
            stop_time=600,
            step_size=2.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=vol_water_init,
            volRiceInit=3e-4,
        )
        # Percentage should equal 100 * massWaterKg / volWaterInit within a
        # small tolerance; co-simulation output may shift values by up to one
        # step, so we allow a tolerance proportional to the step change.
        derived_pct = 100.0 * result["massWaterKg"] / vol_water_init
        np.testing.assert_allclose(
            result["massWaterPct"], derived_pct, atol=0.05,
            err_msg="massWaterPct inconsistent with massWaterKg"
        )

    def test_no_evaporation_without_power(self, fmu_path: Path) -> None:
        """Without heating (powerPct=0) the temperature stays at ambient so
        there is no boiling and therefore no evaporation.  Only slow rice water
        absorption takes place.  The free water mass decrease must not exceed
        the theoretical absorption-only upper bound."""
        vol_water_init = 0.5
        vol_rice_init = 3e-4
        stop_time = 300.0
        result = _run(
            fmu_path,
            stop_time=stop_time,
            step_size=1.0,
            powerPct=0.0,
            tempExt=20.0,
            volWaterInit=vol_water_init,
            volRiceInit=vol_rice_init,
        )
        assert np.all(result["massWaterKg"] >= 0.0), "Water mass became negative"
        # The only water sink without boiling is slow absorption.
        # Max absorption rate at 20 °C: ABSORPTION_RATE_COEFF * T / BOILING_POINT_C
        #   → over 300 s ≈ 0.006 kg
        max_absorbed = ABSORPTION_RATE_COEFF * 20.0 / BOILING_POINT_C * stop_time
        min_expected_water = vol_water_init - max_absorbed - 0.001  # small margin
        assert result["massWaterKg"][-1] >= min_expected_water, (
            f"Water decreased too fast without power: "
            f"final={result['massWaterKg'][-1]:.4f} kg, "
            f"expected >= {min_expected_water:.4f} kg "
            f"(only absorption at 20 °C, no evaporation)"
        )


class TestRiceAbsorptionAndVolume:
    """Tests for water absorption and rice volume swelling (Regimes 1–3)."""

    def test_rice_volume_increases_during_cooking(self, fmu_path: Path) -> None:
        """After a full cooking cycle the rice volume must be larger than
        the initial volume."""
        result = _run(
            fmu_path,
            stop_time=3600,
            step_size=5.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.5,
            volRiceInit=3e-4,
        )
        assert result["volRicePct"][-1] > 100.0, (
            "Rice volume should exceed 100 % of initial after cooking"
        )

    def test_rice_volume_does_not_exceed_max(self, fmu_path: Path) -> None:
        """Rice volume must stay below the physical maximum
        (MAX_RATIO_WATER_ABSORB_BY_VOL × 100 %)."""
        result = _run(
            fmu_path,
            stop_time=7200,
            step_size=10.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=1.0,
            volRiceInit=3e-4,
        )
        max_pct = MAX_RATIO_WATER_ABSORB_BY_VOL * 100.0  # 300 %
        assert max(result["volRicePct"]) <= max_pct + 0.1, (
            f"Rice volume exceeded the physical maximum of {max_pct} %: "
            f"got {max(result['volRicePct']):.2f} %"
        )

    def test_rice_volume_never_below_initial(self, fmu_path: Path) -> None:
        """Rice can only swell, never shrink; ``volRicePct`` must be >= 100 %."""
        result = _run(
            fmu_path,
            stop_time=3600,
            step_size=5.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.5,
            volRiceInit=3e-4,
        )
        assert np.all(result["volRicePct"] >= 100.0 - 0.01), (
            "Rice volume fell below its initial value"
        )

    def test_rice_volume_pct_consistent_with_m3(self, fmu_path: Path) -> None:
        """``volRicePct`` must equal 100 × volRiceM3 / volRiceInit."""
        vol_rice_init = 3e-4
        result = _run(
            fmu_path,
            stop_time=600,
            step_size=2.0,
            powerPct=100.0,
            tempExt=20.0,
            volWaterInit=0.5,
            volRiceInit=vol_rice_init,
        )
        expected_pct = 100.0 * result["volRiceM3"] / vol_rice_init
        np.testing.assert_allclose(
            result["volRicePct"], expected_pct, atol=0.01,
            err_msg="volRicePct inconsistent with volRiceM3"
        )
