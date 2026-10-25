$ErrorActionPreference = 'Stop'

$reproDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = Split-Path -Parent $reproDirectory
$appRoot = Join-Path $packageRoot 'source_snapshot'
$auditedRscript = 'C:\Program Files\R\R-4.6.0\bin\Rscript.exe'

if (Test-Path -LiteralPath $auditedRscript) {
    $rscriptPath = $auditedRscript
} else {
    $rscriptCommand = Get-Command 'Rscript.exe' -ErrorAction SilentlyContinue
    if ($null -eq $rscriptCommand) {
        throw 'Rscript.exe was not found. Install 64-bit R 4.6.0 or add it to PATH.'
    }
    $rscriptPath = $rscriptCommand.Source
}

$mainApp = Join-Path $appRoot 'PASA.R'
$module = Join-Path $appRoot 'deconvolution_module.R'
$runner = Join-Path $reproDirectory 'RUN_PASA.R'
if (-not (Test-Path -LiteralPath $mainApp)) {
    throw "Missing main application: $mainApp"
}
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Missing R launcher: $runner"
}
if (-not (Test-Path -LiteralPath $module)) {
    Write-Warning 'deconvolution_module.R is missing; Advanced-Mode deconvolution will be unavailable.'
}

Push-Location -LiteralPath $appRoot
$previousLaunchBrowser = $env:PASA_LAUNCH_BROWSER
$previousAppDirectory = $env:PASA_APP_DIR
$previousDesktopMode = $env:SPECTRA_DESKTOP_MODE
try {
    if ([string]::IsNullOrWhiteSpace($previousLaunchBrowser)) {
        $env:PASA_LAUNCH_BROWSER = '1'
    } else {
        $env:PASA_LAUNCH_BROWSER = $previousLaunchBrowser
    }
    $env:PASA_APP_DIR = $appRoot
    $env:SPECTRA_DESKTOP_MODE = '1'
    & $rscriptPath --vanilla $runner
    if ($LASTEXITCODE -ne 0) {
        throw "PASA exited with code $LASTEXITCODE."
    }
} finally {
    if ($null -eq $previousLaunchBrowser) {
        Remove-Item Env:PASA_LAUNCH_BROWSER -ErrorAction SilentlyContinue
    } else {
        $env:PASA_LAUNCH_BROWSER = $previousLaunchBrowser
    }
    if ($null -eq $previousAppDirectory) {
        Remove-Item Env:PASA_APP_DIR -ErrorAction SilentlyContinue
    } else {
        $env:PASA_APP_DIR = $previousAppDirectory
    }
    if ($null -eq $previousDesktopMode) {
        Remove-Item Env:SPECTRA_DESKTOP_MODE -ErrorAction SilentlyContinue
    } else {
        $env:SPECTRA_DESKTOP_MODE = $previousDesktopMode
    }
    Pop-Location
}
