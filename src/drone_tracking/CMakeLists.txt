cmake_minimum_required(VERSION 3.0.2)
project(drone_tracking)

find_package(catkin REQUIRED COMPONENTS
  rospy
  std_msgs
  sensor_msgs
  geometry_msgs
  visualization_msgs
  cv_bridge
  image_transport
  mavros_msgs
  std_srvs
  message_generation
)

add_message_files(
  FILES
  Detection.msg
)

generate_messages(
  DEPENDENCIES
  std_msgs
)

catkin_package(
  CATKIN_DEPENDS
    message_runtime
    std_msgs sensor_msgs geometry_msgs
    visualization_msgs mavros_msgs std_srvs
)

include_directories(${catkin_INCLUDE_DIRS})

# Python nodes — catkin wraps these with a proper Python shebang
catkin_install_python(PROGRAMS
  scripts/detector_node.py
  scripts/yaw_controller_node.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

# Shell wrappers — must NOT use catkin_install_python (it would wrap them as Python)
install(PROGRAMS
  scripts/run_detector_conda.sh
  scripts/run_yaw_ctrl_conda.sh
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

# Symlink shell wrappers into the devel space so rosrun/roslaunch can find them
foreach(_sh run_detector_conda.sh run_yaw_ctrl_conda.sh)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E create_symlink
      "${CMAKE_CURRENT_SOURCE_DIR}/scripts/${_sh}"
      "${CATKIN_DEVEL_PREFIX}/lib/${PROJECT_NAME}/${_sh}"
  )
endforeach()

install(DIRECTORY launch/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/launch
  FILES_MATCHING PATTERN "*.launch"
)

install(DIRECTORY config/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
  FILES_MATCHING PATTERN "*.yaml"
)

install(DIRECTORY rviz/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/rviz
  FILES_MATCHING PATTERN "*.rviz"
)
