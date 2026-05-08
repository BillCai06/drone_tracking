#!/usr/bin/env bash
set -euo pipefail

# yolo_tracking env has: ultralytics, opencv, matplotlib, torchvision egg
# blipseg env has:       torch 2.0.0+nv23.05 (JetPack CUDA 11.4 wheel)
# We use yolo_tracking's Python but pull CUDA torch from blipseg via PYTHONPATH.
CONDA_ROOT="/opt/miniforge"
PY="${CONDA_ROOT}/envs/yolo_tracking/bin/python"
BLIPSEG_SITE="${CONDA_ROOT}/envs/blipseg/lib/python3.8/site-packages"

# LD_LIBRARY_PATH: blipseg torch libs first (CUDA), then system CUDA, then Jetson, then ROS
export LD_LIBRARY_PATH=\
"${BLIPSEG_SITE}/torch/lib:\
/usr/local/cuda/lib64:\
/usr/lib/aarch64-linux-gnu:\
/opt/ros/noetic/lib:\
${LD_LIBRARY_PATH:-}"

# PYTHONPATH order:
#   1) blipseg site-packages  — CUDA torch 2.0.0+nv23.05
#   2) system dist-packages   — tensorrt 8.5.2.2, pycuda, other Jetson libs
#   3) ROS Noetic             — rospy, sensor_msgs, etc.
# yolo_tracking's own site-packages (ultralytics, opencv, …) come from
# Python's built-in site mechanism, not PYTHONPATH.
export PYTHONPATH=\
"${BLIPSEG_SITE}:\
/usr/lib/python3.8/dist-packages:\
/usr/local/lib/python3.8/dist-packages:\
/opt/ros/noetic/lib/python3/dist-packages:\
${PYTHONPATH:-}"

export PYTHONNOUSERSITE=1
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[run_detector_conda] python : ${PY}"
echo "[run_detector_conda] PYTHONPATH snippet: ${BLIPSEG_SITE::40}..."

exec "${PY}" -u "${SCRIPT_DIR}/detector_node.py" "$@"
