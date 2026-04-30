cmake_minimum_required(VERSION 3.15)

project(lego_sdf LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(LEGO_SDF_BUILD_SMOKE "Build a small native loader smoke executable" ON)
option(LEGO_SDF_BUILD_STABILITY "Build a native settling/stability metric executable" ON)

if(NOT DEFINED MUJOCO_ROOT OR "${MUJOCO_ROOT}" STREQUAL "")
  message(FATAL_ERROR "Set MUJOCO_ROOT to the MuJoCo runtime root, for example .../lib/win64/mujoco")
endif()

file(TO_CMAKE_PATH "${MUJOCO_ROOT}" MUJOCO_ROOT_CMAKE)

add_library(lego_sdf SHARED
  lego_brick.cc
  register.cc
)

target_include_directories(lego_sdf PRIVATE
  "${MUJOCO_ROOT_CMAKE}/include"
)

if(WIN32)
  target_link_libraries(lego_sdf PRIVATE "${MUJOCO_ROOT_CMAKE}/lib/mujoco.lib")
  set_target_properties(lego_sdf PROPERTIES PREFIX "")
else()
  target_link_directories(lego_sdf PRIVATE "${MUJOCO_ROOT_CMAKE}/lib")
  target_link_libraries(lego_sdf PRIVATE mujoco)
endif()

if(LEGO_SDF_BUILD_SMOKE)
  add_executable(lego_sdf_smoke smoke_main.cc)
  target_include_directories(lego_sdf_smoke PRIVATE
    "${MUJOCO_ROOT_CMAKE}/include"
  )
  if(WIN32)
    target_link_libraries(lego_sdf_smoke PRIVATE "${MUJOCO_ROOT_CMAKE}/lib/mujoco.lib")
  else()
    target_link_directories(lego_sdf_smoke PRIVATE "${MUJOCO_ROOT_CMAKE}/lib")
    target_link_libraries(lego_sdf_smoke PRIVATE mujoco)
  endif()
endif()

if(LEGO_SDF_BUILD_STABILITY)
  add_executable(lego_sdf_stability stability_main.cc)
  target_include_directories(lego_sdf_stability PRIVATE
    "${MUJOCO_ROOT_CMAKE}/include"
  )
  if(WIN32)
    target_link_libraries(lego_sdf_stability PRIVATE "${MUJOCO_ROOT_CMAKE}/lib/mujoco.lib")
  else()
    target_link_directories(lego_sdf_stability PRIVATE "${MUJOCO_ROOT_CMAKE}/lib")
    target_link_libraries(lego_sdf_stability PRIVATE mujoco)
  endif()
endif()