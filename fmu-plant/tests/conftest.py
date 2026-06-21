"""
Pytest configuration for PlantModel FMU tests.

The session-scoped ``fmu_path`` fixture locates (or builds) the platform-specific
FMU before any test runs.

Platform-to-FMU mapping
-----------------------
- Linux / macOS  → ``build/linux/PlantModel.PhysicalModel.fmu``
- Windows        → ``build/windows/PlantModel.PhysicalModel.fmu``

If the FMU for the current platform is not already present and OpenModelica
(``omc``) is available the FMU is rebuilt from source.  If neither condition
is satisfied the entire test session is aborted with a clear error message.
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
MODEL_DIR = REPO_ROOT / "src"
BUILD_DIR = REPO_ROOT / "build"

# Select the platform-specific sub-directory and build script.
if sys.platform.startswith("win"):
    PLATFORM_SUBDIR = "windows"
    BUILD_SCRIPT = REPO_ROOT / "build_fmu.bat"
else:
    PLATFORM_SUBDIR = "linux"
    BUILD_SCRIPT = REPO_ROOT / "build_fmu.sh"

FMU_PATH = BUILD_DIR / PLATFORM_SUBDIR / "PlantModel.PhysicalModel.fmu"


def _build_fmu() -> None:
    """Run the platform-appropriate build script from the repository root."""
    omc = shutil.which("omc")
    if omc is None:
        raise RuntimeError("omc not found on PATH; cannot build FMU.")
    FMU_PATH.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform.startswith("win"):
        cmd = [str(BUILD_SCRIPT)]
    else:
        cmd = ["bash", str(BUILD_SCRIPT)]

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
    """Return the path to the compiled FMU for the current platform.

    Resolution order:
    1. If the platform FMU already exists and is readable, use it
       (emit a warning if it is older than any source ``.mo`` file).
    2. If ``omc`` is on the PATH, build the FMU and then use it.
    3. Otherwise abort with a descriptive error.

    Platform mapping:
    - Linux / macOS → ``build/linux/PlantModel.PhysicalModel.fmu``
    - Windows       → ``build/windows/PlantModel.PhysicalModel.fmu``
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
        more_recent = [
            src for src in MODEL_DIR.glob("*.mo")
            if src.stat().st_mtime > fmu_mtime
        ]
        if more_recent:
            warn(
                f"Pre-built FMU at {FMU_PATH} is older than source files: "
                + ", ".join(str(src) for src in more_recent)
                + ". Consider rebuilding with build_fmu.sh / build_fmu.bat."
            )
        return FMU_PATH

    try:
        _build_fmu()
    except RuntimeError as exc:
        pytest.fail(str(exc))

    return FMU_PATH
