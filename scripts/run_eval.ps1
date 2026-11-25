<#
.SYNOPSIS
    Train, render and evaluate STRinGS on every dataset found under -DatasetRoot.

.DESCRIPTION
    Looks for Datasets\STRinGS-360, Datasets\TandT and Datasets\DL3DV-10K and runs
    full_eval.py on whichever exist. OCR metrics use Google Cloud Vision and run only
    when GOOGLE_APPLICATION_CREDENTIALS points to a service-account key (or -SkipOcr
    is not given and credentials exist). Any extra arguments are passed to full_eval.py.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1
    powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1 -DatasetRoot D:\Datasets -Output D:\strings_eval
    powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1 --scenes books globe
    powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1 --skip_training --skip_rendering
#>
param(
    [string]$DatasetRoot = "Datasets",
    [string]$Output = "eval",
    [switch]$SkipOcr,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$evalArgs = @("--output_path", $Output)
$found = @()
foreach ($ds in @(@("STRinGS-360", "-s360"), @("TandT", "-tat"), @("DL3DV-10K", "-dl3dv"))) {
    $path = Join-Path $DatasetRoot $ds[0]
    if (Test-Path $path) { $evalArgs += @($ds[1], $path); $found += $ds[0] }
}
if (-not $found) { Write-Host "ERROR: no datasets found under '$DatasetRoot'." -ForegroundColor Red; exit 1 }
Write-Host "Datasets: $($found -join ', ')"

if (-not $SkipOcr -and -not ($env:GOOGLE_APPLICATION_CREDENTIALS -and (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS))) {
    Write-Host "GOOGLE_APPLICATION_CREDENTIALS not set: skipping OCR metrics (PSNR/SSIM/LPIPS still run)." -ForegroundColor Yellow
    $SkipOcr = $true
}
if ($SkipOcr) { $evalArgs += "--skip_ocr" }

$log = Join-Path $Output ("eval_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
New-Item -ItemType Directory -Force -Path $Output | Out-Null
Write-Host "Logging to $log"

$env:PYTHONUNBUFFERED = "1"
# Progress bars go to stderr; with "Stop", Windows PowerShell 5.1 would abort on them when redirected.
$ErrorActionPreference = "Continue"
# --no-sync: never trigger a rebuild of the CUDA extensions outside the MSVC environment.
uv run --no-sync python full_eval.py @evalArgs @ExtraArgs 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
if ($code -eq 0) {
    Write-Host "`nDone. Per-scene results: $Output\<scene>\results.json (and test_ocr_output\ocr_results.json)" -ForegroundColor Green
} else {
    Write-Host "`nEvaluation finished with failures (exit code $code). See $log" -ForegroundColor Red
}
exit $code
