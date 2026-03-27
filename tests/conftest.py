"""
Pytest configuration for PlantModel FMU tests.

The session-scoped ``fmu_path`` fixture locates (or builds) the FMU before any
test runs.  If OpenModelica (``omc``) is available the FMU is rebuilt from
source; otherwise the pre-built FMU committed under ``build/`` is used.  If
neither exists, the entire test session is aborted with a clear error message.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.resolve()
FMU_PATH = REPO_ROOT / "build" / "PlantModel.PhysicalModel.fmu"


def _build_fmu() -> None:
    """Run the OpenModelica build script from the repository root."""
    script = REPO_ROOT / "build_fmu.sh"
    omc = shutil.which("omc")
    if omc is None:
        raise RuntimeError("omc not found on PATH; cannot build FMU.")
    (REPO_ROOT / "build").mkdir(exist_ok=True)
    result = subprocess.run(
        ["bash", str(script)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not FMU_PATH.exists():
        raise RuntimeError(
            f"FMU build failed.\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def fmu_path() -> Path:
    """Return the path to the compiled FMU, building it first if necessary.

    Resolution order:
    1. If ``build/PlantModel.PhysicalModel.fmu`` already exists, use it.
    2. If ``omc`` is on the PATH, build the FMU and then use it.
    3. Otherwise abort with a descriptive error.
    """
    if FMU_PATH.exists():
        # Validate the FMU is readable before trusting it.
        try:
            from fmpy import read_model_description
            read_model_description(str(FMU_PATH))
        except Exception as exc:
            pytest.fail(
                f"Pre-built FMU at {FMU_PATH} is unreadable ({exc}). "
                "Delete it and rebuild with build_fmu.sh / build_fmu.bat."
            )
        return FMU_PATH

    try:
        _build_fmu()
    except RuntimeError as exc:
        pytest.fail(str(exc))

    return FMU_PATH
