@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "MOD_DIR=%%~fI"
cd /d "%MOD_DIR%"

set "UNISIM_DIR=%MOD_DIR%\ghdl_unisim"
set "GHDL_STD=--std=08"
set "GHDL_OPTS=-frelaxed -fsynopsys -Wno-hide"
set "STOP_TIME=30000us"
set "WAVE_FILE=dsp_nr_sweep.ghw"

echo ============================================================================
echo  Module 02 Divider - Automated GHDL Simulation Runner
echo  Working Directory: %CD%
echo ============================================================================
echo.

set "NEED_UNISIM=0"
if not exist "%UNISIM_DIR%" set "NEED_UNISIM=1"

if "%NEED_UNISIM%"=="0" (
    echo [INFO] Existing compiled UNISIM library found at:
    echo        %UNISIM_DIR%
    set "RECOMP="
    set /p "RECOMP=Recompile minimal UNISIM files? [y/N]: "
    if /i "%RECOMP%"=="Y" set "NEED_UNISIM=1"
)

if "%NEED_UNISIM%"=="1" goto :build_unisim
goto :run_sim

:build_unisim
echo.
set "VIVADO_ROOT="
set /p "VIVADO_ROOT=Enter Vivado installation folder (e.g. D:\Xilinx\Vivado\2023.1): "
set "VIVADO_ROOT=%VIVADO_ROOT:"=%"
if "%VIVADO_ROOT%"=="" (
    echo [ERROR] Vivado path cannot be empty.
    exit /b 1
)

set "SRC_UNISIM=%VIVADO_ROOT%\data\vhdl\src\unisims"
if not exist "%SRC_UNISIM%\unisim_vcomp.vhd" (
    echo [ERROR] Could not find unisim_vcomp.vhd at:
    echo         %SRC_UNISIM%\unisim_vcomp.vhd
    exit /b 1
)

set "DSP48_SRC=%SRC_UNISIM%\primitive\DSP48E1.vhd"
if not exist "%DSP48_SRC%" set "DSP48_SRC=%SRC_UNISIM%\DSP48E1.vhd"
if not exist "%DSP48_SRC%" (
    echo [ERROR] Could not find DSP48E1.vhd under %SRC_UNISIM%.
    exit /b 1
)

if not exist "%UNISIM_DIR%" mkdir "%UNISIM_DIR%"

echo [INFO] Compiling minimal UNISIM sources into %UNISIM_DIR% ...
if exist "%SRC_UNISIM%\unisim_VPKG.vhd" (
    ghdl -a %GHDL_STD% %GHDL_OPTS% --work=unisim --workdir="%UNISIM_DIR%" "%SRC_UNISIM%\unisim_VPKG.vhd"
    if errorlevel 1 exit /b 1
)

ghdl -a %GHDL_STD% %GHDL_OPTS% --work=unisim --workdir="%UNISIM_DIR%" "%SRC_UNISIM%\unisim_vcomp.vhd"
if errorlevel 1 exit /b 1

ghdl -a %GHDL_STD% %GHDL_OPTS% --work=unisim --workdir="%UNISIM_DIR%" "%DSP48_SRC%"
if errorlevel 1 exit /b 1

echo [OK] Minimal UNISIM compilation complete.
echo.

:run_sim
echo [INFO] Analyzing RTL and testbench sources...
ghdl -a %GHDL_STD% %GHDL_OPTS% -P"%UNISIM_DIR%" ^
    rtl_src\divider_pkg.vhd ^
    rtl_src\DSP_wrapper.vhd ^
    rtl_src\dsp_nr_step.vhd ^
    rtl_src\div_seq_restoring.vhd ^
    rtl_src\div_seq_nonrestoring.vhd ^
    rtl_sim\tb_div_seq_full.vhd ^
    rtl_sim\tb_div_sweep.vhd
if errorlevel 1 (
    echo [ERROR] RTL/Testbench analysis failed.
    exit /b 1
)

echo [INFO] Elaborating tb_div_sweep...
ghdl -e %GHDL_STD% %GHDL_OPTS% -P"%UNISIM_DIR%" tb_div_sweep
if errorlevel 1 (
    echo [ERROR] Elaboration failed.
    exit /b 1
)

echo [INFO] Running simulation (stop-time=%STOP_TIME%, wave=%WAVE_FILE%)...
ghdl -r %GHDL_STD% -frelaxed -fsynopsys -P"%UNISIM_DIR%" tb_div_sweep --ieee-asserts=disable --wave="%WAVE_FILE%" --stop-time=%STOP_TIME%
if errorlevel 1 (
    echo [ERROR] Simulation failed.
    exit /b 1
)

echo.
echo [DONE] Simulation completed. Waveform saved to %CD%\%WAVE_FILE%
endlocal
exit /b 0