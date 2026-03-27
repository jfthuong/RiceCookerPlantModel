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
from warnings import warn

import pytest
from fmpy import read_model_description

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.resolve()
MODEL_DIR = REPO_ROOT / "PlantModel"
BUILD_DIR = REPO_ROOT / "build"
FMU_PATH = BUILD_DIR / "PlantModel.PhysicalModel.fmu"

def _build_fmu() -> None:
    """Run the OpenModelica build script from the repository root (build_fmu.sh / build_fmu.bat)."""
    omc = shutil.which("omc")
    if omc is None:
        raise RuntimeError("omc not found on PATH; cannot build FMU.")
    BUILD_DIR.mkdir(exist_ok=True)
    if sys.platform.startswith("win"):
        cmd = [str(REPO_ROOT / "build_fmu.bat")]
    else:
        cmd = ["bash", str(REPO_ROOT / "build_fmu.sh")]

    result = subprocess.run(
        cmd,
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
    1. If ``build/PlantModel.PhysicalModel.fmu`` already exists
        and is more recent than all source files (.mo files), use it.
    2. If ``omc`` is on the PATH, build the FMU and then use it.
    3. Otherwise abort with a descriptive error.
    """
    if FMU_PATH.exists():
        # Validate the FMU is readable before trusting it.
        try:
            read_model_description(str(FMU_PATH))
        except Exception as exc:
            pytest.fail(
                f"Pre-built FMU at {FMU_PATH} is unreadable ({exc}). "
                "Delete it and rebuild with build_fmu.sh / build_fmu.bat."
            )

        fmu_mtime = FMU_PATH.stat().st_mtime
        source_files = MODEL_DIR.glob("*.mo")
        more_recent = [src for src in source_files if src.stat().st_mtime > fmu_mtime]
        if more_recent:
            warn(
                f"Pre-built FMU at {FMU_PATH} is older than source files: "
                + ", ".join(str(src) for src in more_recent)
                + ". We will rebuild the FMU with build_fmu.sh / build_fmu.bat."
            )
        else:
            return FMU_PATH

    try:
        _build_fmu()
    except RuntimeError as exc:
        pytest.fail(str(exc))

    return FMU_PATH
