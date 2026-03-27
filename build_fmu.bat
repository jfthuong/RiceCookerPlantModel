@echo off
REM ============================================================
REM  build_fmu.bat – Build an FMU (FMI 2.0, ME + CS) for
REM  PlantModel.PhysicalModel using OpenModelica.
REM  Output: build\windows\PlantModel.PhysicalModel.fmu
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

if not exist "build\windows\" mkdir "build\windows"
cd build\windows

echo Building FMU for PlantModel.PhysicalModel (Windows) ...
omc ..\..\build_fmu.mos

if not exist "PlantModel.PhysicalModel.fmu" (
    echo.
    echo ERROR: FMU build failed. Review the output above for details.
    cd ..\..
    exit /b 1
)

echo.
echo FMU build completed successfully.
echo Output: build\windows\PlantModel.PhysicalModel.fmu
cd ..\..
