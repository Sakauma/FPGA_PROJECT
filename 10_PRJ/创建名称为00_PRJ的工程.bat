::那需要准备bd.tcl的文件，如果bd模块较多较复杂，可以通vivado倒推
path %psth%;D:\Xilinx\Vivado\2020.2\bin
::start "C:\Windows\System32\cmd.exe" 
@echo Power By Kingstacker.
@echo Produce the vivado project.
set cache_floder=00_PRJ.cache
cd  %~dp0
if exist %~dp0%cache_floder% ( 
    echo The floder is exist.
    pause
) else (
    vivado -source bf0080_setup.tcl
)
exit
