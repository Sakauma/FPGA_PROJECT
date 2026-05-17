::É¾³ýÎÄ¼þ
@echo on
echo ¾¯¸æ£¡£¡£¡£¡£¡
echo ÊÇ·ñÈ·ÈÏÉ¾³ý£¿£¡£¡£¡
pause
for /r %%f in (*.log) do del %%f
for /r %%f in (*.jou) do del %%f
for /r %%f in (*.xpr) do del %%f
for /r %%f in (vivado_pid*) do del %%f
::É¾³ýÎÄ¼þ¼Ð
@REM
rd /s /q 00_PRJ.cache
rd /s /q 00_PRJ.gen
rd /s /q 00_PRJ.hw
rd /s /q 00_PRJ.ip_user_files
rd /s /q 00_PRJ.sim
rd /s /q 00_PRJ.srcs
rd /s /q 00_PRJ.runs
rd /s /q .xil
::pause