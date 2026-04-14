@echo off
@set "SCRIPT_DIR=%~dp0"
@if not defined PROCISE_DIR set "PROCISE_DIR=C:/FudanMicro/Procise"
@set "TCL_LIBRARY=%PROCISE_DIR%/tcl8.4"
@set "PATH=%PROCISE_DIR%/dll;%PROCISE_DIR%/bin;%PATH%"
@set "ICTIME_HOME=%PROCISE_DIR%"
@set "APP_DIR=%PROCISE_DIR%"
@set "FMSH_DB=%PROCISE_DIR%/db"
@procise.exe "%SCRIPT_DIR%procise_run_disable_icap.tcl"
