@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
set VIVADO_SETTINGS=D:\AMD\2025.2\Vivado\settings64.bat
set BUILD_DIR=%REPO_ROOT%\80_TB\build_srio_video_e2e_work

if "%TB_LINES%"=="" set TB_LINES=8
if "%TB_BACKPRESSURE_CYCLES%"=="" set TB_BACKPRESSURE_CYCLES=4096
if "%TB_GLOBAL_TIMEOUT_CYCLES%"=="" set TB_GLOBAL_TIMEOUT_CYCLES=8000000
if "%TB_PACKET_GAP_CYCLES%"=="" set TB_PACKET_GAP_CYCLES=64
if "%TB_BACKPRESSURE_ALL%"=="" set TB_BACKPRESSURE_ALL=0
if "%TB_RANDOM_READY%"=="" set TB_RANDOM_READY=0
if "%TB_DRAIN_CYCLES%"=="" set TB_DRAIN_CYCLES=512
if "%TB_STRICT_DRAIN%"=="" set TB_STRICT_DRAIN=1
if "%TB_SAVE_E2E_FRAMES%"=="" set TB_SAVE_E2E_FRAMES=0
if "%TB_E2E_OUT_DIR%"=="" set TB_E2E_OUT_DIR=%BUILD_DIR%\e2e_outputs
if "%TB_ENABLE_FISHEYE_REMAP_READER%"=="" set TB_ENABLE_FISHEYE_REMAP_READER=1
if "%TB_STRESS_FULL%"=="" set TB_STRESS_FULL=0
if "%TB_STRESS_RANDOM%"=="" set TB_STRESS_RANDOM=0
if "%TB_RANDOM_SEED%"=="" (
    set TB_RANDOM_SEED=1aceb00c
    set TB_RANDOM_SEED_DEFAULTED=1
) else (
    set TB_RANDOM_SEED_DEFAULTED=0
)

if "%TB_STRESS_FULL%"=="1" (
    set TB_LINES=2048
    set TB_BACKPRESSURE_ALL=1
    set TB_BACKPRESSURE_CYCLES=4096
    set TB_GLOBAL_TIMEOUT_CYCLES=70000000
)

if "%TB_STRESS_RANDOM%"=="1" (
    set TB_LINES=2048
    set TB_BACKPRESSURE_ALL=1
    set TB_RANDOM_READY=1
    set TB_BACKPRESSURE_CYCLES=4096
    set TB_GLOBAL_TIMEOUT_CYCLES=70000000
)

if not exist "%VIVADO_SETTINGS%" (
    echo ERROR: Vivado settings script not found: %VIVADO_SETTINGS%
    exit /b 1
)

call "%VIVADO_SETTINGS%"
if errorlevel 1 exit /b 1

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%TB_E2E_OUT_DIR%" mkdir "%TB_E2E_OUT_DIR%"
set "TB_E2E_OUT_DIR_PLUS=%TB_E2E_OUT_DIR:\=/%"
set "FISHEYE_DEFINE="
if "%TB_ENABLE_FISHEYE_REMAP_READER%"=="1" set "FISHEYE_DEFINE=-d ENABLE_FISHEYE_REMAP_READER"
cd /d "%BUILD_DIR%"

copy /Y "%REPO_ROOT%\hls\fisheye_remap\rtl\*.dat" "%BUILD_DIR%\" >nul

call xvlog -sv ^
    -log xvlog_tb_srio_video_e2e.log ^
    %FISHEYE_DEFINE% ^
    -i "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM" ^
    -i "%REPO_ROOT%\hls\fisheye_remap\rtl" ^
    "%REPO_ROOT%\80_TB\tb_srio_video_e2e.v" ^
    "%REPO_ROOT%\20_HDL\22_User\Common\sync_nrst.v" ^
    "%REPO_ROOT%\20_HDL\22_User\Common\async_fifo_v1000.v" ^
    "%REPO_ROOT%\20_HDL\22_User\axis\fifo_to_axis.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\sdp_drw_ram.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_v_axis_to_fifo.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_fix.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_v_fifo_to_bram_write.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_v_fifo_to_bram_wb.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_v_fifo_to_bram_top.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_v_axis_to_bram\srio_v_axis_to_bram_top.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\readbram_to_axis64\readbram_to_fifo.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\readbram_to_axis64\readbram_to_axis64_top.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\srio_insert_doorbell.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\vbram_lutaxi4_to_axis.v" ^
    "%REPO_ROOT%\20_HDL\22_User\SRIO_2_BRAM\SRIO_2_Video.v"
if errorlevel 1 exit /b 1

call xvlog -sv ^
    -log xvlog_glbl_tb_srio_video_e2e.log ^
    "%XILINX_VIVADO%\data\verilog\src\glbl.v"
if errorlevel 1 exit /b 1

call xelab -debug typical ^
    -log xelab_tb_srio_video_e2e.log ^
    -L unisims_ver ^
    -L unimacro_ver ^
    work.tb_srio_video_e2e work.glbl ^
    -s tb_srio_video_e2e_snap
if errorlevel 1 exit /b 1

if "%TB_STRESS_RANDOM%"=="1" (
    if "%TB_RANDOM_SEED_DEFAULTED%"=="1" (
        for %%S in (00001234 00005678 00009abc 0000def0 1aceb00c) do (
            call :run_one %%S xsim_tb_srio_video_e2e_seed_%%S.log
            if errorlevel 1 exit /b 1
        )
    ) else (
        call :run_one %TB_RANDOM_SEED% xsim_tb_srio_video_e2e.log
        if errorlevel 1 exit /b 1
    )
) else (
    call :run_one %TB_RANDOM_SEED% xsim_tb_srio_video_e2e.log
    if errorlevel 1 exit /b 1
)

endlocal
exit /b 0

:run_one
set "RUN_SEED=%~1"
set "RUN_LOG=%~2"
echo INFO: run tb_srio_video_e2e seed=%RUN_SEED% lines=%TB_LINES% backpressure_all=%TB_BACKPRESSURE_ALL% random_ready=%TB_RANDOM_READY%
call xsim tb_srio_video_e2e_snap ^
    -runall ^
    -testplusarg "TB_LINES=%TB_LINES%" ^
    -testplusarg "TB_BACKPRESSURE_CYCLES=%TB_BACKPRESSURE_CYCLES%" ^
    -testplusarg "TB_GLOBAL_TIMEOUT_CYCLES=%TB_GLOBAL_TIMEOUT_CYCLES%" ^
    -testplusarg "TB_PACKET_GAP_CYCLES=%TB_PACKET_GAP_CYCLES%" ^
    -testplusarg "TB_BACKPRESSURE_ALL=%TB_BACKPRESSURE_ALL%" ^
    -testplusarg "TB_RANDOM_READY=%TB_RANDOM_READY%" ^
    -testplusarg "TB_DRAIN_CYCLES=%TB_DRAIN_CYCLES%" ^
    -testplusarg "TB_STRICT_DRAIN=%TB_STRICT_DRAIN%" ^
    -testplusarg "TB_SAVE_E2E_FRAMES=%TB_SAVE_E2E_FRAMES%" ^
    -testplusarg "TB_E2E_OUT_DIR=%TB_E2E_OUT_DIR_PLUS%" ^
    -testplusarg "TB_RANDOM_SEED=%RUN_SEED%" ^
    -log "%RUN_LOG%"
if errorlevel 1 exit /b 1

findstr /C:"FAIL: tb_srio_video_e2e" "%RUN_LOG%" >nul
if not errorlevel 1 exit /b 1

findstr /C:"PASS: tb_srio_video_e2e" "%RUN_LOG%" >nul
if errorlevel 1 exit /b 1

exit /b 0
