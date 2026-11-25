<#
.SYNOPSIS
    One-time setup of the STRinGS uv environment on Windows (CUDA 12.9, Blackwell GPUs).

.DESCRIPTION
    1. Checks uv, git, the NVIDIA driver and the CUDA 12.9 toolkit.
    2. Loads the MSVC x64 build environment (Visual Studio 2022 Build Tools).
    3. Fetches the CUDA-extension submodules if they are missing.
    4. Detects the GPU compute capability (sm_120 for RTX 50 / RTX PRO, sm_100 for B200).
    5. Installs Python + all dependencies with uv, then compiles simple-knn,
       diff-gaussian-rasterization and fused-ssim against the installed torch.
    6. Runs a smoke test on the GPU.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1
    powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1 -Rebuild
    powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1 -CudaArch 12.0
#>
param(
    # Force recompilation of the CUDA extensions.
    [switch]$Rebuild,
    # Override the detected compute capability, e.g. "12.0" or "10.0" or "10.0;12.0".
    [string]$CudaArch = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Check-Exit($what) { if ($LASTEXITCODE -ne 0) { Fail "$what failed (exit code $LASTEXITCODE)." } }

# --- 1. Tools -----------------------------------------------------------------
Step "Checking required tools"
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Fail "uv not found. Install it with:  powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git not found." }
if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { Fail "nvidia-smi not found - is the NVIDIA driver installed?" }

if (-not $env:CUDA_PATH) {
    $default = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"
    if (Test-Path $default) { $env:CUDA_PATH = $default } else { Fail "CUDA_PATH is not set and CUDA 12.9 was not found at $default." }
}
$nvcc = Join-Path $env:CUDA_PATH "bin\nvcc.exe"
if (-not (Test-Path $nvcc)) { Fail "nvcc.exe not found in $env:CUDA_PATH\bin." }
$nvccVersion = (& $nvcc --version) -join "`n"
if ($nvccVersion -notmatch "release 12\.9") {
    Write-Host "WARNING: nvcc is not CUDA 12.9 ($env:CUDA_PATH). torch is built for cu129; other 12.x versions usually work." -ForegroundColor Yellow
}
$env:CUDA_HOME = $env:CUDA_PATH
$env:PATH = "$env:CUDA_PATH\bin;$env:PATH"
Write-Host "CUDA toolkit: $env:CUDA_PATH"

# --- 2. MSVC ------------------------------------------------------------------
Step "Loading the MSVC x64 build environment"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Fail "Visual Studio not found. Install 'Build Tools for Visual Studio 2022' with the 'Desktop development with C++' workload."
}
$vcComponent = "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
# CUDA 12.9 officially supports VS 2022 (v17); prefer it over newer versions.
$vsPath = & $vswhere -latest -products * -version "[17.0,18.0)" -requires $vcComponent -property installationPath
if (-not $vsPath) {
    $vsPath = & $vswhere -latest -products * -requires $vcComponent -property installationPath
    if (-not $vsPath) { Fail "No Visual Studio install with C++ build tools (x64) found." }
    Write-Host "WARNING: VS 2022 not found; using $vsPath with -allow-unsupported-compiler." -ForegroundColor Yellow
    $env:NVCC_APPEND_FLAGS = "-allow-unsupported-compiler"
}
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { Fail "cl.exe not available after running vcvars64.bat." }
$env:DISTUTILS_USE_SDK = "1"
Write-Host "MSVC: $vsPath"

# --- 3. Submodules ------------------------------------------------------------
Step "Checking CUDA extension submodules"
$needed = @("submodules\simple-knn\setup.py", "submodules\diff-gaussian-rasterization\setup.py",
            "submodules\fused-ssim\setup.py", "submodules\diff-gaussian-rasterization\third_party\glm\glm\glm.hpp")
if ($needed | Where-Object { -not (Test-Path $_) }) {
    git submodule update --init --recursive submodules/
    Check-Exit "git submodule update"
} else { Write-Host "Submodules present." }

# --- 4. GPU architecture ------------------------------------------------------
Step "Detecting GPU architecture"
if (-not $CudaArch) {
    $caps = (& nvidia-smi --query-gpu=compute_cap --format=csv,noheader) | ForEach-Object { $_.Trim() } | Sort-Object -Unique
    Check-Exit "nvidia-smi"
    $CudaArch = $caps -join ";"
}
$env:TORCH_CUDA_ARCH_LIST = $CudaArch                       # used by simple-knn / diff-gaussian-rasterization
$env:CUDA_ARCHITECTURES = ($CudaArch -replace "\.", "")     # used by fused-ssim (e.g. "120")
& nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv
Write-Host "Building for compute capability: $CudaArch"

# --- 5. Python environment ----------------------------------------------------
Step "Installing Python 3.12 and dependencies (without the CUDA extensions)"
$exts = @("simple-knn", "diff-gaussian-rasterization", "fused-ssim")
$skipArgs = $exts | ForEach-Object { "--no-install-package", $_ }
uv sync @skipArgs
Check-Exit "uv sync (phase 1)"

Step "Compiling CUDA extensions (this takes several minutes)"
$extraArgs = @()
if ($Rebuild) { $extraArgs = $exts | ForEach-Object { "--reinstall-package", $_ } }
uv sync @extraArgs
Check-Exit "uv sync (phase 2: CUDA extensions)"

# --- 6. Smoke test ------------------------------------------------------------
Step "Smoke test"
$test = @"
import torch
assert torch.cuda.is_available(), 'CUDA not available to torch'
print('torch', torch.__version__, '| CUDA', torch.version.cuda, '|', torch.cuda.get_device_name(0), 'sm_%d%d' % torch.cuda.get_device_capability(0))
from simple_knn._C import distCUDA2
d = distCUDA2(torch.rand(1000, 3, device='cuda'))
print('simple_knn OK', tuple(d.shape))
from diff_gaussian_rasterization import GaussianRasterizer, GaussianRasterizationSettings
print('diff_gaussian_rasterization OK')
from fused_ssim import fused_ssim
a = torch.rand(1, 3, 64, 64, device='cuda', requires_grad=True)
print('fused_ssim OK', float(fused_ssim(a, torch.rand(1, 3, 64, 64, device='cuda'))))
"@
uv run --no-sync python -c $test
Check-Exit "Smoke test"

Write-Host "`nSetup complete. Run the evaluation with:" -ForegroundColor Green
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1" -ForegroundColor Green
