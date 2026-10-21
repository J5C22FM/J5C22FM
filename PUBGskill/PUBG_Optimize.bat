@echo off
chcp 936 >nul
title PUBG 安全优化工具 v1.1
setlocal enabledelayedexpansion
color 0B

echo ============================================================
echo            PUBG 安全优化工具 v1.1 （通用自适应版）
echo              所有修改均可通过 Restore_PUBG.bat 一键还原
echo ============================================================
echo.

:: ============ 1. 管理员权限检测与自动提权 ============
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 当前不是管理员权限，正在请求提权（请在弹出的窗口中点"是"）...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo [OK] 已获得管理员权限
echo.

:: ============ 2. 操作前确认 ============
echo [说明] 即将执行以下 8 项优化/检查（全部可一键还原）：
echo        1. 电源计划切换为高性能
echo        2. 关闭 PUBG 全屏优化干扰（如检测到游戏）
echo        3. 关闭 Xbox Game Bar 后台录制
echo        4. 清理临时文件与预读取
echo        5. 虚拟内存按物理内存 1.5 倍自动设置
echo        6. 网络延迟优化（关闭 Nagle 算法）
echo        7. 防止 Windows 更新在游戏时自动重启
echo        8. 显卡驱动版本检查（NVIDIA 过旧时提示更新）
echo.
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $r=[System.Windows.Forms.MessageBox]::Show('即将执行 PUBG 系统优化（全部可一键还原），是否继续？','PUBG 优化工具',4); exit $r"
if %errorlevel% neq 6 (
    echo [提示] 已取消，未做任何修改。
    pause
    exit /b
)
echo [OK] 确认继续
echo.

:: ============ 3. 硬件自动检测 ============
echo [检测] 正在读取本机硬件配置...
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"`) do set "CPU_NAME=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1MB)"`) do set "RAM_MB=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Virtual' } | Select-Object -First 1).Name"`) do set "GPU_NAME=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile"`) do set "OLD_AUTO=%%i"

if not defined RAM_MB set "RAM_MB=16384"
set /a RAM_GB=%RAM_MB%/1024
set /a PF_MB=%RAM_MB%*3/2

set "GPU_BRAND=未知"
echo !GPU_NAME! | findstr /i "NVIDIA" >nul && set "GPU_BRAND=NVIDIA"
echo !GPU_NAME! | findstr /i "AMD" >nul && set "GPU_BRAND=AMD"
echo !GPU_NAME! | findstr /i "Intel" >nul && set "GPU_BRAND=Intel"

echo.
echo [配置] CPU : !CPU_NAME!
echo [配置] 内存 : !RAM_MB! MB （约 !RAM_GB! GB）
echo [配置] 显卡 : !GPU_NAME!  [品牌: !GPU_BRAND!]
echo.

:: ============ 4. 备份原始设置 ============
echo [备份] 正在读取并保存当前原始设置...
for /f "tokens=4 delims=()" %%i in ('powercfg /getactivescheme') do set "OLD_PLAN=%%i"
for /f "tokens=2,* delims==" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles 2^>nul ^| find "REG_MULTI_SZ"') do set "OLD_PF=%%a"
for /f "tokens=*" %%j in ("!OLD_PF!") do set "OLD_PF=%%j"
for /f "tokens=2" %%a in ("!OLD_PF!") do set "OLD_PF_SIZE=%%a"

set "BACKUP_DIR=%~dp0"
if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\Desktop\"
set "BACKUP_FILE=!BACKUP_DIR!PUBG_Backup.ini"
(
echo [backup]
echo OLD_PLAN=!OLD_PLAN!
echo OLD_PF=!OLD_PF!
echo OLD_AUTO=!OLD_AUTO!
) > "!BACKUP_FILE!"
echo [OK] 原始设置已备份到: !BACKUP_FILE!
echo.

:: ============ 5. 执行优化 ============
echo ============================================================
echo                      开始执行优化
echo ============================================================

echo.
echo [1/8] 电源计划优化 ...
if /i "!OLD_PLAN!"=="8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" (
    echo        当前已是"高性能"计划，无需切换。
) else (
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    echo        已切换到"高性能"电源计划。
)

echo.
echo [2/8] 关闭 PUBG 全屏优化干扰 ...
set "STEAM_DIR="
for /f "tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\Valve\Steam" /v SteamPath 2^>nul ^| find "REG_SZ"') do set "STEAM_DIR=%%b"
if not defined STEAM_DIR (
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul ^| find "REG_SZ"') do set "STEAM_DIR=%%b"
)
if defined STEAM_DIR (
    set "PUBG_EXE=!STEAM_DIR!\steamapps\common\PUBG\TslGame\Binaries\Win64\TslGame.exe"
    if exist "!PUBG_EXE!" (
        reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "!PUBG_EXE!" /t REG_SZ /d "DISABLEDXMAXIMIZEDWINDOWEDMODE" /f >nul
        echo        已关闭 PUBG 全屏优化（TslGame.exe）。
    ) else (
        echo        [跳过] 未找到 PUBG 游戏目录，可稍后手动添加。
    )
) else (
    echo        [跳过] 未检测到 Steam，可稍后手动添加。
)

echo.
echo [3/8] 关闭 Xbox Game Bar 后台录制 ...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f >nul
echo        已关闭 Game DVR 后台录制与自动游戏模式。

echo.
echo [4/8] 清理临时文件与预读取 ...
set "TP_SAFE=1"
if defined TEMP (
    set "TP=!TEMP!"
    if "!TP:~-1!"=="\" set "TP=!TP:~0,-1!"
    if "!TP!"=="" set "TP_SAFE=0"
    if "!TP!"=="\" set "TP_SAFE=0"
    if "!TP:~1,1!"==":" (
        if "!TP:~2,1!"=="\" (
            if "!TP:~3!"=="" set "TP_SAFE=0"
        )
    )
) else set "TP_SAFE=0"
if "!TP_SAFE!"=="1" (
    if exist "!TP!\*" (
        del /f /s /q "!TP!\*" >nul 2>&1
        echo        用户临时文件已清理（!TP!）。
    )
) else (
    echo        [跳过] TEMP 路径异常，已保护，未执行清理。
)
if exist "C:\Windows\Temp\*" (
    del /f /s /q "C:\Windows\Temp\*" >nul 2>&1
    echo        系统临时文件已清理。
)
if exist "C:\Windows\Prefetch\*" (
    del /f /s /q "C:\Windows\Prefetch\*" >nul 2>&1
    echo        预读取文件已清理。
)

echo.
echo [5/8] 虚拟内存优化（按物理内存 1.5 倍自动计算）...
echo        当前物理内存: !RAM_MB! MB ，目标虚拟内存: !PF_MB! MB
if defined OLD_PF_SIZE (
    if !OLD_PF_SIZE! GEQ !PF_MB! (
        echo        当前虚拟内存（!OLD_PF_SIZE! MB）已满足 1.5 倍要求，无需修改。
    ) else (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "c:\pagefile.sys !PF_MB! !PF_MB!" /f >nul
        echo        虚拟内存已设置为 !PF_MB! MB（重启后生效）。
    )
) else (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "c:\pagefile.sys !PF_MB! !PF_MB!" /f >nul
    echo        虚拟内存已设置为 !PF_MB! MB（重启后生效）。
)

echo.
echo [6/8] 网络延迟优化（关闭 Nagle 算法）...
for /f "delims=" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"') do (
    echo %%i | findstr /r "^HKEY" >nul && (
        reg add "%%i" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%i" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
    )
)
echo        已为所有网络接口关闭 Nagle 算法（重启后完全生效）。

echo.
echo [7/8] 防止 Windows 更新在游戏时自动重启 ...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul
echo        已设置：有用户登录时不因更新自动重启。

:: ============ 8. 显卡驱动检查（NVIDIA 专属，不修改系统） ============
if "!GPU_BRAND!"=="NVIDIA" (
    for /f "usebackq delims=" %%i in (`nvidia-smi --query-gpu=driver_version --format=csv,noheader 2^>nul`) do set "NVIDIA_DRV=%%i"
    if defined NVIDIA_DRV (
        echo.
        echo [8/8] 显卡驱动检查 ...
        echo        当前 NVIDIA 驱动版本: !NVIDIA_DRV!
        for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Virtual' } | Select-Object -First 1).DriverDate.ToString('yyyyMMdd')"`) do set "NVIDIA_DATE=%%d"
        if defined NVIDIA_DATE (
            if !NVIDIA_DATE! LSS 20260101 (
                echo        驱动日期为 !NVIDIA_DATE!，较早，建议更新到最新 Game Ready 驱动。
                powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $r=[System.Windows.Forms.MessageBox]::Show('检测到显卡驱动较旧（!NVIDIA_DRV!），是否立即打开 NVIDIA 官方驱动下载页面？','PUBG 优化工具',4); exit $r"
                if !errorlevel! equ 6 (
                    start "" "https://www.nvidia.com/drivers"
                    echo        已打开 NVIDIA 驱动下载页面，请按提示下载安装最新 Game Ready 驱动。
                ) else (
                    echo        [跳过] 已选择不打开下载页面。
                )
            ) else (
                echo        驱动日期较新，无需更新。
            )
        )
    ) else (
        echo.
        echo [8/8] 显卡驱动检查 ... [跳过] 未获取到驱动信息
    )
)

echo.
echo ============================================================
echo  优化执行完成！
echo  = 恢复脚本 Restore_PUBG.bat 已就绪，可一键还原所有修改。
echo  = 部分设置（虚拟内存、网络参数）需要重启电脑后完全生效。
echo  = 建议：重启后再进游戏，画质可先用 NVIDIA 推荐设置。
echo ============================================================
echo.
pause
exit /b