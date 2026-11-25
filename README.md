<div align="center">
    <h1>STRinGS: Selective Text Refinement in Gaussian Splatting<br>
        <span style="font-size:0.6em;">WACV 2026</span>
    </h1>
    <p style="font-size:1.2em;">
        <a href="https://www.linkedin.com/in/abhinav-raundhal/">Abhinav Raundhal</a><sup>*</sup>,
        <a href="https://www.linkedin.com/in/gauravbehera/">Gaurav Behera</a><sup>*</sup>,<br>
        <a href="https://faculty.iiit.ac.in/~pjn/">P. J. Narayanan</a>,
        <a href="https://ravika.github.io/">Ravi Kiran Sarvadevabhatla</a>,
        <a href="https://makarandtapaswi.github.io/">Makarand Tapaswi</a>
    </p>
    <p align="center">
        <a href="https://arxiv.org/abs/2512.07230"><img src="https://img.shields.io/badge/arXiv-b31b1b.svg?logo=arxiv&style=for-the-badge" alt="arXiv"></a>
        <a href="https://STRinGS-official.github.io/"><img src="https://img.shields.io/badge/Project%20Page-2e8a04.svg?logo=googlechrome&logoColor=80c95d&style=for-the-badge" alt="Project Page"></a>
        <a href="https://drive.google.com/drive/folders/19hgxxiqQNRYgqhvVhgflq7GIZu-RgIN3?usp=sharing"><img src="https://img.shields.io/badge/STRinGS--360-blue?logo=googledrive&logoColor=77cbfc&style=for-the-badge" alt="STRinGS-360 Dataset"></a>
    </p>
</div>




<p align="center">
  <img src="assets/teaser.png" width="80%"/>
  <br>
  <em>STRinGS (bottom) produces sharper and readable text
as compared to vanilla 3DGS (top)</em>
</p>

## Announcements
* [Feb 4, 2026] 🚀 Code Released!
* [Dec 25, 2025] 🎁 STRinGS-360 Dataset is now available! <a href="https://drive.google.com/drive/folders/19hgxxiqQNRYgqhvVhgflq7GIZu-RgIN3?usp=sharing">Download here</a>.
* [Dec 12, 2025] 🔗 Project Page is live! Check it out <a href="https://STRinGS-official.github.io/">here</a>.
* [Nov 9, 2025] 🎉 Paper accepted to WACV 2026!
---

## Setup Instructions

1. Clone the repository:
    ```bash
    # HTTPS
    git clone --recursive https://github.com/STRinGS-official/STRinGS.git
    cd STRinGS
    ```
    ```bash
    # SSH
    git clone --recursive git@github.com:STRinGS-official/STRinGS.git
    cd STRinGS
    ```

2. Create a virtual environment and activate it:
    ```bash
    conda env create --file environment.yml
    conda activate strings
    pip install submodules/*
    ```

### Windows + Blackwell GPUs (uv)

Uses torch 2.8 built for CUDA 12.9 (required for Blackwell, sm_100 / sm_120) and Python 3.12.

Prerequisites: NVIDIA driver, [CUDA Toolkit 12.9](https://developer.nvidia.com/cuda-12-9-0-download-archive), [Build Tools for Visual Studio 2022](https://visualstudio.microsoft.com/visual-cpp-build-tools/) with the *Desktop development with C++* workload, git and [uv](https://docs.astral.sh/uv/).

```powershell
git clone https://github.com/ferdos202150762/far-STRINGS.git
cd far-STRINGS
git submodule update --init --recursive submodules/

# One-time: installs dependencies and compiles the CUDA extensions for your GPU
powershell -ExecutionPolicy Bypass -File scripts\setup_windows.ps1

# Train + render + metrics on every dataset found in .\Datasets
powershell -ExecutionPolicy Bypass -File scripts\run_eval.ps1
```

`run_eval.ps1` accepts `-DatasetRoot`, `-Output`, `-SkipOcr`, and any `full_eval.py` flag (e.g. `--scenes books globe`, `--skip_training`). OCR metrics call the Google Cloud Vision API and only run when `GOOGLE_APPLICATION_CREDENTIALS` points to a service-account JSON key.

## Datasets

Download all the datasets (STRinGS-360, Tanks&Temples and DL3DV-10K Benchmark) used in the paper [here](https://drive.google.com/drive/folders/17_rvrx7JYrCaDjWRKG1RuJSKLXUuD9Hq?usp=sharing). Place the `Datasets` folder in the root directory of the repository.

The dataset structure is as follows:
```
Datasets
├── DL3DV-10K
│   ├── multilingual
│   ├── scene_107
│   ├── scene_132
│   ├── scene_136
│   ├── scene_21
│   ├── scene_3
│   ├── scene_80
│   └── scene_92
├── STRinGS-360
│   ├── books
│   ├── chemicals
│   ├── extinguisher
│   ├── globe
│   └── shelf
└── TandT
    ├── train
    └── truck
```

Each scene should have the following structure:
```
scene_name
├── hisam_jsons
├── images
├── input
├── masks
├── masks_vis
└── sparse
```

The `masks` folder should contain binary text masks corresponding to each image in the `images` folder. This can be generated using any off-the-shelf text detection method. Our implementation using Hi-SAM can be found [here](https://github.com/strings-official/Hi-SAM). Run the following command to generate text masks using Hi-SAM:

```bash
bash text_segmentation.sh <dataset_path> <dilation_factor>
```
For all experiments, we used a dilation factor of 20% of the image width.

## Training and Evaluation

To replicate the results in the paper, run the following:

```bash
python full_eval.py -s360 Datasets/STRinGS-360/ -tat Datasets/TandT/ -dl3dv Datasets/DL3DV-10K/
```

For running on individual datasets, use the following commands:

1. Train
    ```bash
    python train.py -s <dataset_path> -m <model_output> --eval --phase_separator <phase_separator>
    ```

2. Render
    ```bash
    python render.py -m <model_output> --skip_train
    ```

3. Metrics
    ```bash
    python metrics.py -m <model_output>
    python metrics_ocr.py -m <model_output>
    ```

<section class="section" id="BibTeX">
  <div class="container is-max-desktop content">
    <h2 class="title">BibTeX</h2>
    <pre><code>@InProceedings{STRinGS_2026_WACV,
  author    = {Raundhal, Abhinav and Behera, Gaurav and Narayanan, P. J. and Sarvadevabhatla, Ravi Kiran and Tapaswi, Makarand},
  title     = {STRinGS: Selective Text Refinement in Gaussian Splatting},
  booktitle = {Proceedings of the Winter Conference on Applications of Computer Vision (WACV)},
  month     = {March},
  year      = {2026},
}</code></pre>
  </div>
</section>
