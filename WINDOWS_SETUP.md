# Running STRinGS on Windows (Blackwell GPUs, CUDA 12.9)

This guide sets up a [uv](https://docs.astral.sh/uv/) environment and runs the full
evaluation (train → render → metrics) automatically. It uses Python 3.12 and
torch 2.8 built for CUDA 12.9, which is required for Blackwell GPUs (sm_100 / sm_120).

## 1. Install the prerequisites (one time)

| Tool | Where to get it | Notes |
|---|---|---|
| NVIDIA driver | https://www.nvidia.com/drivers | Must be recent enough for Blackwell |
| CUDA Toolkit 12.9 | https://developer.nvidia.com/cuda-12-9-0-download-archive | Default install path is fine |
| Visual Studio 2022 Build Tools | https://visualstudio.microsoft.com/visual-cpp-build-tools/ | Tick the **"Desktop development with C++"** workload |
| Git | https://git-scm.com | |
| uv | In PowerShell: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 \| iex"` | |

Close and reopen PowerShell after installing, so the new tools are on PATH.

## 2. Get the code

```powershell
git clone -b windows-uv-setup https://github.com/ferdos202150762/far-STRINGS.git
cd far-STRINGS
git submodule update --init --recursive submodules/
```

## 3. Put the dataset in place

Put your `Datasets` folder in the repo root. You only need the datasets you actually have:

```
far-STRINGS\
└── Datasets\
    ├── STRinGS-360\   (books, chemicals, extinguisher, globe, shelf)
    ├── TandT\         (train, truck)
    └── DL3DV-10K\     (scene_3, scene_21, ...)
```

Each scene folder needs `images`, `masks` and `sparse`. If the data lives elsewhere,
for example `D:\Datasets`, skip copying it and pass `-DatasetRoot D:\Datasets` in step 5.

## 4. Set up the environment (one time, ~10–20 min)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1
```

The script finds the Visual Studio C++ compiler, checks CUDA 12.9, detects your GPU
architecture, installs the dependencies and compiles the three CUDA extensions.
When it works, it ends with lines like:

```
torch 2.8.0+cu129 | CUDA 12.9 | NVIDIA GeForce RTX 5090 sm_120
simple_knn OK ...
diff_gaussian_rasterization OK
fused_ssim OK ...
Setup complete.
```

## 5. Run the evaluation

Quick test on one scene first (recommended):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1 --scenes books
```

Full run on every dataset found:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1
```

Useful options:

| Option | Effect |
|---|---|
| `-DatasetRoot D:\Datasets` | Dataset location (default `.\Datasets`) |
| `-Output D:\results` | Output folder (default `.\eval`) |
| `--scenes books globe` | Run only these scenes |
| `--skip_training` | Reuse already-trained models |
| `--skip_training --skip_rendering` | Recompute metrics only |
| `-SkipOcr` | Don't run the OCR metric |

## 6. OCR metric (optional)

The text-legibility score uses the Google Cloud Vision API, which is paid. To enable it,
create a service account with Vision API access, download its JSON key, then set:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\key.json"
```

Without the key, the script skips OCR and still computes PSNR, SSIM and LPIPS.

## 7. Where the results are

For each scene, under `eval\<scene>\`:

- `results.json`: PSNR, SSIM and LPIPS
- `per_view.json`: the same metrics for each image
- `test_ocr_output\ocr_results.json`: the OCR metric, if enabled
- `test\ours_30000\renders\`: the rendered images

Also in `eval\`: `timing.txt` (training time per dataset) and `eval_<timestamp>.log` (full log).

## Troubleshooting

- **The setup fails while compiling the CUDA extensions**: check that Visual Studio 2022
  Build Tools has the C++ workload and that CUDA 12.9 is installed, then re-run the setup.
- **You've changed the CUDA, driver or Visual Studio version**: rebuild the extensions with
  `powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1 -Rebuild`.
- **Wrong GPU architecture detected**: force it, e.g. `scripts\setup_windows.ps1 -Rebuild -CudaArch 12.0`.
- **"running scripts is disabled on this system"**: always launch the scripts with
  `powershell -ExecutionPolicy Bypass -File ...` as shown above.
- **The first metrics run fails to download LPIPS weights**: the machine needs internet access
  to `raw.githubusercontent.com` once.
