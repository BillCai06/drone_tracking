#!/usr/bin/env bash
set -euo pipefail

# yaw_controller only needs ROS + mavros_msgs — system Python 3.8 is fine.
# This wrapper exists for uniformity; swap ENV_NAME if you want a conda env.
SYSTEM_PY="/usr/bin/python3"

export PYTHONPATH=\
"/opt/ros/noetic/lib/python3/dist-packages:\
${PYTHONPATH:-}"

export PYTHONNOUSERSITE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[run_yaw_ctrl] python: ${SYSTEM_PY}"

exec "${SYSTEM_PY}" -u "${SCRIPT_DIR}/yaw_controller_node.py" "$@"
