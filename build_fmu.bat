@echo off
REM ============================================================
REM  build_fmu.bat – Build an FMU (FMI 2.0, ME + CS) for
REM  PlantModel.PhysicalModel using OpenModelica.
REM
REM  Usage: run from the repository root directory.
REM  Prerequisite: OpenModelica installed; omc on the system PATH.
REM ============================================================

where omc >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: omc not found.
    echo Please install OpenModelica ^(https://openmodelica.org^) and add it to PATH.
    exit /b 1
)

echo Building FMU for PlantModel.PhysicalModel ...
omc build_fmu.mos

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: FMU build failed. Review the output above for details.
    exit /b 1
)

echo.
echo FMU build completed successfully.
echo Output: PlantModel.PhysicalModel.fmu
