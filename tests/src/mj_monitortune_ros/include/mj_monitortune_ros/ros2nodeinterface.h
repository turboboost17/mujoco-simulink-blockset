
//
// File ros2nodeinterface.h
//
// Code generated for Simulink model 'mj_monitorTune_ROS'.
//
// Model version                  : 8.28
// Simulink Coder version         : 25.1 (R2025a) 21-Nov-2024
// C/C++ source code generated on : Sun Apr 26 14:47:53 2026
//
#ifndef _ROS2_MATLAB_NODEINTERFACE_
#define _ROS2_MATLAB_NODEINTERFACE_
#ifdef _MSC_VER
#pragma warning(push)
#pragma warning(disable : 4265)
#pragma warning(disable : 4458)
#pragma warning(disable : 4100)
#else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#pragma GCC diagnostic ignored "-Wunused-local-typedefs"
#pragma GCC diagnostic ignored "-Wredundant-decls"
#pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wshadow"
#endif //_MSC_VER
#include "rclcpp/rclcpp.hpp"
namespace rclcpp{
namespace executors{
class SLMultiThreadedExecutor;
}
}
#include "rtwtypes.h"
#include "mj_monitorTune_ROS_types.h"
#include "sensor_msgs/msg/image.hpp"
#include "sensor_msgs/msg/imu.hpp"
extern rclcpp::Node::SharedPtr SLROSNodePtr;
namespace ros2 {
namespace matlab {
  //Semaphore using std::CV and std::mutex
  class Semaphore {
  public:
    std::mutex mMutex;
    std::condition_variable mCV;
    std::atomic_uint mCount;
    //
    Semaphore(int count = 0)
      : mCount(count) {
      }
    //
    inline void notify() {
      std::unique_lock<std::mutex> lock(mMutex);
      mCount++;
      mCV.notify_all();
    }
    //
    inline void wait() {
      std::unique_lock<std::mutex> lock(mMutex);
      while (mCount == 0) {
        mCV.wait(lock);
      }
      if (mCount)
        mCount--;
    }
  };
  //NodeInterface
  class NodeInterface {
    NodeInterface(const NodeInterface& );
    NodeInterface& operator=(const NodeInterface& );
    std::shared_ptr<rclcpp::executors::SLMultiThreadedExecutor> mExec;
    //
    Semaphore mBaseRateSem;
    std::shared_ptr<std::thread> mBaseRateThread;
    rclcpp::TimerBase::SharedPtr mSchedulerTimer;
    rclcpp::CallbackGroup::SharedPtr mSchedulerGroup;
    //
    //
    Semaphore mStopSem;
    volatile boolean_T mRunModel;
  public:
    NodeInterface();
    ~NodeInterface();
    //
    void initialize(int argc, char * const argv[]);
    int run();
    void stop(void);
    void terminate(void);
    //
    boolean_T getStopRequestedFlag(void);
    void schedulerThreadCallback(void);
    void baseRateTask(void);
    //
    rclcpp::Node::SharedPtr getNode() {
      return SLROSNodePtr;
    }
  }; //class NodeInterface
  //
  std::shared_ptr<ros2::matlab::NodeInterface> getNodeInterface();
}//namespace matlab
}//namespace ros2
#ifdef _MSC_VER
#pragma warning(pop)
#else
#pragma GCC diagnostic pop
#endif //_MSC_VER
#endif //_ROS2_MATLAB_ROS2CGEN_MULTIRATE_
