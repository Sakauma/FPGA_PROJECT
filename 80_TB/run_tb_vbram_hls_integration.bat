@echo off
setlocal

set REPO_ROOT=%~dp0..
set VIVADO_SETTINGS=D:\AMD\2025.2\Vivado\settings64.bat
set BUILD_DIR=%REPO_ROOT%\80_TB\build_vbram_hls_integration

if not exist "%VIVADO_SETTINGS%" (
    echo ERROR: Vivado settings script not found: %VIVADO_SETTINGS%
    exit /b 1
)

call "%VIVADO_SETTINGS%"
if errorlevel 1 exit /b 1

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

call xvlog -sv ^
    -log xvlog_tb_vbram_hls_integration.log ^
    ..\tb_vbram_hls_integration.v ^
    ..\..\20_HDL\22_User\Common\async_fifo_v1000.v ^
    ..\..\20_HDL\22_User\axis\fifo_to_axis.v ^
    ..\..\20_HDL\22_User\SRIO_2_BRAM\readbram_to_axis64\readbram_to_fifo.v ^
    ..\..\20_HDL\22_User\SRIO_2_BRAM\readbram_to_axis64\readbram_to_axis64_top.v ^
    ..\..\20_HDL\22_User\SRIO_2_BRAM\undistort_demo_hls_wrap.v ^
    ..\..\20_HDL\22_User\SRIO_2_BRAM\vbram_lutaxi4_to_axis.v
if errorlevel 1 exit /b 1

call xelab -debug typical ^
    -log xelab_tb_vbram_hls_integration.log ^
    work.tb_vbram_hls_integration ^
    -s tb_vbram_hls_integration_snap
if errorlevel 1 exit /b 1

call xsim tb_vbram_hls_integration_snap ^
    -runall ^
    -log xsim_tb_vbram_hls_integration.log
if errorlevel 1 exit /b 1

endlocal
