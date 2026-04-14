REM New code: keep the tool path configurable and invoke the TCL script relative to this BAT file.
@echo off
@set "SCRIPT_DIR=%~dp0"
@if not defined PROCISE_DIR set "PROCISE_DIR=C:/FudanMicro/Procise"
@set "TCL_LIBRARY=%PROCISE_DIR%/tcl8.4"
@set "PATH=%PROCISE_DIR%/dll;%PROCISE_DIR%/bin;%PATH%"
@set "ICTIME_HOME=%PROCISE_DIR%"
@set "APP_DIR=%PROCISE_DIR%"
@set "FMSH_DB=%PROCISE_DIR%/db"
@procise.exe "%SCRIPT_DIR%procise_run_disable_icap.tcl"
REM Old code preserved below:
REM @set PROCISE_DIR=C:/FudanMicro/Procise
REM @set TCL_LIBRARY=%PROCISE_DIR%/tcl8.4
REM @set PATH=%PROCISE_DIR%/dll;%PROCISE_DIR%/bin;%PATH%
REM @set ICTIME_HOME=%PROCISE_DIR%
REM @set APP_DIR=%PROCISE_DIR%
REM @set FMSH_DB=%PROCISE_DIR%/db
REM @procise.exe D:/Staff/test/EB4110_FPGA_20260410_2/10_PRJ/procise_run_disable_icap.tcl
