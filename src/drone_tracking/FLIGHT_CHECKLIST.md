# 真机实验飞行前检查单

> 适用系统：Jetson + ZED Mini VIO + PX4/MAVROS + px4ctrl + YOLOv26n 无人机跟踪
> 每次飞行前必须按顺序完成所有 ✅ 项，任何一项不达标禁止飞行。

---

## 0. 人员与场地

- [ ] 飞手持遥控器，随时可切 Manual/Stabilize 模式
- [ ] 安全员站在安全距离之外，与飞手保持语音联系
- [ ] 目标无人机操作手就位，待命起飞
- [ ] 场地净空、无闲杂人员进入 10 m 范围
- [ ] 已确认当地法规允许飞行（空域、时段）

---

## 1. 硬件上电前检查

- [ ] 机体螺旋桨安装紧固，桨叶无缺口裂纹
- [ ] 电池电量 ≥ 80%（满电静态电压 ≥ 4.15 V/cell）
- [ ] ZED Mini 镜头清洁，无遮挡，USB 线缆固定不松动
- [ ] Jetson 电源与飞控电源分开供电（避免推力电流干扰 VIO）
- [ ] 遥控器电量充足，与飞控已对频
- [ ] **遥控器所有摇杆居中，拨杆处于 Manual 位**

---

## 2. VIO 稳定性验证（上电后，地面静止）

VIO 是 OFFBOARD 位置保持的基础，**此步不达标禁止进入 OFFBOARD 模式**。

### 2.1 启动 ZED 节点

```bash
roslaunch zed_wrapper zedm.launch
```

等待输出 `[zed_node] ZED Ready` 后继续。

### 2.2 检查 VIO 位姿话题

```bash
rostopic hz /zedm/zed_node/pose          # 目标 ≥ 50 Hz
rostopic echo /zedm/zed_node/pose --once  # 确认有数值输出
```

### 2.3 静止漂移测试（最重要）

```bash
rostopic echo /zedm/zed_node/pose | grep -A3 "position"
```

**合格标准**（机体静止放置 30 s）：
- XY 漂移 < 2 cm
- Z 漂移 < 3 cm
- 位姿无突变（无跳变）

> 若漂移超标：检查 ZED 视野内纹理是否丰富（白墙等低纹理区域会导致 VIO 漂移）；
> 确认 IMU 振动隔离；重启 ZED 节点重新初始化。

### 2.4 手持机体缓慢移动测试

手持飞机缓慢移动 1 m 再归位，观察 `/zedm/zed_node/pose`：
- [ ] 位移与实际运动方向一致（方向无反转）
- [ ] 归位后位姿回到初始值附近（< 5 cm 偏差）

---

## 3. 启动 MAVROS 与飞控桥接

```bash
# 包含 MAVROS + ZED→PX4 VIO 桥接
roslaunch px4ctrl px4.launch
```

- [ ] `rostopic echo /mavros/state` 输出 `connected: True`
- [ ] `mode` 初始为 `MANUAL` 或 `STABILIZED`
- [ ] `armed: False`
- [ ] 确认 VIO 已接入飞控：

```bash
rostopic hz /mavros/odometry/out         # ≥ 50 Hz（VIO 桥接正常）
rostopic echo /mavros/local_position/odom --once  # 有数值输出
```

在 QGroundControl 中确认：
- `EKF2_AID_MASK` 包含 Vision Position
- `ekf2_innovations` 中 `pos_innov` 小且稳定（< 0.05 m）
- [ ] QGroundControl 中无红色 Prearm 告警
- [ ] **确认遥控器有拨杆可随时切回 Manual（紧急接管）**

---

## 4. 启动 px4ctrl

px4ctrl 是位置/姿态控制核心，也是 OFFBOARD 心跳来源（100 Hz 姿态指令）。
**必须在启动跟踪系统之前运行。**

```bash
roslaunch px4ctrl run_ctrl.launch
```

- [ ] 日志出现 `[PX4CTRL] Waiting for RC` → `[PX4CTRL] RC received`
- [ ] 日志出现 `[px4ctrl] Voltage=...`（电池数据正常）
- [ ] 确认 px4ctrl 处于 `MANUAL_CTRL` 状态（初始状态，正常）

> **切入 Hover 模式前确认摇杆全部居中。** px4ctrl 会检查并拒绝摇杆未居中时的模式切换，
> 防止上次实验"遥控器未居中导致无人机自动爬升"的事故重现。

---

## 5. 启动跟踪系统

### 5.1 运行

```bash
source /opt/ros/noetic/setup.bash
source /home/zd/tracking_ws/devel/setup.bash
roslaunch drone_tracking drone_tracking.launch
```

首飞强烈建议使用保守参数：

```bash
roslaunch drone_tracking drone_tracking.launch \
  kp:=0.3 \
  yaw_rate_max:=0.3
```

### 5.2 验证各节点正常

```bash
rostopic hz /detector_node/detection          # ≥ 8 Hz（YOLO 推理正常）
rostopic hz /px4ctrl/ext_yaw_rate             # = 20 Hz（偏航指令心跳正常）
rostopic echo /yaw_controller_node/control_active  # 应为 False（尚未使能）
```

### 5.3 检查标注图像（可选，调试用）

```bash
# 在地面站 PC 上（与 Jetson 同网段）
export ROS_MASTER_URI=http://<jetson_ip>:11311
rqt_image_view /detector_node/annotated_image/compressed
```

- [ ] 画面正常，目标无人机在视野内时出现绿框
- [ ] track_id 在连续跟踪时保持稳定（不频繁跳变）
- [ ] error_x 方向正确（目标右移时为正）

---

## 6. 起飞（人工控制阶段）

- [ ] 所有人员退出螺旋桨危险范围（≥ 3 m）
- [ ] **确认摇杆全部居中后**，飞手口头宣布"解锁"后解锁
- [ ] 垂直爬升至 **1.5 m 悬停**，保持 Manual/Stabilize 模式
- [ ] 观察悬停稳定性 ≥ 30 s：无明显漂移，VIO 无跳变
- [ ] 切换到 **Position 模式**，验证位置保持（< 20 cm 漂移/30 s）

> 若 Position 模式不稳定，**不得进入下一步**，降落排查 VIO。

---

## 7. 进入 OFFBOARD + 开启跟踪

### 7.1 切入 OFFBOARD 前确认

OFFBOARD 心跳由 **px4ctrl** 以 100 Hz 发布姿态指令维持，与跟踪系统无关。
切换前只需确认 px4ctrl 正常运行即可。

```bash
# px4ctrl 持续发布姿态指令（OFFBOARD 心跳来源）
rostopic hz /mavros/setpoint_raw/attitude   # 应显示 ~100 Hz
```

- [ ] 目标无人机在视野内且 track_id 稳定
- [ ] px4ctrl 姿态指令心跳正常（上步已确认）
- [ ] **遥控器摇杆居中**

### 7.2 切换 Hover 模式（px4ctrl AUTO_HOVER）

通过遥控器将模式拨杆拨至 Hover 档位：

- [ ] px4ctrl 日志出现 `MANUAL_CTRL(L1) --> AUTO_HOVER(L2)`
- [ ] 飞机继续悬停（不应有明显位移）

> 若日志出现 `Reject AUTO_HOVER ... sticks must be centered`，
> 将所有摇杆回到中位后重试。

### 7.3 切换 PX4 至 OFFBOARD 模式

通过遥控器模式拨杆切至 OFFBOARD，或：

```bash
rosservice call /mavros/set_mode "custom_mode: 'OFFBOARD'"
```

- [ ] `rostopic echo /mavros/state` 中 `mode: OFFBOARD` 出现
- [ ] px4ctrl 日志无报错
- [ ] 飞机继续悬停

### 7.4 使能偏航跟踪

```bash
rosservice call /yaw_controller_node/enable_control "data: true"
```

- [ ] `/yaw_controller_node/control_active` 变为 `True`
- [ ] 飞机开始缓慢转向目标方向
- [ ] 转向速率合理（首飞 kp=0.3 时最大约 15°/s）

### 7.5 飞行中监控

| 指标 | 正常范围 | 异常处理 |
|---|---|---|
| VIO 跳变 | 无 | 立即切 Manual，降落 |
| 偏航振荡 | 无持续振荡 | 关闭跟踪，降低 kp |
| 跟踪 ID 稳定性 | 长时间维持同一 ID | 短暂切换可接受，频繁则降落检查 |
| 电池电压 | ≥ 3.6 V/cell | 低压立即降落 |
| 丢目标后行为 | 0.5 s 内停止偏航指令，px4ctrl 自动维持悬停 | 验证悬停是否稳定 |

---

## 8. 紧急程序

| 情况 | 动作 |
|---|---|
| VIO 位姿跳变 / 飞机漂移 | 立即切 **Manual/Stabilize**，飞手接管降落 |
| 偏航失控（持续转圈） | 切 **Manual**，飞手接管 |
| 跟踪系统崩溃 | px4ctrl 检测到 ext_yaw_rate 超时（0.5 s），自动回退到遥控器偏航控制，无人机继续悬停；OFFBOARD 不受影响 |
| px4ctrl 崩溃 | 姿态指令断流，PX4 OFFBOARD 超时自动退出（~0.5 s），切回上次模式 |
| ROS 节点挂死 | 切 Manual，降落后 `rosnode kill` |
| 电机异响 / 机体抖动 | 立即油门收至最低，切 Manual 降落 |

> **飞手任何时候都可以通过切换遥控器模式接管飞机，无需等待软件响应。**

---

## 9. 降落与飞后

### 9.1 关闭跟踪

```bash
rosservice call /yaw_controller_node/enable_control "data: false"
```

手动切回 Position / Manual 降落，上锁。

### 9.2 飞后数据检查

```bash
rosbag info <bag_file>
rosbag play <bag_file>
rqt_plot /detector_node/detection/error_x
rqt_plot /detector_node/detection/track_id
```

- [ ] error_x 收敛曲线合理（有震荡则下次降低 kp）
- [ ] track_id 稳定段占比 > 80%（否则排查多检测问题）
- [ ] VIO 位姿轨迹无跳变

---

## 10. 参数调优指南

### kp 整定顺序

1. 从 `kp=0.3, yaw_rate_max=0.3` 开始
2. 若响应过慢（目标明显偏离中心但转向很慢）→ 增加 kp 至 0.5
3. 若出现持续振荡 → 降低 kp，或增大 `deadband`
4. 最终目标：`kp=0.8~1.0`，无振荡，响应 1~2 s 内对准

### 速度安全上限

px4ctrl 内置 `max_cmd_vel = 0.5 m/s` 硬限制，即使规划器发出更快的指令也会被截断。
如需修改，编辑 `px4ctrl/config/ctrl_param_fpv.yaml`。

### 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 切 Hover 模式被拒绝 | 摇杆未居中 | 将所有摇杆回中位后重拨 |
| 切 OFFBOARD 立刻退出 | px4ctrl 未运行，姿态指令心跳中断 | 确认 run_ctrl.launch 已启动 |
| 起飞后 Position 模式漂移 | VIO 纹理不足或振动过大 | 增加地面纹理贴纸，检查减振 |
| 偏航方向反转 | 罕见，检查坐标系 | 参见 yaw_controller_node.py 注释 |
| ID 频繁跳变 | 多目标检测竞争 | 已修复（sticky track ID），仍跳则查 annotated_image |
| 检测延迟高 | RViz/rqt_image_view 常开占用带宽 | 调试完成后关闭标注图像订阅 |

---

## 附录：话题速查

| 话题 | 类型 | 用途 |
|---|---|---|
| `/zedm/zed_node/pose` | `PoseStamped` | ZED VIO 原始位姿 |
| `/mavros/odometry/out` | `Odometry` | VIO 桥接输出（送往 PX4 EKF2）|
| `/mavros/state` | `State` | 飞控连接/模式/解锁状态 |
| `/mavros/local_position/odom` | `Odometry` | EKF2 融合后位姿（px4ctrl 使用）|
| `/mavros/setpoint_raw/attitude` | `AttitudeTarget` | px4ctrl 姿态指令（OFFBOARD 心跳来源，100 Hz）|
| `/px4ctrl/ext_yaw_rate` | `TwistStamped` | 偏航指令（yaw_ctrl → px4ctrl，20 Hz）|
| `/detector_node/detection` | `Detection` | 检测结果（cx/cy/error_x/track_id）|
| `/detector_node/annotated_image/compressed` | `CompressedImage` | 标注画面（仅调试用）|
| `/yaw_controller_node/control_active` | `Bool` | 跟踪是否正在输出指令 |
| `/yaw_controller_node/enable_control` | `SetBool` service | 使能/停止跟踪 |
