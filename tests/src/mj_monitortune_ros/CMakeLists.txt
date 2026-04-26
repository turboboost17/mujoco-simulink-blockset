cmake_minimum_required(VERSION 3.5)
project(mj_monitortune_ros)
set(CMAKE_VERBOSE_MAKEFILE ON)
# Set CMAKE_BUILD_TYPE
set(CMAKE_BUILD_TYPE Release)
set(MW_TOP_LEVEL_PROJECT_NAME ${PROJECT_NAME})
# Default to C99
if(NOT CMAKE_C_STANDARD)
  set(CMAKE_C_STANDARD 99)
endif()
# Default to C++17
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()
if(ALIAS_ROS2_TF2)
  add_definitions(-Dtf2=ros2_tf2)
  add_definitions(-Dtf2_ros=ros2_tf2_ros)
  add_definitions(-Dmessage_filters=ros2_message_filters)
endif()
# Check the ROS 2 distribution and define a macro
if("$ENV{ROS_DISTRO}" STREQUAL "humble")
    message(STATUS "Building for ROS 2 Humble")
    add_definitions(-DROS2_DISTRO_HUMBLE)
elseif("$ENV{ROS_DISTRO}" STREQUAL "jazzy")
    message(STATUS "Building for ROS 2 Jazzy")
    add_definitions(-DROS2_DISTRO_JAZZY)
else()
    message(WARNING "ROS 2 distribution $ENV{ROS_DISTRO} is not recommended for this MATLAB version. Use 'ROS 2 Jazzy' for this MATLAB version.")
    message(WARNING "Building for ROS 2 Jazzy")
    add_definitions(-DROS2_DISTRO_JAZZY)
endif()
# find dependencies
find_package(ament_cmake REQUIRED)
find_package(ament_cmake_ros REQUIRED)
find_package( builtin_interfaces REQUIRED)
find_package( rclcpp REQUIRED)
find_package( sensor_msgs REQUIRED)
# Add package include directories
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/include/mj_monitortune_ros")
include_directories("include/mj_monitortune_ros/E/Documents/MATLAB/mujoco-simulink-blockset/lib/linux-aarch64/mujoco/include")
include_directories("include/mj_monitortune_ros/E/Documents/MATLAB/mujoco-simulink-blockset/src")
set (CMAKE_SKIP_BUILD_RPATH false)
set (CMAKE_BUILD_WITH_INSTALL_RPATH true)
set (CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set (CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
add_library(coder_custom_lib_1 UNKNOWN IMPORTED)
set_property(TARGET coder_custom_lib_1 PROPERTY IMPORTED_LOCATION "${PROJECT_SOURCE_DIR}/src/libmujoco.so.3.7.0")
# Node
add_executable(mj_monitorTune_ROS 
src/rt_matrx.c
src/rt_printf.c
src/slros2_multi_threaded_executor.cpp
src/mj.cpp
src/mj_sfun.cpp
src/main.cpp
src/mj_monitorTune_ROS.cpp
src/mj_monitorTune_ROS_data.cpp
src/ros2nodeinterface.cpp
src/rtGetInf.cpp
src/rtGetNaN.cpp
src/rt_nonfinite.cpp
src/slros2_initialize.cpp
)
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
target_compile_options(mj_monitorTune_ROS PUBLIC 
  $<$<OR:$<COMPILE_LANGUAGE:CXX>,$<COMPILE_LANGUAGE:C>>:
  -Wall -Wextra -Wpedantic
  >)
endif()
target_compile_options(mj_monitorTune_ROS PRIVATE
  $<$<OR:$<COMPILE_LANGUAGE:CXX>,$<COMPILE_LANGUAGE:C>>:
  -DMODEL=mj_monitorTune_ROS
  -DNUMST=2
  -DNCSTATES=0
  -DHAVESTDIO
  -DMODEL_HAS_DYNAMICALLY_LOADED_SFCNS=0
  -DCLASSIC_INTERFACE=0
  -DALLOCATIONFCN=0
  -DUSE_RTMODEL
  -DERT
  -DTID01EQ=0
  -DTERMFCN=1
  -DONESTEPFCN=1
  -DMAT_FILE=0
  -DMULTI_INSTANCE_CODE=0
  -DINTEGER_CODE=0
  -DMT=0
  -DROS2_PROJECT
  -DSTACK_SIZE=64
  -D__MW_TARGET_USE_HARDWARE_RESOURCES_H__
  -DRT=RT
  -fpermissive  -O3 -fPIC  >
  )
ament_target_dependencies(
  mj_monitorTune_ROS
  "builtin_interfaces"
  "rclcpp"
  "sensor_msgs"
)
target_include_directories(mj_monitorTune_ROS PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
target_link_libraries(mj_monitorTune_ROS 
    coder_custom_lib_1
    GL glfw
	${CMAKE_DL_LIBS}
    )
install(TARGETS mj_monitorTune_ROS
  EXPORT export_${PROJECT_NAME}
  DESTINATION lib/${PROJECT_NAME})
ament_export_include_directories(
  include
)
foreach(file_i ${CUDA_BINS})
add_custom_command(
                   TARGET mj_monitorTune_ROS
                   POST_BUILD
                   COMMAND ${CMAKE_COMMAND}
                   ARGS -E copy ${PROJECT_SOURCE_DIR}/src/${file_i} ${CMAKE_INSTALL_PREFIX}/mj_monitorTune_ROS_ert_rtw/${file_i}
				   )
add_custom_command(
                   TARGET mj_monitorTune_ROS
                   POST_BUILD
                   COMMAND ${CMAKE_COMMAND}
                   ARGS -E copy ${PROJECT_SOURCE_DIR}/src/${file_i} ${CMAKE_INSTALL_PREFIX}/codegen/exe/mj_monitorTune_ROS/${file_i}
				   )				   
endforeach(file_i)
ament_package()
# Generated on Sun Apr 26 14:47:57 2026
