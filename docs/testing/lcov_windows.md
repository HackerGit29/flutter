# LCOV Installation Guide for Windows (Non-WSL)

Since administrative access is restricted in this environment, follow these steps on your local machine to enable test coverage visualization.

## Option 1: Using Chocolatey (Recommended)
1. Open PowerShell as Administrator.
2. Install Chocolatey if not present: `Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol.Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))`
3. Install lcov:
   ```powershell
   choco install lcov
   ```

## Option 2: Using Scoop
1. Open PowerShell.
2. Install Scoop: `Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')`
3. Install lcov:
   ```powershell
   scoop install lcov
   ```

## Option 3: Manual Installation (Git Bash / MinGW)
LCOV is typically bundled with the `lcov` package in MinGW/MSYS2. If you use Git Bash, you may need to install the MSYS2 environment and run `pacman -S lcov`.

## Verification
After installation, restart your terminal and run:
```bash
lcov --version
```
If this works, you can follow the process in `docs/testing/coverage.md`.
