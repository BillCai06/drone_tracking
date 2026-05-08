# Flight Checklist

> System: Jetson + ZED Mini VIO + PX4/MAVROS + px4ctrl + YOLOv26n drone tracking
> Complete every item in order before each flight. Do not fly if any item fails.

---

## 0. Personnel & Site

- [ ] Pilot holds RC, ready to switch to Manual/Stabilize at any time
- [ ] Safety observer positioned outside danger zone, in voice contact with pilot
- [ ] Target drone operator on standby
- [ ] Area clear — no bystanders within 10 m
- [ ] Local regulations confirmed (airspace, time window)

---

## 1. Pre-power Hardware Check

- [ ] Propellers tight, no cracks or chips
- [ ] Battery ≥ 80% (full-charge resting voltage ≥ 4.15 V/cell)
- [ ] ZED Mini lens clean, unobstructed, USB cable secured
- [ ] Jetson and flight controller on separate power rails (motor current can corrupt VIO)
- [ ] RC transmitter charged and bound to flight controller
- [ ] **All RC sticks centred, all switches in Manual position**

---

## 2. VIO Health Check (powered on, drone stationary)

VIO is the foundation of OFFBOARD position hold. **Do not enter OFFBOARD if this section fails.**

### 2.1 Start ZED node

```bash
roslaunch zed_wrapper zedm.launch
```

Wait for `[zed_node] ZED Ready` before continuing.

### 2.2 Verify VIO pose topic

```bash
rostopic hz /zedm/zed_node/pose           # target ≥ 50 Hz
rostopic echo /zedm/zed_node/pose --once  # confirm values are present
```

### 2.3 Static drift test (most important)

```bash
rostopic echo /zedm/zed_node/pose | grep -A3 "position"
```

**Pass criteria** (drone stationary for 30 s):
- XY drift < 2 cm
- Z drift < 3 cm
- No sudden jumps in position

> If drift is excessive: check that the ZED has rich visual texture in view (plain white walls cause drift);
> verify IMU vibration isolation; restart the ZED node to reinitialise.

### 2.4 Hand-carry motion test

Slowly carry the drone 1 m and return. Watch `/zedm/zed_node/pose`:
- [ ] Displacement matches actual direction (no axis inversions)
- [ ] Position returns to near the start after replacing drone (< 5 cm error)

---

## 3. Start MAVROS & VIO Bridge

```bash
# Starts MAVROS + ZED→PX4 EKF2 odometry bridge together
roslaunch px4ctrl px4.launch
```

- [ ] `rostopic echo /mavros/state` shows `connected: True`
- [ ] `mode` is `MANUAL` or `STABILIZED`
- [ ] `armed: False`
- [ ] VIO bridge is feeding PX4:

```bash
rostopic hz /mavros/odometry/out          # ≥ 50 Hz (bridge running)
rostopic echo /mavros/local_position/odom --once  # values present
```

In QGroundControl confirm:
- `EKF2_AID_MASK` includes Vision Position
- `ekf2_innovations` `pos_innov` is small and stable (< 0.05 m)
- [ ] No red Prearm warnings in QGroundControl
- [ ] **Confirm RC has a switch dedicated to returning to Manual (emergency takeover)**

---

## 4. Start px4ctrl

px4ctrl is the position/attitude control core. It also provides the OFFBOARD heartbeat (attitude setpoints at 100 Hz). **Must be running before the tracking system.**

```bash
roslaunch px4ctrl run_ctrl.launch
```

- [ ] Log shows `[PX4CTRL] Waiting for RC` → `[PX4CTRL] RC received`
- [ ] Log shows `[px4ctrl] Voltage=...` (battery data flowing)
- [ ] px4ctrl is in `MANUAL_CTRL` state (normal initial state)

> **Ensure all RC sticks are centred before switching to Hover mode.**
> px4ctrl will reject the mode switch with an error if any stick is off-centre,
> preventing the drone from climbing unexpectedly on entry to AUTO_HOVER.

---

## 5. Start Tracking System

### 5.1 Launch

```bash
source /opt/ros/noetic/setup.bash
source /home/zd/tracking_ws/devel/setup.bash
roslaunch drone_tracking drone_tracking.launch
```

Strongly recommended conservative parameters for first flight:

```bash
roslaunch drone_tracking drone_tracking.launch \
  kp:=0.3 \
  yaw_rate_max:=0.3
```

### 5.2 Verify nodes are healthy

```bash
rostopic hz /detector_node/detection           # ≥ 8 Hz (YOLO inference running)
rostopic hz /px4ctrl/ext_yaw_rate              # = 20 Hz (yaw command heartbeat)
rostopic echo /yaw_controller_node/control_active  # should be False (not yet enabled)
```

### 5.3 Check annotated image (optional, debug only)

```bash
# On ground station PC (same network as Jetson)
export ROS_MASTER_URI=http://<jetson_ip>:11311
rqt_image_view /detector_node/annotated_image/compressed
```

- [ ] Image looks normal; green bounding box appears when target is in frame
- [ ] `track_id` is stable during continuous tracking (not rapidly incrementing)
- [ ] `error_x` direction is intuitive (positive when target is to the right)

---

## 6. Takeoff (manual phase)

- [ ] All personnel clear of propeller arc (≥ 3 m)
- [ ] **Confirm all RC sticks are centred**, then pilot announces "arming" before arming
- [ ] Climb vertically to **1.5 m hover**, stay in Manual/Stabilize mode
- [ ] Observe hover stability for ≥ 30 s: no notable drift, no VIO jumps
- [ ] Switch to **Position mode**, verify position hold (< 20 cm drift over 30 s)

> If Position mode is unstable, **do not proceed**. Land and diagnose VIO.

---

## 7. Enter OFFBOARD & Enable Tracking

### 7.1 Pre-OFFBOARD confirmation

The OFFBOARD heartbeat is maintained by **px4ctrl** publishing attitude setpoints at 100 Hz —
it is independent of the tracking system. Simply confirm px4ctrl is running.

```bash
# px4ctrl attitude setpoints = OFFBOARD heartbeat
rostopic hz /mavros/setpoint_raw/attitude    # should show ~100 Hz
```

- [ ] Target drone is visible and track_id is stable
- [ ] px4ctrl attitude heartbeat confirmed above
- [ ] **All RC sticks centred**

### 7.2 Switch to Hover mode (px4ctrl AUTO_HOVER)

Toggle the RC mode switch to the Hover position:

- [ ] px4ctrl log shows `MANUAL_CTRL(L1) --> AUTO_HOVER(L2)`
- [ ] Drone continues hovering (no significant position change)

> If the log shows `Reject AUTO_HOVER ... sticks must be centered`,
> return all sticks to centre and toggle the switch again.

### 7.3 Switch PX4 to OFFBOARD mode

Use the RC mode switch, or:

```bash
rosservice call /mavros/set_mode "custom_mode: 'OFFBOARD'"
```

- [ ] `rostopic echo /mavros/state` shows `mode: OFFBOARD`
- [ ] No errors in px4ctrl log
- [ ] Drone continues hovering

### 7.4 Enable yaw tracking

```bash
rosservice call /yaw_controller_node/enable_control "data: true"
```

- [ ] `/yaw_controller_node/control_active` becomes `True`
- [ ] Drone slowly rotates toward the target
- [ ] Yaw rate is reasonable (at kp=0.3, max ≈ 15°/s)

### 7.5 In-flight monitoring

| Indicator | Normal | Action if abnormal |
|---|---|---|
| VIO jumps | None | Switch to Manual immediately, land |
| Yaw oscillation | No sustained oscillation | Disable tracking, reduce kp |
| Track ID stability | Same ID held for long periods | Brief switches acceptable; frequent → land and inspect |
| Battery voltage | ≥ 3.6 V/cell | Low voltage → land immediately |
| Lost-target behaviour | Yaw stops within 0.5 s, px4ctrl holds hover | Verify hover is stable |

---

## 8. Emergency Procedures

| Situation | Action |
|---|---|
| VIO pose jump / drone drifting | Switch to **Manual/Stabilize** immediately, pilot takes over |
| Yaw runaway (continuous spin) | Switch to **Manual**, pilot takes over |
| Tracking system crash | px4ctrl detects `ext_yaw_rate` timeout (0.5 s) and falls back to RC yaw stick; drone continues hovering; OFFBOARD unaffected |
| px4ctrl crash | Attitude setpoints stop; PX4 OFFBOARD times out (~0.5 s) and reverts to previous mode |
| ROS node hang | Switch to Manual, land, then `rosnode kill` |
| Motor noise / airframe vibration | Reduce throttle to minimum, switch to Manual, land |

> **The pilot can take over at any time by switching the RC mode — no software response required.**

---

## 9. Landing & Post-flight

### 9.1 Disable tracking

```bash
rosservice call /yaw_controller_node/enable_control "data: false"
```

Switch back to Position / Manual, descend and land, disarm.

### 9.2 Post-flight data review

```bash
rosbag info <bag_file>
rosbag play <bag_file>
rqt_plot /detector_node/detection/error_x
rqt_plot /detector_node/detection/track_id
```

- [ ] `error_x` converges smoothly (if oscillating, reduce kp next flight)
- [ ] `track_id` stable fraction > 80% (otherwise investigate multi-detection interference)
- [ ] VIO trajectory has no jumps

---

## 10. Parameter Tuning Guide

### kp tuning sequence

1. Start with `kp=0.3, yaw_rate_max=0.3`
2. Too slow (target clearly off-centre but drone barely turns) → increase kp to 0.5
3. Sustained oscillation → decrease kp or increase `deadband`
4. Target: `kp=0.8–1.0`, no oscillation, centres within 1–2 s

### Velocity safety limit

px4ctrl enforces a hard `max_cmd_vel = 0.5 m/s` cap on any autonomous position command,
even if the planner requests more. To change it edit `px4ctrl/config/ctrl_param_fpv.yaml`.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hover mode switch rejected | RC sticks not centred | Return all sticks to centre and retry |
| OFFBOARD exits immediately | px4ctrl not running — attitude heartbeat absent | Confirm `run_ctrl.launch` is up |
| Position mode drifts after takeoff | Insufficient VIO texture or excessive vibration | Add floor texture markers, check vibration damping |
| Yaw direction reversed | Frame convention mismatch | See comments in `yaw_controller_node.py` |
| track_id increments rapidly | Multi-target detection conflict | Sticky ID fix already applied; if still happening, inspect `annotated_image` |
| High detection latency | `rqt_image_view` or RViz open, consuming image bandwidth | Close annotated image subscriber when not debugging |

---

## Appendix: Topic Reference

| Topic | Type | Purpose |
|---|---|---|
| `/zedm/zed_node/pose` | `PoseStamped` | Raw ZED VIO pose |
| `/mavros/odometry/out` | `Odometry` | VIO bridge output to PX4 EKF2 |
| `/mavros/state` | `State` | FCU connection / mode / arm state |
| `/mavros/local_position/odom` | `Odometry` | EKF2 fused pose (used by px4ctrl) |
| `/mavros/setpoint_raw/attitude` | `AttitudeTarget` | px4ctrl attitude cmd — OFFBOARD heartbeat (100 Hz) |
| `/px4ctrl/ext_yaw_rate` | `TwistStamped` | Yaw rate command from yaw_ctrl → px4ctrl (20 Hz) |
| `/detector_node/detection` | `Detection` | Per-frame detection result (cx/cy/error_x/track_id) |
| `/detector_node/annotated_image/compressed` | `CompressedImage` | Debug view (only published when subscribed) |
| `/yaw_controller_node/control_active` | `Bool` | True when actively commanding yaw |
| `/yaw_controller_node/enable_control` | `SetBool` service | Enable / disable yaw tracking |
