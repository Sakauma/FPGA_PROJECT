::清除文件
@echo on
echo 如果当前工程名为00_PRJ，将会缩减不必要文件，保证存储最小化。
echo 执行完打开工程时需要重新综合IP！！！
echo 执行完打开工程时imp时会卡死一次，再次imp可以成功！！！
pause
set folderPath=00_PRJ.srcs
IF NOT EXIST %folderPath% (
echo 文件目录下不存在工程名为00_PRJ的工程！！！
pause
exit /b 1
)

for /r %%f in (*.mif) do del %%f
for /r %%f in (*.log) do del %%f
for /r %%f in (*.jou) do del %%f
for /r %%f in (vivado_pid*) do del %%f

for /r %%f in (00_PRJ.runs\impl_1\*.dcp) do del %%f
for /r %%f in (00_PRJ.runs\impl_1\*.rpt) do del %%f
for /r %%f in (00_PRJ.runs\impl_1\*.rpx) do del %%f
::删除文件夹
@REM
rd /s /q .xil
rd /s /q 00_PRJ.cache
rd /s /q 00_PRJ.gen
rd /s /q 00_PRJ.hw
rd /s /q 00_PRJ.ip_user_files
rd /s /q 00_PRJ.sim
rd /s /q 00_PRJ.tmp



cd 00_PRJ.runs

set "excludeFolder=impl_1"

echo "准备删除文件夹%%~a"

for /f "delims=" %%F in ('dir /ad /b /s ^| findstr /v /i 
"%excludeFolder%"') do (
 echo Deleting file: %%F
rd /s /q "%%F"
)
echo "准备删除文件%%~a"
for /f "delims=" %%F in ('dir /b /a-d /s ^| findstr /v /i 
"%excludeFolder%"') do (
 echo Deleting file: %%F
	del /f /q "%%F"
)


cd impl_1
set Ext=bin,bit,ltx
::删除文件
for /f "delims=" %%a in ('dir /a-d/s/b') do (
	if /i not "%%~a"=="%~f0" (
		set "Skip="
		for %%i in (%Ext%) do (
			if /i ".%%~i"=="%%~xa" (
				set Skip=OK
			)
		)
		if not defined Skip (
			echo "正在删除文件%%~a"
			del /f /q "%%~a"
		)
	)
)

::删除所有文件夹
for /f "delims=" %%i in ('dir /ad /s /b') do (
	if exist "%%i" (
		echo "正在删除文件夹%%i"
		rd /s /q "%%i" >nul
	)
)

