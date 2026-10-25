# Kept for muscle memory: .\dev.ps1 dev | dev-dood | dind
# Everything else lives in bin/devbox (see devbox.ps1).
param(
    [ValidateSet("dev", "dev-dood", "dind")]
    [string]$Command = "dev"
)

switch ($Command) {
    "dev"      { & "$PSScriptRoot\devbox.ps1" shell }
    "dev-dood" { & "$PSScriptRoot\devbox.ps1" shell --dood }
    "dind"     { & "$PSScriptRoot\devbox.ps1" dind }
}
exit $LASTEXITCODE
