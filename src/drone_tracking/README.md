# drone_tracking

Visual yaw-tracking for a quadrotor: detects a target drone in the ZED Mini image stream using a TensorRT YOLO model, then commands the host drone to rotate and keep the target centred in frame.

Runs on a Jetson with ROS Noetic, ZED Mini, PX4/MAVROS, and [px4ctrl](https://github.com/BillCai06/Fast-Drone-250).

---

## Architecture

```
ZED Mini
  └─ /zedm/zed_node/left/image_rect_color/compressed
        │
        ▼
  detector_node  (YOLO TensorRT + ByteTrack)
        │  /detector_node/detection  (drone_tracking/Detection)
        ▼
  yaw_controller_node  (P controller)
        │  /px4ctrl/ext_yaw_rate  (geometry_msgs/TwistStamped)
        ▼
  px4ctrl  ──►  /mavros/setpoint_raw/attitude  ──►  PX4
```

The yaw controller feeds its output into **px4ctrl** via `/px4ctrl/ext_yaw_rate` — NOT directly to MAVROS. px4ctrl blends the external yaw rate into its hover setpoint so that attitude and yaw control remain in one place and do not fight each other.

---

## Dependencies

| Dependency | Notes |
|---|---|
| ROS Noetic | |
| [px4ctrl](https://github.com/BillCai06/Fast-Drone-250) | Must be built and running |
| MAVROS | `sudo apt install ros-noetic-mavros` |
| ZED ROS wrapper | `zed_wrapper` package for ZED Mini |
| CUDA / TensorRT | For TensorRT engine inference |
| Ultralytics YOLO | In conda env — see `run_detector_conda.sh` |
| ByteTrack | Bundled in `Scout-Vision/` |

---

## Build

```bash
cd ~/tracking_ws
catkin_make
source devel/setup.bash
```

---

## Quick Start

**1. Start ZED Mini**
```bash
roslaunch zed_wrapper zedm.launch
```

**2. Start MAVROS + VIO bridge**
```bash
roslaunch px4ctrl px4.launch
```

**3. Start px4ctrl**
```bash
roslaunch px4ctrl run_ctrl.launch
```

**4. Start drone tracking**
```bash
roslaunch drone_tracking drone_tracking.launch
```

For a conservative first flight:
```bash
roslaunch drone_tracking drone_tracking.launch kp:=0.3 yaw_rate_max:=0.3
```

**5. Enable yaw tracking** (after the drone is in OFFBOARD and hovering stably)
```bash
rosservice call /yaw_controller_node/enable_control "data: true"
```

---

## Parameters

### Detector (`detector_node`)

| Parameter | Default | Description |
|---|---|---|
| `engine_path` | `yolo26n_neo_720_v3.engine` | Path to TensorRT `.engine` file |
| `image_topic` | `/zedm/zed_node/left/image_rect_color` | Input image topic |
| `use_compressed` | `true` | Subscribe to compressed image |
| `conf` | `0.06` | YOLO confidence threshold |
| `class_id` | `0` | Target class ID (0 = drone) |

### Yaw Controller (`yaw_controller_node`)

| Parameter | Default | Description |
|---|---|---|
| `kp` | `1.0` | Proportional gain (rad/s per normalised error unit) |
| `yaw_rate_max` | `0.8` | Hard clamp on output yaw rate (rad/s) |
| `deadband` | `0.01` | Normalised error deadband (~1.4% of FOV) |
| `detection_stale_sec` | `0.5` | Age after which a detection is ignored |
| `heartbeat_hz` | `20.0` | Control loop rate (Hz) |
| `require_offboard` | `true` | Only control when PX4 is in OFFBOARD mode |

**Tuning guide:** start at `kp=0.3, yaw_rate_max=0.3`. Increase `kp` if response is too slow; reduce it or increase `deadband` if yaw oscillates. Target steady-state: `kp=0.8–1.0` with no oscillation.

---

## Topics & Services

| Topic / Service | Type | Direction | Description |
|---|---|---|---|
| `/detector_node/detection` | `drone_tracking/Detection` | publish | Detection result per frame |
| `/detector_node/annotated_image/compressed` | `CompressedImage` | publish | Debug view (only published when subscribed) |
| `/detector_node/status` | `String` | publish | `"detected"` or `"none"` |
| `/px4ctrl/ext_yaw_rate` | `TwistStamped` | publish | Yaw rate command to px4ctrl (`angular.z`) |
| `/yaw_controller_node/control_active` | `Bool` | publish | `true` when actively commanding yaw |
| `/yaw_controller_node/enable_control` | `SetBool` service | subscribe | Enable / disable yaw tracking |

### Detection message

```
std_msgs/Header header
bool    detected    # target visible this frame
float32 cx          # normalised horizontal centre [0, 1]
float32 cy          # normalised vertical centre [0, 1]
float32 width       # normalised bounding box width
float32 height      # normalised bounding box height
float32 conf        # detection confidence
int32   track_id    # ByteTrack persistent ID (-1 if untracked)
float32 error_x     # cx - 0.5  (negative = target left, positive = target right)
```

---

## Sign conventions

- `error_x > 0` → target is to the right → yaw clockwise → `angular.z < 0` (ROS ENU body frame)
- px4ctrl applies `ext_yaw_rate` only when a fresh message (< 0.5 s old) is present; falls back to RC yaw stick otherwise

---

## Flight checklist

See [FLIGHT_CHECKLIST.md](FLIGHT_CHECKLIST.md) for the full pre-flight and in-flight procedure.

> **Emergency:** switch the RC to Manual/Stabilize at any time to override OFFBOARD and regain manual control.
