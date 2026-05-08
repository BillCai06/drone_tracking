# 真机实验飞行前检查单

> 适用系统：Jetson + ZED Mini VIO + PX4/MAVROS + YOLOv26n 无人机跟踪
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

---

## 2. VIO 稳定性验证（上电后，地面静止）

VIO 是 OFFBOARD 位置保持的基础，**此步不达标禁止进入 OFFBOARD 模式**。

### 2.1 启动 ZED 节点

```bash
# 机载 Jetson 上
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
# 记录 30 秒静止位姿
rostopic echo /zedm/zed_node/pose | grep -A3 "position"
```

**合格标准**（机体静止放置 30 s）：
- XY 漂移 < 2 cm
- Z 漂移 < 3 cm
- 位姿无突变（无跳变）

> 若漂移超标：检查 ZED 视野内纹理是否丰富（白墙等低纹理区域会导致 VIO 漂移）；
> 确认 IMU 振动隔离；重启 ZED 节点重新初始化。

### 2.4 确认 VIO 已接入飞控

```bash
rostopic hz /mavros/vision_pose/pose    # 必须有数据
rostopic echo /mavros/local_position/pose --once  # 与 VIO 输出一致
```

在 QGroundControl 中确认：
- EKF2 → `EKF2_AID_MASK` 包含 Vision Position
- `ekf2_innovations` 中 `pos_innov` 小且稳定（< 0.05 m）

### 2.5 手持机体缓慢移动测试

手持飞机缓慢移动 1 m 再归位，观察 `/zedm/zed_node/pose`：
- [ ] 位移与实际运动方向一致（方向无反转）
- [ ] 归位后位姿回到初始值附近（< 5 cm 偏差）

---

## 3. MAVROS 与飞控检查

```bash
# 启动 MAVROS（若未随其他 launch 一起启动）
roslaunch mavros px4.launch fcu_url:=/dev/ttyTHS1:921600
```

- [ ] `rostopic echo /mavros/state` 输出 `connected: True`
- [ ] `mode` 初始为 `MANUAL` 或 `STABILIZED`
- [ ] `armed: False`（上电后默认未解锁）
- [ ] QGroundControl 中无红色 Prearm 告警
- [ ] 遥控器 Channel 5（或对应模式通道）可切换 Manual ↔ Altitude ↔ Position 模式
- [ ] **确认遥控器有一个拨杆专用于杀死 OFFBOARD**（切回 Manual 即可接管）

---

## 4. 启动跟踪系统

### 4.1 运行

```bash
# 机载 Jetson 上（新终端）
source /opt/ros/noetic/setup.bash
source /home/zd/tracking_ws/devel/setup.bash
roslaunch drone_tracking drone_tracking.launch
```

可选参数覆盖（首飞强烈建议使用保守参数）：

```bash
roslaunch drone_tracking drone_tracking.launch \
  kp:=0.3 \
  yaw_rate_max:=0.3
```

### 4.2 验证各节点正常

rosservice call /yaw_controller_node/enable_control "data: true"

```bash
# 另开终端
rostopic hz /detector_node/detection   # ≥ 8 Hz（推理正常）
rostopic hz /mavros/setpoint_velocity/cmd_vel         # = 20 Hz（心跳正常）
rostopic echo /yaw_controller_node/control_active  # False（未使能）
```

### 4.3 检查标注图像（可选，调试用）

```bash
# 在地面站 PC 上（与 Jetson 同网段）
export ROS_MASTER_URI=http://<jetson_ip>:11311
rqt_image_view /detector_node/annotated_image/compressed
```

- [ ] 画面正常，无人机在视野内时出现绿框
- [ ] ID 数字在连续跟踪时保持稳定（不快速增长）
- [ ] error_x 显示在 marker 上，方向直觉正确（目标右移时为正）

---

## 5. 起飞（人工控制阶段）

- [ ] 所有人员退出螺旋桨危险范围（≥ 3 m）
- [ ] 飞手口头宣布"解锁"后解锁
- [ ] 垂直爬升至 **1.5 m 悬停**，保持 Manual/Stabilize 模式
- [ ] 观察悬停稳定性 ≥ 30 s：无明显漂移，VIO 无跳变
- [ ] 切换到 **Position 模式**，验证位置保持（< 20 cm 漂移/30 s）

> 若 Position 模式不稳定，**不得进入下一步**，降落排查 VIO。

---

## 6. 进入 OFFBOARD + 开启跟踪

### 6.1 切入 OFFBOARD 前确认

```bash
# 确认 cmd_vel 心跳正常（必须先有 20 Hz 心跳才能切 OFFBOARD）
rostopic hz /mavros/setpoint_velocity/cmd_vel  # 应显示 20.0 Hz
```

- [ ] `yaw_controller_node` 心跳正常（上步已确认）
- [ ] 目标无人机在视野内且 ID 稳定

### 6.2 切换 OFFBOARD

通过遥控器模式拨杆切换至 OFFBOARD，或：

```bash
rosservice call /mavros/set_mode "custom_mode: 'OFFBOARD'"
```

- [ ] `rostopic echo /mavros/state` 中 `mode: OFFBOARD` 出现
- [ ] 飞机继续悬停（不应有明显位移）

### 6.3 使能偏航跟踪

```bash
rosservice call /yaw_controller_node/enable_control "data: true"
```

- [ ] `/yaw_controller_node/control_active` 变为 `True`
- [ ] 飞机开始缓慢转向目标方向
- [ ] 转向速率合理（首飞 kp=0.3 时最大约 15°/s）

### 6.4 飞行中监控

持续观察以下指标：

| 指标 | 正常范围 | 异常处理 |
|---|---|---|
| VIO 跳变 | 无 | 立即切 Manual，降落 |
| 偏航振荡 | 无持续振荡 | 关闭跟踪，降低 kp |
| 跟踪 ID 稳定性 | 长时间维持同一 ID | 可接受短暂切换，频繁则降落检查 |
| 电池电压 | ≥ 3.6 V/cell | 低压立即降落 |
| `detection_stale` | 丢目标后 ≤ 0.5 s 恢复悬停 | 正常，验证悬停是否稳定 |

---

## 7. 紧急程序

| 情况 | 动作 |
|---|---|
| VIO 位姿跳变 / 飞机漂移 | 立即切 **Manual/Stabilize**，飞手接管降落 |
| 偏航失控（持续转圈） | 切 **Manual**，飞手接管 |
| 跟踪系统崩溃 | `cmd_vel` 断流，PX4 OFFBOARD 超时自动切回 Position（默认 0.5 s） |
| ROS 节点挂死 | 切 Manual，降落后 `rosnode kill` |
| 电机异响 / 机体抖动 | 立即油门收至最低，切 Manual 降落 |

> **飞手任何时候都可以通过切换遥控器模式接管飞机，无需等待软件响应。**

---

## 8. 降落与飞后

### 8.1 关闭跟踪

```bash
rosservice call /yaw_controller_node/enable_control "data: false"
```

手动切回 Position / Manual 降落，上锁。

### 8.2 飞后数据检查

```bash
# 回放 detection 日志（若有 rosbag）
rosbag info <bag_file>
rosbag play <bag_file>
rqt_plot /detector_node/detection/error_x
rqt_plot /detector_node/detection/track_id
```

- [ ] error_x 收敛曲线合理（有震荡则下次降低 kp）
- [ ] track_id 稳定段占比 > 80%（否则排查多检测问题）
- [ ] VIO 位姿轨迹无跳变

---

## 9. 参数调优指南

### kp 整定顺序

1. 从 `kp=0.3, yaw_rate_max=0.3` 开始
2. 若响应过慢（目标明显偏离中心但转向很慢）→ 增加 kp 至 0.5
3. 若出现持续振荡 → 降低 kp，或增大 `deadband`
4. 最终目标：`kp=0.8~1.0`，无振荡，响应 1~2 s 内对准

### 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 起飞后 Position 模式漂移 | VIO 纹理不足或振动过大 | 增加地面纹理贴纸，检查减振 |
| 切 OFFBOARD 立刻退出 | `cmd_vel` 心跳不足 10 Hz | 检查节点是否正常运行 |
| 偏航方向反转 | 罕见，检查 MAVROS 坐标系 | 参见 yaw_controller_node.py 注释 |
| ID 频繁跳变 | 多目标检测竞争 | 已修复（sticky track ID），仍跳则查 annotated_image |
| 检测延迟高 | GPU 占用，annotated_image 无人订阅时仍发布 | 确认 RViz 未常开 |

---

## 附录：话题速查

| 话题 | 类型 | 用途 |
|---|---|---|
| `/zedm/zed_node/pose` | `PoseStamped` | VIO 原始位姿 |
| `/mavros/state` | `State` | 飞控连接/模式/解锁状态 |
| `/mavros/local_position/pose` | `PoseStamped` | 飞控融合后位姿 |
| `/mavros/setpoint_velocity/cmd_vel` | `TwistStamped` | 偏航指令（本系统输出）|
| `/detector_node/detection` | `Detection` | 检测结果（cx/cy/error_x/track_id）|
| `/detector_node/annotated_image/compressed` | `CompressedImage` | 标注画面（仅调试用，无订阅时不发布）|
| `/yaw_controller_node/control_active` | `Bool` | 跟踪是否正在输出指令 |
| `/yaw_controller_node/enable_control` | `SetBool` service | 使能/停止跟踪 |
