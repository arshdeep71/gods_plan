@echo off
echo ====================================================
echo AltStore / AltServer 2FA & Connection Repair Script
echo ====================================================
echo.
echo [1/4] Stopping AltServer...
taskkill /f /im AltServer.exe >nul 2>&1

echo [2/4] Stopping Apple Mobile Device Service...
net stop "Apple Mobile Device Service" >nul 2>&1
net stop "Bonjour Service" >nul 2>&1

echo [3/4] Clearing Apple ADI / Anisette Cache...
rmdir /s /q "C:\ProgramData\Apple Computer\iTunes\adi" >nul 2>&1

echo [4/4] Restarting Apple Services...
net start "Apple Mobile Device Service" >nul 2>&1
net start "Bonjour Service" >nul 2>&1

echo.
echo ====================================================
echo SUCCESS: Apple Services reset and Cache cleared!
echo ====================================================
echo.
echo NEXT STEPS:
echo 1. Start AltServer again (Right-click -> Run as Administrator).
echo 2. Make sure your iPhone is connected via USB and iTunes is open.
echo 3. Try to log in inside the AltStore app on your iPhone.
echo.
pause
