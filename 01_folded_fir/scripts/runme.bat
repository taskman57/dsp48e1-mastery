@echo off
setlocal enabledelayedexpansion

REM Set directory context to the location of this batch script
set SCRIPT_DIR=%~dp0

echo ==============================================================================
echo Building Vivado Project using fir_script.tcl...
echo ==============================================================================

call settings64.bat
@echo vivado tcl script is running
@echo check log files for progress
call vivado -nolog -nojournal -mode batch -source ../scripts/fir_script.tcl -tclargs %1 > "../scripts/fir_script.log"
pause

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Vivado project generation failed. Check vivado_build.log for details.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Project created successfully!
echo.

set /p OPEN_GUI="Do you want to open the project in Vivado GUI now? (Y/N): "
if /i "%OPEN_GUI%"=="Y" (
    echo Opening Vivado GUI...
    start "" vivado "%SCRIPT_DIR%..\project\folded_fir_proj.xpr"
)

endlocal