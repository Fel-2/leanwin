@echo off
setlocal enabledelayedexpansion

:: Defaults — overridden by compose env (USERNAME/PASSWORD) when dockurr propagates them.
if not defined USERNAME set USERNAME=builder
if not defined PASSWORD set PASSWORD=build

echo [leanwin] Provisioning Windows Server 2022 Core (user=%USERNAME%)...

:: --- SSH Server ---
echo [leanwin] Installing OpenSSH Server...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" 2>nul
sc config sshd start=auto 2>nul
sc start sshd 2>nul
powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22" 2>nul
echo [leanwin] Setting PowerShell as default SSH shell and restarting...
reg add "HKLM\SOFTWARE\OpenSSH" /v DefaultShell /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" /f 2>nul
sc stop sshd 2>nul
sc start sshd 2>nul
echo [leanwin] SSH ready - PowerShell login on port 22

:: --- Hostname ---
echo [leanwin] Setting hostname...
powershell -Command "Rename-Computer -NewName 'LEANWIN' -Force" 2>nul

:: --- Dev Tools ---
echo [leanwin] Installing Git for Windows...
curl -sL -o C:\git-install.exe "https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe"
start "" /wait C:\git-install.exe /VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES /COMPONENTS="gitlfs,assoc,cmd,gitbash" /TASKS="modpath"
del C:\git-install.exe

echo [leanwin] Installing Chocolatey...
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" 2>nul

echo [leanwin] Installing tools via Chocolatey...
powershell -NoProfile -Command "choco install -y neovim ripgrep fd 7zip bottom fastfetch python nodejs-lts cmake make wixtoolset nuget.commandline strawberryperl 2>&1 | Out-Null" 2>nul

echo [leanwin] Installing Rust via rustup (MSVC toolchain)...
curl -sL -o C:\rustup-init.exe "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
start "" /wait C:\rustup-init.exe --default-host x86_64-pc-windows-msvc --default-toolchain stable --profile default -y 2>nul
del C:\rustup-init.exe

echo [leanwin] Installing MinGW-w64 (GNU linker for Rust on Server Core)...
powershell -NoProfile -Command "choco install mingw -y --no-progress 2>&1 | Out-Null" 2>nul
echo [leanwin] Configuring cargo for GNU toolchain + Machine PATH...
powershell -NoProfile -Command ^
  "$cargoBin = \"$env:USERPROFILE\\.cargo\\bin\"; " ^
  "$cargoCfg = \"$env:USERPROFILE\\.cargo\"; " ^
  "if (!(Test-Path $cargoCfg)) { New-Item -Path $cargoCfg -ItemType Directory -Force > $null }; " ^
  "@\"`n[target.x86_64-pc-windows-gnu]`nlinker = \"x86_64-w64-mingw32-gcc\"`nrustflags = [\"-C\", \"target-feature=+crt-static\"]`n\"@ | Set-Content \"$cargoCfg\\config.toml\"; " ^
  "$machinePath = [Environment]::GetEnvironmentVariable('Path','Machine'); " ^
  "if ($machinePath -notlike \"*$cargoBin*\") { " ^
  "  [Environment]::SetEnvironmentVariable('Path', \"$machinePath;$cargoBin\", 'Machine') " ^
  "}; " ^
  "Write-Host done" 2>nul

echo [leanwin] Installing nvm-windows (Node Version Manager)...
curl -sL -o C:\nvm.zip "https://github.com/coreybutler/nvm-windows/releases/download/1.2.2/nvm-noinstall.zip"
powershell -NoProfile -Command "Expand-Archive -Path C:\nvm.zip -DestinationPath C:\nvm -Force" 2>nul
del C:\nvm.zip
powershell -NoProfile -Command ^
  "$mp = [Environment]::GetEnvironmentVariable('Path','Machine'); " ^
  "if ($mp -notlike '*C:\\nvm*') { [Environment]::SetEnvironmentVariable('Path',\"$mp;C:\\nvm\",'Machine') }" 2>nul

echo [leanwin] Installing pyenv-win (Python Version Manager)...
powershell -NoProfile -Command "pip install pyenv-win --quiet 2>&1 | Out-Null" 2>nul
powershell -NoProfile -Command ^
  "$pypath = python -c 'import site; print(site.USER_SITE)' 2>&1; " ^
  "$mp = [Environment]::GetEnvironmentVariable('Path','Machine'); " ^
  "if ($mp -notlike '*pyenv-win*') { " ^
  "  [Environment]::SetEnvironmentVariable('Path',\"$mp;$pypath\\pyenv-win\\bin;$pypath\\pyenv-win\\shims\",'Machine') " ^
  "}" 2>nul

echo [leanwin] Adding WiX Toolset to Machine PATH...
powershell -NoProfile -Command ^
  "$mp = [Environment]::GetEnvironmentVariable('Path','Machine'); " ^
  "$wix = 'C:\\Program Files (x86)\\WiX Toolset v3.14\\bin'; " ^
  "if ($mp -notlike '*WiX*') { [Environment]::SetEnvironmentVariable('Path',\"$mp;$wix\",'Machine') }" 2>nul

echo [leanwin] Installing winget (portable, Server Core compatible)...
powershell -NoProfile -Command ^
  "Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null; " ^
  "Install-Script winget-install -Force -ErrorAction SilentlyContinue | Out-Null; " ^
  "winget-install -Force -ErrorAction SilentlyContinue" 2>nul

echo [leanwin] Setting up Neovim config...
if exist C:\oem\init.lua (
  mkdir "%USERPROFILE%\AppData\Local\nvim" 2>nul
  copy /Y C:\oem\init.lua "%USERPROFILE%\AppData\Local\nvim\init.lua" 2>nul
  echo [leanwin] nvim init.lua copied from OEM
) else (
  echo [leanwin] No init.lua in OEM, skipping
)

echo [leanwin] Setting up fastfetch config + ASCII logo...
if exist C:\oem\fastfetch.jsonc (
  mkdir "%APPDATA%\fastfetch" 2>nul
  copy /Y C:\oem\fastfetch.jsonc "%APPDATA%\fastfetch\config.jsonc" 2>nul
  if exist C:\oem\logo.txt copy /Y C:\oem\logo.txt "%APPDATA%\fastfetch\logo.txt" 2>nul
  echo [leanwin] fastfetch config + logo copied from OEM
) else (
  echo [leanwin] No fastfetch config in OEM, skipping
)

echo [leanwin] Installing Zellij terminal multiplexer...
powershell -NoProfile -Command ^
  "$url = 'https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-pc-windows-msvc.zip';" ^
  "$zip = \"$env:TEMP\\zellij.zip\";" ^
  "try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop; " ^
  "Expand-Archive -Path $zip -DestinationPath \"$env:ChocolateyInstall\\bin\" -Force -ErrorAction Stop; " ^
  "Write-Host 'zellij installed' } catch { Write-Host 'zellij download failed' }" 2>nul

echo [leanwin] Installing Oh My Posh...
powershell -NoProfile -Command ^
  "$binDir = [Environment]::GetEnvironmentVariable('ChocolateyInstall','Machine') + '\\bin';" ^
  "$ompExe = \"$binDir\\oh-my-posh.exe\";" ^
  "$themesDir = \"$binDir\\..\\lib\\oh-my-posh\\themes\";" ^
  "New-Item -ItemType Directory -Force -Path $themesDir | Out-Null;" ^
  "Write-Host 'Downloading oh-my-posh binary...';" ^
  "try { Invoke-WebRequest -Uri 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe' -OutFile $ompExe -UseBasicParsing -ErrorAction Stop } catch { };" ^
  "Write-Host 'Downloading themes...';" ^
  "try { Invoke-WebRequest -Uri 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip' -OutFile \"$env:TEMP\\themes.zip\" -UseBasicParsing -ErrorAction Stop; Expand-Archive -Path \"$env:TEMP\\themes.zip\" -DestinationPath $themesDir -Force } catch { };" ^
  "[Environment]::SetEnvironmentVariable('POSH_THEMES_PATH',$themesDir,'User');" ^
  "Write-Host 'oh-my-posh installed'" 2>nul

:: --- VS Build Tools (MSVC, .NET SDK, Windows SDK) ---
echo [leanwin] Downloading VS Build Tools...
curl -sL -o C:\vs_buildtools.exe "https://aka.ms/vs/stable/vs_buildtools.exe"

echo [leanwin] Installing VS Build Tools with C++ + .NET workloads (this takes a while)...
start "" /wait C:\vs_buildtools.exe ^
  --quiet --wait --norestart --nocache ^
  --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" ^
  --add Microsoft.VisualStudio.Workload.VCTools ^
  --add Microsoft.VisualStudio.Workload.MSBuildTools ^
  --add Microsoft.Net.Component.4.8.SDK ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.20348 ^
  || if "%ERRORLEVEL%"=="3010" echo [leanwin] VS Build Tools: reboot required (will happen later)

del C:\vs_buildtools.exe

echo [leanwin] Installing PSReadLine 2.2.6 (predictive suggestions)...
powershell -NoProfile -Command ^
  "Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null; " ^
  "Install-Module PSReadLine -RequiredVersion 2.2.6 -Force -SkipPublisherCheck -ErrorAction SilentlyContinue" 2>nul

:: --- PowerShell Profile & MOTD ---
echo [leanwin] Configuring PowerShell profile...
powershell -NoProfile -Command ^
  "$ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source;" ^
  "if (!($ompExe)) { $ompExe = [Environment]::GetEnvironmentVariable('ChocolateyInstall','Machine') + '\\bin\\oh-my-posh.exe' };" ^
  "$themesDir = [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH','User');" ^
  "if (!($themesDir)) { $themesDir = [Environment]::GetEnvironmentVariable('ChocolateyInstall','Machine') + '\\lib\\oh-my-posh\\themes' };" ^
  "$profileDir = Split-Path $PROFILE -Parent;" ^
  "if (!(Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force > $null };" ^
  "@(
    '',
    '# leanwin: MOTD',
    'try {',
    '  fastfetch',
    '  Write-Host ''  reboot/poweroff  → shutdown -r -t 0 / shutdown -s -t 0'' -ForegroundColor DarkGray',
    '  Write-Host ''  host.lan\Shared  → file exchange'' -ForegroundColor DarkGray',
    '} catch { Write-Host ''Welcome to LEANWIN'' -ForegroundColor Cyan }',
    '',
    '# leanwin: oh-my-posh prompt',
    'try { & ''' + $ompExe + ''' init pwsh --config ''' + $themesDir + '\montys.omp.json'' | Invoke-Expression } catch {}',
    '# leanwin: aliases',
    'function ll { Get-ChildItem -Force $args }',
    'function grep { Select-String $args }',
    'function rmrf { Remove-Item -Recurse -Force $args }',
    'function rmf { Remove-Item -Force $args }',
    'function rmdir { Remove-Item -Recurse $args }',
    'function touch { New-Item -ItemType File $args }',
    'function which { Get-Command $args }',
    'function reboot { shutdown -r -t 0 }',
    'function poweroff { shutdown -s -t 0 }',
    '',
    '# leanwin: PSReadLine auto-suggestions (like oh-my-zsh)',
    'try {',
    '  Remove-Module PSReadLine -ErrorAction SilentlyContinue',
    '  Import-Module PSReadLine -RequiredVersion 2.2.6',
    '  Set-PSReadLineOption -PredictionSource History',
    '  Set-PSReadLineOption -PredictionViewStyle InlineView',
    '  Set-PSReadLineOption -HistorySearchCursorMovesToEnd',
    '} catch {}',
    ''
  ) | Add-Content $PROFILE" 2>nul

:: --- Telemetry ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f

sc stop DiagTrack 2>nul
sc config DiagTrack start=disabled 2>nul
sc stop dmwappushservice 2>nul
sc config dmwappushservice start=disabled 2>nul
sc stop diagnosticshub.standardcollector.service 2>nul
sc config diagnosticshub.standardcollector.service start=disabled 2>nul

:: --- Windows Update ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /t REG_DWORD /d 3 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f

sc stop wuauserv 2>nul
sc config wuauserv start=disabled 2>nul
sc stop UsoSvc 2>nul
sc config UsoSvc start=disabled 2>nul

:: --- Remove scheduled tasks ---
schtasks /change /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\ProgramDataUpdater" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\StartupAppTask" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Update\Scheduled Start" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Update\Automatic App Update" /disable 2>nul
schtasks /change /tn "\Microsoft\Windows\Defrag\ScheduledDefrag" /disable 2>nul

:: --- Power ---
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>nul
powercfg /h off 2>nul

:: --- Disable Defender real-time (build box) ---
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" 2>nul
powershell -Command "Set-MpPreference -DisableIOAVProtection $true" 2>nul

:: --- Dev env vars ---
setx DEVENV "leanwin" /M 2>nul

:: --- Build Server (HTTP API for CI) ---
echo [leanwin] Setting up build server (port 8080)...
powershell -NoProfile -Command ^
  "$node = (Get-Command node).Source; " ^
  "$action = New-ScheduledTaskAction -Execute $node -Argument 'C:\\oem\\build-server.js' -WorkingDirectory 'C:\\builds'; " ^
  "$trigger = New-ScheduledTaskTrigger -AtStartup; " ^
  "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable; " ^
  "Register-ScheduledTask -TaskName LeanwinBuildServer -Action $action -Trigger $trigger -Settings $settings -User 'LEANWIN\\%USERNAME%' -Password '%PASSWORD%' -RunLevel Highest -Force | Out-Null; " ^
  "Start-ScheduledTask -TaskName LeanwinBuildServer; " ^
  "New-NetFirewallRule -Name build-server -DisplayName 'LEANWIN Build Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 8080 -ErrorAction SilentlyContinue | Out-Null; " ^
  "Write-Host 'build server started'" 2>nul

:: --- Disk Cleanup ---
echo [leanwin] Removing rustup docs, clippy, rustfmt (~200MB)...
powershell -NoProfile -Command "rustup component remove rust-docs-x86_64-pc-windows-msvc clippy-x86_64-pc-windows-msvc rustfmt-x86_64-pc-windows-msvc 2>&1 | Out-Null" 2>nul
echo [leanwin] Cleaning cargo registry index/cache...
if exist "%USERPROFILE%\.cargo\registry\index" rmdir /s /q "%USERPROFILE%\.cargo\registry\index" 2>nul
if exist "%USERPROFILE%\.cargo\registry\cache" rmdir /s /q "%USERPROFILE%\.cargo\registry\cache" 2>nul
echo [leanwin] Cleaning chocolatey cache...
if exist "C:\ProgramData\chocolatey\cache" rmdir /s /q "C:\ProgramData\chocolatey\cache" 2>nul
echo [leanwin] Running DISM WinSxS cleanup...
dism /online /Cleanup-Image /StartComponentCleanup /Quiet 2>nul
powershell -NoProfile -Command "Get-ChildItem -Path $env:TEMP,'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue" 2>nul

echo [leanwin] ========================================
echo [leanwin]  LEANWIN is ready.
echo [leanwin]
echo [leanwin]  SSH:   ssh -p 2223 builder@localhost
echo [leanwin]  Build: curl http://localhost:2224/exec  (HTTP API)
echo [leanwin]  RDP:   localhost:3389
echo [leanwin]  Web:   http://localhost:8006
echo [leanwin]
echo [leanwin]  Tools: git, choco, winget, neovim, rg, fd, 7zip, btm, fastfetch
echo [leanwin]  TMUX: zellij  (terminal multiplexer)
echo [leanwin]  VS:    MSVC, .NET 4.8 SDK, Windows SDK
echo [leanwin]  Shell: PowerShell + oh-my-posh
echo [leanwin] ========================================
