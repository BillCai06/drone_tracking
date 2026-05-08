;; Auto-generated. Do not edit!


(when (boundp 'drone_tracking::Detection)
  (if (not (find-package "DRONE_TRACKING"))
    (make-package "DRONE_TRACKING"))
  (shadow 'Detection (find-package "DRONE_TRACKING")))
(unless (find-package "DRONE_TRACKING::DETECTION")
  (make-package "DRONE_TRACKING::DETECTION"))

(in-package "ROS")
;;//! \htmlinclude Detection.msg.html
(if (not (find-package "STD_MSGS"))
  (ros::roseus-add-msgs "std_msgs"))


(defclass drone_tracking::Detection
  :super ros::object
  :slots (_header _detected _cx _cy _width _height _conf _track_id _error_x ))

(defmethod drone_tracking::Detection
  (:init
   (&key
    ((:header __header) (instance std_msgs::Header :init))
    ((:detected __detected) nil)
    ((:cx __cx) 0.0)
    ((:cy __cy) 0.0)
    ((:width __width) 0.0)
    ((:height __height) 0.0)
    ((:conf __conf) 0.0)
    ((:track_id __track_id) 0)
    ((:error_x __error_x) 0.0)
    )
   (send-super :init)
   (setq _header __header)
   (setq _detected __detected)
   (setq _cx (float __cx))
   (setq _cy (float __cy))
   (setq _width (float __width))
   (setq _height (float __height))
   (setq _conf (float __conf))
   (setq _track_id (round __track_id))
   (setq _error_x (float __error_x))
   self)
  (:header
   (&rest __header)
   (if (keywordp (car __header))
       (send* _header __header)
     (progn
       (if __header (setq _header (car __header)))
       _header)))
  (:detected
   (&optional (__detected :null))
   (if (not (eq __detected :null)) (setq _detected __detected)) _detected)
  (:cx
   (&optional __cx)
   (if __cx (setq _cx __cx)) _cx)
  (:cy
   (&optional __cy)
   (if __cy (setq _cy __cy)) _cy)
  (:width
   (&optional __width)
   (if __width (setq _width __width)) _width)
  (:height
   (&optional __height)
   (if __height (setq _height __height)) _height)
  (:conf
   (&optional __conf)
   (if __conf (setq _conf __conf)) _conf)
  (:track_id
   (&optional __track_id)
   (if __track_id (setq _track_id __track_id)) _track_id)
  (:error_x
   (&optional __error_x)
   (if __error_x (setq _error_x __error_x)) _error_x)
  (:serialization-length
   ()
   (+
    ;; std_msgs/Header _header
    (send _header :serialization-length)
    ;; bool _detected
    1
    ;; float32 _cx
    4
    ;; float32 _cy
    4
    ;; float32 _width
    4
    ;; float32 _height
    4
    ;; float32 _conf
    4
    ;; int32 _track_id
    4
    ;; float32 _error_x
    4
    ))
  (:serialize
   (&optional strm)
   (let ((s (if strm strm
              (make-string-output-stream (send self :serialization-length)))))
     ;; std_msgs/Header _header
       (send _header :serialize s)
     ;; bool _detected
       (if _detected (write-byte -1 s) (write-byte 0 s))
     ;; float32 _cx
       (sys::poke _cx (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;; float32 _cy
       (sys::poke _cy (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;; float32 _width
       (sys::poke _width (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;; float32 _height
       (sys::poke _height (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;; float32 _conf
       (sys::poke _conf (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;; int32 _track_id
       (write-long _track_id s)
     ;; float32 _error_x
       (sys::poke _error_x (send s :buffer) (send s :count) :float) (incf (stream-count s) 4)
     ;;
     (if (null strm) (get-output-stream-string s))))
  (:deserialize
   (buf &optional (ptr- 0))
   ;; std_msgs/Header _header
     (send _header :deserialize buf ptr-) (incf ptr- (send _header :serialization-length))
   ;; bool _detected
     (setq _detected (not (= 0 (sys::peek buf ptr- :char)))) (incf ptr- 1)
   ;; float32 _cx
     (setq _cx (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;; float32 _cy
     (setq _cy (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;; float32 _width
     (setq _width (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;; float32 _height
     (setq _height (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;; float32 _conf
     (setq _conf (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;; int32 _track_id
     (setq _track_id (sys::peek buf ptr- :integer)) (incf ptr- 4)
   ;; float32 _error_x
     (setq _error_x (sys::peek buf ptr- :float)) (incf ptr- 4)
   ;;
   self)
  )

(setf (get drone_tracking::Detection :md5sum-) "3596dd143859f8f7cb18a2f97daa2146")
(setf (get drone_tracking::Detection :datatype-) "drone_tracking/Detection")
(setf (get drone_tracking::Detection :definition-)
      "std_msgs/Header header
bool    detected
float32 cx
float32 cy
float32 width
float32 height
float32 conf
int32   track_id
float32 error_x

================================================================================
MSG: std_msgs/Header
# Standard metadata for higher-level stamped data types.
# This is generally used to communicate timestamped data 
# in a particular coordinate frame.
# 
# sequence ID: consecutively increasing ID 
uint32 seq
#Two-integer timestamp that is expressed as:
# * stamp.sec: seconds (stamp_secs) since epoch (in Python the variable is called 'secs')
# * stamp.nsec: nanoseconds since stamp_secs (in Python the variable is called 'nsecs')
# time-handling sugar is provided by the client library
time stamp
#Frame this data is associated with
string frame_id

")



(provide :drone_tracking/Detection "3596dd143859f8f7cb18a2f97daa2146")


