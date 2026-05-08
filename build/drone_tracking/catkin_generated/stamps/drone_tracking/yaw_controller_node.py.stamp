#!/usr/bin/env python3
import threading
import rospy
from geometry_msgs.msg import TwistStamped
from mavros_msgs.msg import State
from std_msgs.msg import Bool
from std_srvs.srv import SetBool, SetBoolResponse
from drone_tracking.msg import Detection


class YawControllerNode:
    def __init__(self):
        rospy.init_node("yaw_controller_node", anonymous=False)

        self.kp               = rospy.get_param("~kp", 1.0)
        self.yaw_rate_max     = rospy.get_param("~yaw_rate_max", 0.8)   # rad/s
        self.deadband         = rospy.get_param("~deadband", 0.01)      # normalized error_x units
        self.stale_sec        = rospy.get_param("~detection_stale_sec", 0.5)
        self.heartbeat_hz     = rospy.get_param("~heartbeat_hz", 20.0)
        self.require_offboard = rospy.get_param("~require_offboard", True)

        self._lock       = threading.Lock()
        self._enabled    = False
        self._state      = State()
        self._latest_det = None
        self._det_time   = rospy.Time(0)

        self.pub_cmd    = rospy.Publisher("/mavros/setpoint_velocity/cmd_vel",
                                          TwistStamped, queue_size=10)
        self.pub_active = rospy.Publisher("~control_active", Bool, queue_size=1)

        rospy.Subscriber("/mavros/state",           State,     self._state_cb,  queue_size=1)
        rospy.Subscriber("/drone_tracking/detection", Detection, self._det_cb,  queue_size=5)

        rospy.Service("~enable_control", SetBool, self._enable_srv)

        rospy.Timer(rospy.Duration(1.0 / self.heartbeat_hz), self._control_loop)

        rospy.loginfo(f"[yaw_ctrl] Ready  Kp={self.kp}  max={self.yaw_rate_max} rad/s  "
                      f"deadband={self.deadband}  heartbeat={self.heartbeat_hz} Hz  "
                      f"require_offboard={self.require_offboard}")

    # ------------------------------------------------------------------
    def _state_cb(self, msg: State):
        with self._lock:
            self._state = msg

    def _det_cb(self, msg: Detection):
        with self._lock:
            self._latest_det = msg
            self._det_time   = rospy.Time.now()

    def _enable_srv(self, req):
        with self._lock:
            self._enabled = req.data
        rospy.loginfo(f"[yaw_ctrl] Control {'ENABLED' if req.data else 'DISABLED'}")
        return SetBoolResponse(success=True,
                               message="enabled" if req.data else "disabled")

    # ------------------------------------------------------------------
    def _control_loop(self, _event):
        """20 Hz timer — always publishes to keep OFFBOARD heartbeat alive."""
        with self._lock:
            enabled    = self._enabled
            mode       = self._state.mode
            det        = self._latest_det
            det_age    = (rospy.Time.now() - self._det_time).to_sec()

        is_offboard = (mode == "OFFBOARD")
        det_fresh   = (det is not None and det.detected and det_age < self.stale_sec)
        do_control  = enabled and (is_offboard or not self.require_offboard) and det_fresh

        yaw_rate = 0.0
        if do_control:
            # error_x > 0 → target right → yaw right
            # ROS/ENU body frame: angular.z < 0 = clockwise = yaw right
            error = det.error_x
            if abs(error) < self.deadband:
                error = 0.0
            raw = -self.kp * error
            yaw_rate = max(-self.yaw_rate_max, min(self.yaw_rate_max, raw))

        cmd = TwistStamped()
        cmd.header.stamp    = rospy.Time.now()
        cmd.header.frame_id = "base_link"
        cmd.twist.angular.z = yaw_rate
        self.pub_cmd.publish(cmd)

        self.pub_active.publish(Bool(data=do_control))

    def spin(self):
        rospy.spin()


if __name__ == "__main__":
    YawControllerNode().spin()
