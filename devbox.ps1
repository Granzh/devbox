# PowerShell wrapper for bin/devbox: runs the bash script via WSL (if its default distro
# can reach docker) or Git Bash. All logic lives in bin/devbox.
$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot 'bin/devbox'
$userHome = $env:USERPROFILE

$distroOk = $false
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $null = & wsl.exe -e bash -c 'docker info' 2>$null
    $distroOk = ($LASTEXITCODE -eq 0)
}

if ($distroOk) {
    # the script runs inside WSL, so hand it Windows paths in /mnt/<drive>/ form
    $wslScript = (& wsl.exe wslpath -a ($script -replace '\\', '/')).Trim()
    $wslHome = (& wsl.exe wslpath -a ($userHome -replace '\\', '/')).Trim()
    $env:DEVBOX_HOST_HOME = $wslHome
    $env:WSLENV = (@($env:WSLENV, 'DEVBOX_HOST_HOME', 'DEVBOX_TAG') | Where-Object { $_ }) -join ':'
    & wsl.exe bash $wslScript @args
    exit $LASTEXITCODE
}

# System32\bash.exe is the WSL launcher, so look for Git Bash explicitly
$bash = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) { throw 'Neither a docker-capable WSL distro nor Git Bash was found.' }
$env:DEVBOX_HOST_HOME = $userHome -replace '\\', '/'
& $bash ($script -replace '\\', '/') @args
exit $LASTEXITCODE
