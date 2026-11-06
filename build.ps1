<#
.SYNOPSIS
    Builds the Ultimate Realism Framework and optionally deploys it to a GTA V install.

.DESCRIPTION
    Requires the .NET SDK (6.0 or newer) or Visual Studio 2019/2022.
    The project targets .NET Framework 4.8 / x64, which is what
    ScriptHookVDotNet3 loads.

    The ScriptHookVDotNet3.dll reference defaults to .\refs\ScriptHookVDotNet3.dll.
    To build against the DLL from your own game install (recommended, since it matches
    your game build), pass -ShvdnPath.

.EXAMPLE
    .\build.ps1

.EXAMPLE
    .\build.ps1 -GamePath "D:\Games\GTAV" -ShvdnPath "D:\Games\GTAV\ScriptHookVDotNet3.dll"

.EXAMPLE
    .\build.ps1 -Configuration Debug -RunConfigValidator
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [string]$ShvdnPath,

    [string]$GamePath,

    [switch]$RunConfigValidator,

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "Ultimate Realism Framework - build" -ForegroundColor Cyan
Write-Host "  root          : $root"
Write-Host "  configuration : $Configuration"
Write-Host ""

# --- 1. config <-> code consistency gate ---------------------------------------
if ($RunConfigValidator) {
    Write-Host "[1/4] Validating configuration against code..." -ForegroundColor Yellow
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }

    if ($python) {
        & $python.Source (Join-Path $root 'tools/validate_config.py')
        if ($LASTEXITCODE -ne 0) {
            throw "Configuration validator failed. Fix the reported keys before shipping."
        }
    }
    else {
        Write-Warning "Python not found; skipping the configuration validator."
    }
}
else {
    Write-Host "[1/4] Configuration validator skipped (use -RunConfigValidator)." -ForegroundColor DarkGray
}

# --- 2. build ----------------------------------------------------------------
Write-Host "[2/4] Building..." -ForegroundColor Yellow
$project = Join-Path $root 'src/UltimateRealism/UltimateRealism.csproj'

$dotnetArgs = @('build', $project, '-c', $Configuration, '--nologo')
if ($ShvdnPath) {
    $dotnetArgs += "-p:ShvdnPath=$ShvdnPath"
}
if ($Clean) {
    $dotnetArgs += '--no-incremental'
}

& dotnet @dotnetArgs
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

$output = Join-Path $root "src/UltimateRealism/bin/$Configuration"
$assembly = Join-Path $output 'UltimateRealism.dll'
if (-not (Test-Path $assembly)) { throw "Build reported success but $assembly is missing." }

$size = [math]::Round((Get-Item $assembly).Length / 1KB, 1)
Write-Host "      -> $assembly ($size KB)" -ForegroundColor Green

# --- 3. sanity report --------------------------------------------------------
Write-Host "[3/4] Build artefacts:" -ForegroundColor Yellow
Get-ChildItem $output -File | ForEach-Object {
    Write-Host ("      {0,-32} {1,8:N1} KB" -f $_.Name, ($_.Length / 1KB))
}

# --- 4. deploy ---------------------------------------------------------------
if ($GamePath) {
    Write-Host "[4/4] Deploying to $GamePath ..." -ForegroundColor Yellow

    $scriptsDir = Join-Path $GamePath 'scripts'
    if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir | Out-Null }

    Copy-Item $assembly (Join-Path $scriptsDir 'UltimateRealism.dll') -Force

    $iniTarget = Join-Path $scriptsDir 'UltimateRealism.ini'
    if (-not (Test-Path $iniTarget)) {
        Copy-Item (Join-Path $root 'UltimateRealism.ini') $iniTarget -Force
        Write-Host "      fresh install: default UltimateRealism.ini deployed." -ForegroundColor Green
    }
    else {
        Write-Host "      existing UltimateRealism.ini preserved (your settings are safe)." -ForegroundColor Green
    }

    Write-Host "      deployed. Launch the game; the log appears in $scriptsDir." -ForegroundColor Green

    if (-not (Test-Path (Join-Path $GamePath 'ScriptHookV.dll'))) {
        Write-Warning "ScriptHookV.dll not found in $GamePath - install ScriptHookV first."
    }
    if (-not (Test-Path (Join-Path $GamePath 'ScriptHookVDotNet3.dll'))) {
        Write-Warning "ScriptHookVDotNet3.dll not found in $GamePath - install ScriptHookVDotNet3 first."
    }
}
else {
    Write-Host "[4/4] Deployment skipped (pass -GamePath to copy into your game)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
