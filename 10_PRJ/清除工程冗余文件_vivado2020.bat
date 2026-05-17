::清除文件
@echo on
echo 警告！！！！！
echo 是否确认清除？！！！
pause
for /r %%f in (*.mif) do del %%f
for /r %%f in (*.log) do del %%f
for /r %%f in (*.jou) do del %%f
for /r %%f in (vivado_pid*) do del %%f

for /r %%f in (00_PRJ.runs\impl_1\*.dcp) do del %%f
for /r %%f in (00_PRJ.runs\impl_1\*.rpt) do del %%f
for /r %%f in (00_PRJ.runs\impl_1\*.rpx) do del %%f
::删除文件夹
@REM
rd /s /q 00_PRJ.cache
rd /s /q 00_PRJ.hw
::rd /s /q 00_PRJ.ip_user_files
rd /s /q 00_PRJ.sim
rd /s /q .xil

::rd /s /q 00_PRJ.runs\synth_1


::cd 00_PRJ.runs\impl_1
::set Ext=bin,bit,ltx
::删除文件
::for /f "delims=" %%a in ('dir /a-d/s/b') do (
::	if /i not "%%~a"=="%~f0" (
::		set "Skip="
::		for %%i in (%Ext%) do (
::			if /i ".%%~i"=="%%~xa" (
::				set Skip=OK
::			)
::		)
::		if not defined Skip (
::			echo "正在删除文件%%~a"
::			del /f /q "%%~a"
::		)
::	)
::)
::::删除所有文件夹
::for /f "delims=" %%i in ('dir /ad /s /b') do (
::	if exist "%%i" (
::		echo "正在删除文件夹%%i"
::		rd /s /q "%%i" >nul
::	)
::)
