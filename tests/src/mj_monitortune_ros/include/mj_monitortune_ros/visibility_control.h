#ifndef MJ_MONITORTUNE_ROS__VISIBILITY_CONTROL_H_
#define MJ_MONITORTUNE_ROS__VISIBILITY_CONTROL_H_
#if defined _WIN32 || defined __CYGWIN__
  #ifdef __GNUC__
    #define MJ_MONITORTUNE_ROS_EXPORT __attribute__ ((dllexport))
    #define MJ_MONITORTUNE_ROS_IMPORT __attribute__ ((dllimport))
  #else
    #define MJ_MONITORTUNE_ROS_EXPORT __declspec(dllexport)
    #define MJ_MONITORTUNE_ROS_IMPORT __declspec(dllimport)
  #endif
  #ifdef MJ_MONITORTUNE_ROS_BUILDING_LIBRARY
    #define MJ_MONITORTUNE_ROS_PUBLIC MJ_MONITORTUNE_ROS_EXPORT
  #else
    #define MJ_MONITORTUNE_ROS_PUBLIC MJ_MONITORTUNE_ROS_IMPORT
  #endif
  #define MJ_MONITORTUNE_ROS_PUBLIC_TYPE MJ_MONITORTUNE_ROS_PUBLIC
  #define MJ_MONITORTUNE_ROS_LOCAL
#else
  #define MJ_MONITORTUNE_ROS_EXPORT __attribute__ ((visibility("default")))
  #define MJ_MONITORTUNE_ROS_IMPORT
  #if __GNUC__ >= 4
    #define MJ_MONITORTUNE_ROS_PUBLIC __attribute__ ((visibility("default")))
    #define MJ_MONITORTUNE_ROS_LOCAL  __attribute__ ((visibility("hidden")))
  #else
    #define MJ_MONITORTUNE_ROS_PUBLIC
    #define MJ_MONITORTUNE_ROS_LOCAL
  #endif
  #define MJ_MONITORTUNE_ROS_PUBLIC_TYPE
#endif
#endif  // MJ_MONITORTUNE_ROS__VISIBILITY_CONTROL_H_
// Generated 26-Apr-2026 14:47:57
 