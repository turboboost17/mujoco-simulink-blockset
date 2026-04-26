// Copyright 2022-2024 The MathWorks, Inc.
// Generated 26-Apr-2026 14:47:53
#ifndef _SLROS2_INITIALIZE_H_
#define _SLROS2_INITIALIZE_H_
#include "mj_monitorTune_ROS_types.h"
// Generic pub-sub header
#include "slros2_generic_pubsub.h"
#include "slros2_time.h"
#ifndef SET_QOS_VALUES
#define SET_QOS_VALUES(qosStruct, _history, _depth, _durability, _reliability, _deadline \
, _lifespan, _liveliness, _lease_duration, _avoid_ros_namespace_conventions)             \
    {                                                                                    \
        qosStruct.history = _history;                                                    \
        qosStruct.depth = _depth;                                                        \
        qosStruct.durability = _durability;                                              \
        qosStruct.reliability = _reliability;                                            \
        qosStruct.deadline.sec = _deadline.sec;                                          \
        qosStruct.deadline.nsec = _deadline.nsec;                                        \
        qosStruct.lifespan.sec = _lifespan.sec;                                          \
        qosStruct.lifespan.nsec = _lifespan.nsec;                                        \
        qosStruct.liveliness = _liveliness;                                              \
        qosStruct.liveliness_lease_duration.sec = _lease_duration.sec;                   \
        qosStruct.liveliness_lease_duration.nsec = _lease_duration.nsec;                 \
        qosStruct.avoid_ros_namespace_conventions = _avoid_ros_namespace_conventions;    \
    }
#endif
inline rclcpp::QoS getQOSSettingsFromRMW(const rmw_qos_profile_t& qosProfile) {
    rclcpp::QoS qos(rclcpp::QoSInitialization::from_rmw(qosProfile));
    if (RMW_QOS_POLICY_DURABILITY_TRANSIENT_LOCAL == qosProfile.durability) {
        qos.transient_local();
    } else {
        qos.durability_volatile();
    }
    if (RMW_QOS_POLICY_RELIABILITY_RELIABLE == qosProfile.reliability) {
        qos.reliable();
    } else {
        qos.best_effort();
    }
    return qos;
}
// mj_monitorTune_ROS/Publish
extern SimulinkPublisher<sensor_msgs::msg::Imu,SL_Bus_sensor_msgs_Imu> Pub_mj_monitorTune_ROS_136;
// mj_monitorTune_ROS/Publish1
extern SimulinkPublisher<sensor_msgs::msg::Image,SL_Bus_sensor_msgs_Image> Pub_mj_monitorTune_ROS_143;
#endif
