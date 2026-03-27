#!/usr/bin/env bash
# ============================================================
#  build_fmu.sh – Build an FMU (FMI 2.0, ME + CS) for
#  PlantModel.PhysicalModel using OpenModelica.
#
#  Usage: run from the repository root directory.
#  Prerequisite: OpenModelica installed; omc on the system PATH.
# ============================================================

set -euo pipefail

if ! command -v omc &>/dev/null; then
    echo "ERROR: omc not found."
    echo "Please install OpenModelica (https://openmodelica.org) and add it to PATH."
    exit 1
fi

mkdir -p build
cd build

echo "Building FMU for PlantModel.PhysicalModel ..."
omc ../build_fmu.mos

if [ ! -f "PlantModel.PhysicalModel.fmu" ]; then
    echo ""
    echo "ERROR: FMU build failed. Review the output above for details."
    cd ..
    exit 1
fi

echo ""
echo "FMU build completed successfully."
echo "Output: build/PlantModel.PhysicalModel.fmu"
cd ..