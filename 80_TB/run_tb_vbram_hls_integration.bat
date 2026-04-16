// ============================================================================
// 新增维护说明
// 文件职责      : 当前文件为手工维护源码，承担本模块/脚本的真实实现。
// 维护边界      : 本注释块仅补充维护说明，不改写任何原有说明、历史注释或现有逻辑。
// 修改约束      : 后续如需继续补充说明，只允许追加中文注释，不得替换旧注释或改动旧代码。
// 生成关系      : 若存在对应生成物，应以当前手工源码为准，禁止反向覆盖本文件。
// ============================================================================
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
