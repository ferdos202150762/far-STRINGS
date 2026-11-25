#
# Copyright (C) 2023, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

import os
import subprocess
import sys
import time
from argparse import ArgumentParser

DATASETS = {
    # name: (cli flag dest, scenes, max_densify per scene)
    "s360": ("strings360", ["extinguisher", "books", "chemicals", "globe", "shelf"], [25, 25, 25, 25, 25]),
    "tandt": ("tanksandtemples", ["truck", "train"], [20, 15]),
    "dl3dv": ("dl3dv", ["scene_3", "scene_21", "scene_80", "scene_92", "scene_107", "scene_132", "scene_136"],
              [20, 20, 15, 20, 20, 15, 15]),
}

parser = ArgumentParser(description="Full evaluation script parameters")
parser.add_argument("--skip_training", action="store_true")
parser.add_argument("--skip_rendering", action="store_true")
parser.add_argument("--skip_metrics", action="store_true")
parser.add_argument("--skip_ocr", action="store_true", help="Skip OCR metrics (needs Google Cloud Vision credentials)")
parser.add_argument("--output_path", default="./eval")
parser.add_argument("--use_depth", action="store_true")
parser.add_argument("--use_expcomp", action="store_true")
parser.add_argument("--fast", action="store_true")
parser.add_argument("--aa", action="store_true")
parser.add_argument("--scenes", nargs="+", default=None, help="Only run these scenes (e.g. books globe)")
# Each dataset is optional: only the ones given are evaluated.
parser.add_argument("--strings360", "-s360", type=str, default=None)
parser.add_argument("--tanksandtemples", "-tat", type=str, default=None)
parser.add_argument("--dl3dv", "-dl3dv", type=str, default=None)
args = parser.parse_args()

# (dataset, scene, source path, max_densify)
jobs = []
for name, (dest, scenes, max_densifies) in DATASETS.items():
    root = getattr(args, dest)
    if root is None:
        continue
    for scene, max_densify in zip(scenes, max_densifies):
        if args.scenes and scene not in args.scenes:
            continue
        jobs.append((name, scene, os.path.join(root, scene), max_densify))

if not jobs:
    parser.error("No scenes selected: pass at least one of -s360 / -tat / -dl3dv (and check --scenes).")

os.makedirs(args.output_path, exist_ok=True)
failures = []


def run(cmd):
    """Run a script with the current interpreter (the uv venv); record failures instead of ignoring them."""
    full_cmd = [sys.executable] + cmd
    print("\n>>> " + " ".join(full_cmd), flush=True)
    result = subprocess.run(full_cmd)
    if result.returncode != 0:
        print(f"!!! Command failed with exit code {result.returncode}", flush=True)
        failures.append(" ".join(cmd))
    return result.returncode == 0


def model_path(scene):
    return os.path.join(args.output_path, scene)


if not args.skip_training:
    common_args = ["--disable_viewer", "--quiet", "--eval", "--test_iterations", "-1"]
    if args.aa:
        common_args += ["--antialiasing"]
    if args.use_depth:
        common_args += ["-d", "depths2/"]
    if args.use_expcomp:
        common_args += ["--exposure_lr_init", "0.001", "--exposure_lr_final", "0.0001",
                        "--exposure_lr_delay_steps", "5000", "--exposure_lr_delay_mult", "0.001", "--train_test_exp"]
    if args.fast:
        common_args += ["--optimizer_type", "sparse_adam"]

    timings = {}
    for name, scene, source, max_densify in jobs:
        start = time.time()
        run(["train.py", "-s", source, "-m", model_path(scene), "--max_densify", str(max_densify)] + common_args)
        timings[name] = timings.get(name, 0.0) + (time.time() - start) / 60.0

    with open(os.path.join(args.output_path, "timing.txt"), "w") as file:
        for name, minutes in timings.items():
            file.write(f"{name}: {minutes} minutes\n")

if not args.skip_rendering:
    common_args = ["--quiet", "--eval", "--skip_train"]
    if args.aa:
        common_args += ["--antialiasing"]
    if args.use_expcomp:
        common_args += ["--train_test_exp"]

    for _, scene, source, _ in jobs:
        for iteration in ("7000", "30000"):
            run(["render.py", "--iteration", iteration, "-s", source, "-m", model_path(scene)] + common_args)

if not args.skip_metrics:
    model_paths = [model_path(scene) for _, scene, _, _ in jobs]
    run(["metrics.py", "-m"] + model_paths)
    if not args.skip_ocr:
        run(["metrics_ocr.py", "-m"] + model_paths)

if failures:
    print(f"\n{len(failures)} step(s) failed:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nFull evaluation finished successfully.")
