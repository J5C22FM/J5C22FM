@echo off
chcp 936 >nul
title PUBG 优化还原工具
setlocal enabledelayedexpansion

:: 管理员提权
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 正在请求管理员权限...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo            PUBG 优化还原工具
echo ============================================================
echo.

:: 备份文件路径（带来源校验，防止路径为空或异常）
set "BACKUP_DIR=%~dp0"
if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\Desktop\"
set "BACKUP_FILE=!BACKUP_DIR!PUBG_Backup.ini"
if not defined BACKUP_FILE (
    echo [错误] 备份路径无效。
    pause
    exit /b
)
if not exist "%BACKUP_FILE%" (
    echo [错误] 未找到备份文件 PUBG_Backup.ini
    echo        请将本脚本与 PUBG_Backup.ini 放在同一目录后再运行。
    pause
    exit /b
)

echo [读取] 正在读取备份的原始设置...
for /f "usebackq delims=" %%a in ("%BACKUP_FILE%") do set "%%a"

echo.
echo [1/7] 恢复电源计划 ...
if defined OLD_PLAN (
    powercfg /setactive !OLD_PLAN!
    echo        已恢复原电源计划: !OLD_PLAN!
) else (
    echo        [跳过] 备份中没有电源计划记录。
)

echo [2/7] 恢复虚拟内存 ...
if defined OLD_PF (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "!OLD_PF!" /f >nul
    echo        已恢复原虚拟内存设置（重启后生效）。
)
if /i "!OLD_AUTO!"=="True" (
    powershell -NoProfile -Command "$cs=Get-CimInstance Win32_ComputerSystem; Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile=$true}" >nul 2>&1
    echo        已恢复系统自动托管虚拟内存。
)

echo [3/7] 恢复 PUBG 全屏优化设置 ...
set "STEAM_DIR="
for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Valve\Steam" /v SteamPath 2^>nul ^| find "REG_SZ"') do set "STEAM_DIR=%%b"
if not defined STEAM_DIR (
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul ^| find "REG_SZ"') do set "STEAM_DIR=%%b"
)
if defined STEAM_DIR (
    set "PUBG_EXE=!STEAM_DIR!\steamapps\common\PUBG\TslGame\Binaries\Win64\TslGame.exe"
    if exist "!PUBG_EXE!" (
        reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "!PUBG_EXE!" /f >nul 2>&1
        echo        已还原 PUBG 全屏优化设置。
    )
)

echo [4/7] 恢复 Xbox Game Bar / Game DVR ...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul
echo        已恢复 Xbox Game Bar 相关设置。

echo [5/7] 恢复网络参数 ...
for /f "delims=" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"') do (
    echo %%i | findstr /r "^HKEY" >nul && (
        reg delete "%%i" /v TcpAckFrequency /f >nul 2>&1
        reg delete "%%i" /v TCPNoDelay /f >nul 2>&1
    )
)
echo        已移除网络延迟优化参数（Nagle 恢复默认）。

echo [6/7] 恢复 Windows 更新策略 ...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /f >nul 2>&1
echo        已移除防自动重启策略。

echo [7/7] 清理备份文件 ...
if defined BACKUP_FILE (
    if exist "!BACKUP_FILE!" del /f /q "!BACKUP_FILE!" >nul 2>&1
    echo        备份文件已删除。
)

echo.
echo ============================================================
echo  还原完成！建议重启电脑使所有设置完全生效。
echo ============================================================
pause
exit /b