@echo off
goto :after_chinese_header
REM ============================================================================
REM 新增维护说明
REM 作者          : Egor Izmaylov
REM 文件职责      : 运行 vbram/HLS 集成 testbench，验证 BRAM 读出到 HLS 处理再到 AXIS 输出的链路。
REM 维护边界      : 本脚本只负责 XSim 编译、展开和运行，不修改 Vivado 工程配置。
REM 修改约束      : 新增 RTL 文件或 HLS wrapper 依赖时，必须同步补充 xvlog 文件列表。
REM ============================================================================
:after_chinese_header
chcp 65001 >nul
setlocal

set REPO_ROOT=%~dp0..
set VIVADO_SETTINGS=D:\AMD\2025.2\Vivado\settings64.bat
set BUILD_DIR=%REPO_ROOT%\80_TB\build_vbram_hls_integration_work

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
