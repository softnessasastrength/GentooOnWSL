@echo off
:: ==========================================================
:: Gentoo on WSL2 — Resilient Install & Bootstrap (OpenRC)
:: Local stage3:
::   C:\Users\Branden\Downloads\stage3-amd64-openrc-20250907T165007Z.tar.xz
:: Install path:
::   E:\Distros\Gentoo
:: Linux user to create:
::   branden
:: Notes:
::   - Sets default user ONLY AFTER creation succeeds.
::   - Sudo install is best-effort (won't block user creation).
::   - Provides rescue hints at the end.
:: ==========================================================

setlocal ENABLEDELAYEDEXPANSION

set DISTRO=Gentoo
set BASE=E:\Distros\Gentoo
set ROOTFS=C:\Users\Branden\Downloads\stage3-amd64-openrc-20250907T165007Z.tar.xz
set USERNAME=branden

echo:
echo [*] Checking prereqs...
where wsl >nul 2>&1 || (echo [!] WSL not found. Enable "Windows Subsystem for Linux" and "Virtual Machine Platform", then reboot. & pause & exit /b 1)
if not exist "%ROOTFS%" (echo [!] Missing tarball: "%ROOTFS%". Fix path and retry. & pause & exit /b 1)

echo:
echo [*] Creating base path: "%BASE%"
mkdir "%BASE%" 2>nul

:: If the distro is already present, you can comment the next two lines to keep it.
echo:
echo [*] Unregistering any existing "%DISTRO%" (safe to ignore errors)...
wsl --unregister %DISTRO% 2>nul

echo:
echo [*] Importing Gentoo into WSL2...
wsl --import %DISTRO% "%BASE%" "%ROOTFS%" --version 2
if errorlevel 1 (echo [!] Import failed. Aborting. & pause & exit /b 1)

:: ------------------ BASE CONFIG (no default user yet) ------------------
echo:
echo [*] Writing base /etc/wsl.conf (default = root for now) and DNS...
wsl -d %DISTRO% -- bash -lc "set -e
mkdir -p /etc
cat > /etc/wsl.conf <<'EOF'
[user]
default=root

[network]
generateResolvConf = false
hostname = %DISTRO%

[boot]
systemd = false
EOF

rm -f /etc/resolv.conf || true
cat > /etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
EOF
"

if errorlevel 1 (
  echo [!] Failed to write wsl.conf/resolv.conf. You can rescue with:
  echo     wsl -d %DISTRO% -u root -- bash -l
  pause
  exit /b 1
)

:: ------------------ CREATE USER FIRST ------------------
echo:
echo [*] Creating Linux user '%USERNAME%' and adding to wheel...
wsl -d %DISTRO% -- bash -lc "set -e
id -u %USERNAME% >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash %USERNAME%
"

if errorlevel 1 (
  echo [!] User creation failed. Keeping default=root so you can rescue.
  echo     Launch rescue shell:
  echo         wsl -d %DISTRO% -u root -- bash -l
  echo     Then inside Gentoo:
  echo         useradd -m -G wheel -s /bin/bash %USERNAME%
  echo         passwd && passwd %USERNAME%
  echo         sed -i 's/^default=.*/default=%USERNAME%/' /etc/wsl.conf
  echo         exit  ^&  wsl --shutdown  ^&  wsl -d %DISTRO%
  pause
  exit /b 1
)

:: ------------------ NOW SAFE TO SET DEFAULT USER ------------------
echo:
echo [*] Setting default user to '%USERNAME%' in /etc/wsl.conf...
wsl -d %DISTRO% -- bash -lc "set -e
sed -i 's/^default=.*/default=%USERNAME%/' /etc/wsl.conf
"

:: ------------------ SUDO (BEST-EFFORT) ------------------
echo:
echo [*] Installing sudo and enabling wheel in sudoers (best-effort)...
wsl -d %DISTRO% -- bash -lc "
set -e
# Try to get a Portage snapshot quickly; don't fail the run if mirrors are slow
(emerge-webrsync || true)
(emerge --sync || true)
# Install sudo without interactivity if possible
(yes | emerge app-admin/sudo) || emerge --ask=n app-admin/sudo || true
# Enable wheel line if it's commented
if grep -q '^[#][[:space:]]*%wheel ALL=(ALL:ALL) ALL' /etc/sudoers; then
  sed -i 's/^[#][[:space:]]*%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi
"

:: ------------------ MOTD & PASSWORD REMINDER ------------------
wsl -d %DISTRO% -- bash -lc "printf '\n%s\n%s\n%s\n%s\n\n' \
'Gentoo WSL bootstrap: base config complete.' \
'Next steps (inside this first shell):' \
'  passwd && passwd %USERNAME%   # set root and your user password' \
'  (optional) sudo emerge -avuDN @world' \
> /etc/motd"

echo:
echo [*] Launching Gentoo now. Inside Gentoo, run:
echo       passwd
echo       passwd %USERNAME%
echo     Then 'exit'  ^> Windows:
echo       wsl --shutdown
echo       wsl -d %DISTRO%
echo:
pause
wsl -d %DISTRO%

echo:
echo [*] Applying default-user setting (restart WSL)...
wsl --shutdown

echo:
echo [*] Done. Re-enter Gentoo as '%USERNAME%' with:
echo       wsl -d %DISTRO%
echo     Verify:
echo       whoami
echo       cat /etc/os-release
echo:
echo [Rescue]
echo   If launch ever fails, force root shell:
echo     wsl -d %DISTRO% -u root -- bash -l
echo   To reset default user back to root:
echo     wsl -d %DISTRO% -u root -- sh -lc ""sed -i 's/^default=.*/default=root/' /etc/wsl.conf""
echo     wsl --shutdown
echo:
pause

endlocal
