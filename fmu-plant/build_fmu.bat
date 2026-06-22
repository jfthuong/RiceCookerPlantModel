@echo off
setlocal
REM ============================================================
REM  build_fmu.bat – Build an FMU (FMI 2.0, ME + CS) for
REM  PlantModel.PhysicalModel using OpenModelica.
REM  Output: build\windows\PlantModel.PhysicalModel.fmu
REM
REM  Usage: run from the fmu-plant directory.
REM  Prerequisite: OpenModelica installed.
REM ============================================================

set "OMC_EXE="
if defined OPENMODELICAHOME (
    if exist "%OPENMODELICAHOME%\bin\omc.exe" set "OMC_EXE=%OPENMODELICAHOME%\bin\omc.exe"
)

if not defined OMC_EXE (
    for %%I in (omc.exe) do set "OMC_EXE=%%~$PATH:I"
)

if not defined OMC_EXE (
    for /d %%D in ("C:\Program Files\OpenModelica*") do (
        if exist "%%~fD\bin\omc.exe" set "OMC_EXE=%%~fD\bin\omc.exe"
    )
)

if not defined OMC_EXE (
    echo ERROR: omc.exe not found.
    echo Checked OPENMODELICAHOME, PATH, and C:\Program Files\OpenModelica*\bin.
    echo Set OPENMODELICAHOME or add omc.exe to PATH and retry.
    goto Error
)

cd %~dp0
if not exist "build\windows\" mkdir "build\windows"
cd build\windows

echo Building FMU for PlantModel.PhysicalModel (Windows) ...
"%OMC_EXE%" ..\..\build_fmu.mos

if not exist "PlantModel.PhysicalModel.fmu" (
    echo.
    echo ERROR: FMU build failed. Review the output above for details.
    cd ..\..
    goto Error
)

echo.
echo FMU build completed successfully.
echo Output: build\windows\PlantModel.PhysicalModel.fmu
cd ..\..
timeout /t 20
exit /b 0

:Error
echo.
echo An error occurred during the FMU build process.
echo Please review the output above for details.
echo.
pause
exit /b 1

