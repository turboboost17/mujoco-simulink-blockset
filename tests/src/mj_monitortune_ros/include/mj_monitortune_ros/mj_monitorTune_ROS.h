//
//  mj_monitorTune_ROS.h
//
//  Code generation for model "mj_monitorTune_ROS".
//
//  Model version              : 8.28
//  Simulink Coder version : 25.1 (R2025a) 21-Nov-2024
//  C++ source code generated on : Sun Apr 26 04:42:39 2026
//
//  Target selection: ert.tlc
//  Embedded hardware selection: ARM Compatible->ARM Cortex-A (64-bit)
//  Code generation objectives: Unspecified
//  Validation result: Not run


#ifndef mj_monitorTune_ROS_h_
#define mj_monitorTune_ROS_h_
#include "rtwtypes.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "slros2_initialize.h"
#include "mj_monitorTune_ROS_types.h"
#include <stddef.h>
#include <string.h>

extern "C"
{

#include "rt_nonfinite.h"

}

// Block signals (default storage)
struct B_mj_monitorTune_ROS_T {
  real32_T SFunction_o3[1228801];      // '<S3>/S-Function'
  uint8_T SFunction_o2[3686401];       // '<S3>/S-Function'
  uint8_T SFunction_o4[3686401];       // '<S3>/S-Function'
  SL_Bus_sensor_msgs_Image HeaderAssign;// '<S2>/HeaderAssign'
  uint8_T PermuteDimensions[921600];   // '<S4>/Permute Dimensions'
  uint8_T image[921600];
  uint8_T Data1[921600];
  SL_Bus_sensor_msgs_Imu BusAssignment_i;// '<Root>/Bus Assignment'
  char_T Switch1[256];                 // '<S2>/Switch1'
  real_T SFunction_o1[5];              // '<S3>/S-Function'
  sJ4ih70VmKcvCeguWN0mNVF deadline;
  sJ4ih70VmKcvCeguWN0mNVF deadline_m;
  real_T Constant1;                    // '<Root>/Constant1'
  real_T Constant;                     // '<S9>/Constant'
};

// Block states (default storage) for system '<Root>'
struct DW_mj_monitorTune_ROS_T {
  ros_slros2_internal_block_Cur_T obj; // '<S2>/Current Time'
  ros_slros2_internal_block_Pub_T obj_i;// '<S6>/SinkBlock'
  ros_slros2_internal_block_Pub_T obj_o;// '<S5>/SinkBlock'
  int_T SFunction_IWORK[2];            // '<S3>/S-Function'
};

// Parameters (default storage)
struct P_mj_monitorTune_ROS_T_ {
  SL_Bus_sensor_msgs_Image Constant_Value;// Computed Parameter: Constant_Value
                                             //  Referenced by: '<S11>/Constant'

  SL_Bus_sensor_msgs_Imu Constant_Value_g;// Computed Parameter: Constant_Value_g
                                             //  Referenced by: '<S1>/Constant'

  mj_bus_sensor_15738467249377022003 blankSensorBus_Value;
                                     // Computed Parameter: blankSensorBus_Value
                                        //  Referenced by: '<S8>/blankSensorBus'

  real_T Constant1_Value;              // Expression: SetFrameID
                                          //  Referenced by: '<S2>/Constant1'

  real_T Constant_Value_f;             // Expression: InsertTimeStamp
                                          //  Referenced by: '<S2>/Constant'

  real_T SFunction_P1_Size[2];         // Computed Parameter: SFunction_P1_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P1[61];             // Computed Parameter: SFunction_P1
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P2_Size[2];         // Computed Parameter: SFunction_P2_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P2[5];              // Computed Parameter: SFunction_P2
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P3_Size[2];         // Computed Parameter: SFunction_P3_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P3;                 // Expression: controlLength
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P4_Size[2];         // Computed Parameter: SFunction_P4_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P4;                 // Expression: sensorLength
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P5_Size[2];         // Computed Parameter: SFunction_P5_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P5;                 // Expression: rgbLength
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P6_Size[2];         // Computed Parameter: SFunction_P6_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P6;                 // Expression: depthLength
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P7_Size[2];         // Computed Parameter: SFunction_P7_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P7;                 // Expression: vsync
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P8_Size[2];         // Computed Parameter: SFunction_P8_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P8;                 // Expression: visualFPS
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P9_Size[2];         // Computed Parameter: SFunction_P9_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P9;                 // Expression: cameraSampleTime
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P10_Size[2];        // Computed Parameter: SFunction_P10_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P10;                // Expression: sampleTime
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P11_Size[2];        // Computed Parameter: SFunction_P11_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P11;                // Expression: zoomLevel
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P12_Size[2];        // Computed Parameter: SFunction_P12_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P12[4];             // Computed Parameter: SFunction_P12
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P13_Size[2];        // Computed Parameter: SFunction_P13_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P13;                // Expression: rgbOutOption
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P14_Size[2];        // Computed Parameter: SFunction_P14_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P14;                // Expression: depthOutOption
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P15_Size[2];        // Computed Parameter: SFunction_P15_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P15;                // Expression: segmentationOutOption
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P16_Size[2];        // Computed Parameter: SFunction_P16_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P16[2];             // Expression: camWidth
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P17_Size[2];        // Computed Parameter: SFunction_P17_Size
                                          //  Referenced by: '<S3>/S-Function'

  real_T SFunction_P17[2];             // Expression: camHeight
                                          //  Referenced by: '<S3>/S-Function'

  real_T Constant1_Value_j;            // Expression: 0.25
                                          //  Referenced by: '<Root>/Constant1'

  real_T Constant_Value_e;             // Expression: 0
                                          //  Referenced by: '<S9>/Constant'

  char_T StringConstant1_String[256];  // Expression: FrameID
                                          //  Referenced by: '<S2>/String Constant1'

};

// Real-time Model Data Structure
struct tag_RTM_mj_monitorTune_ROS_T {
  struct SimStruct_tag * *childSfunctions;
  const char_T *errorStatus;
  SS_SimMode simMode;
  RTWSolverInfo solverInfo;
  RTWSolverInfo *solverInfoPtr;
  void *sfcnInfo;

  //
  //  NonInlinedSFcns:
  //  The following substructure contains information regarding
  //  non-inlined s-functions used in the model.

  struct {
    RTWSfcnInfo sfcnInfo;
    time_T *taskTimePtrs[2];
    SimStruct childSFunctions[1];
    SimStruct *childSFunctionPtrs[1];
    struct _ssBlkInfo2 blkInfo2[1];
    struct _ssSFcnModelMethods2 methods2[1];
    struct _ssSFcnModelMethods3 methods3[1];
    struct _ssSFcnModelMethods4 methods4[1];
    struct _ssStatesInfo2 statesInfo2[1];
    ssPeriodicStatesInfo periodicStatesInfo[1];
    struct _ssPortInfo2 inputOutputPortInfo2[1];
    struct {
      time_T sfcnPeriod[1];
      time_T sfcnOffset[1];
      int_T sfcnTsMap[1];
      struct _ssPortInputs inputPortInfo[1];
      struct _ssInPortUnit inputPortUnits[1];
      struct _ssInPortCoSimAttribute inputPortCoSimAttribute[1];
      real_T const *UPtrs0[2];
      struct _ssPortOutputs outputPortInfo[4];
      struct _ssOutPortUnit outputPortUnits[4];
      struct _ssOutPortCoSimAttribute outputPortCoSimAttribute[4];
      uint_T attribs[17];
      mxArray *params[17];
      struct _ssDWorkRecord dWork[1];
      struct _ssDWorkAuxRecord dWorkAux[1];
    } Sfcn0;
  } NonInlinedSFcns;

  boolean_T zCCacheNeedsReset;
  boolean_T derivCacheNeedsReset;
  boolean_T CTOutputIncnstWithState;

  //
  //  Sizes:
  //  The following substructure contains sizes information
  //  for many of the model attributes such as inputs, outputs,
  //  dwork, sample times, etc.

  struct {
    uint32_T options;
    int_T numContStates;
    int_T numU;
    int_T numY;
    int_T numSampTimes;
    int_T numBlocks;
    int_T numBlockIO;
    int_T numBlockPrms;
    int_T numDwork;
    int_T numSFcnPrms;
    int_T numSFcns;
    int_T numIports;
    int_T numOports;
    int_T numNonSampZCs;
    int_T sysDirFeedThru;
    int_T rtwGenSfcn;
  } Sizes;

  //
  //  Timing:
  //  The following substructure contains information regarding
  //  the timing information for the model.

  struct {
    time_T stepSize;
    uint32_T clockTick0;
    time_T stepSize0;
    struct {
      uint8_T TID[2];
    } TaskCounters;

    time_T tStart;
    time_T tFinal;
    time_T timeOfLastOutput;
    boolean_T stopRequestedFlag;
    time_T *sampleTimes;
    time_T *offsetTimes;
    int_T *sampleTimeTaskIDPtr;
    int_T *sampleHits;
    int_T *perTaskSampleHits;
    time_T *t;
    time_T sampleTimesArray[2];
    time_T offsetTimesArray[2];
    int_T sampleTimeTaskIDArray[2];
    int_T sampleHitArray[2];
    int_T perTaskSampleHitsArray[4];
    time_T tArray[2];
  } Timing;

  boolean_T getStopRequested() const;
  void setStopRequested(boolean_T aStopRequested);
  boolean_T getDerivCacheNeedsReset() const;
  void setDerivCacheNeedsReset(boolean_T aDerivCacheNeedsReset);
  const char_T* getErrorStatus() const;
  void setErrorStatus(const char_T* const aErrorStatus);
  boolean_T getContTimeOutputInconsistentWithStateAtMajorStepFlag() const;
  void setContTimeOutputInconsistentWithStateAtMajorStepFlag(boolean_T
    aContTimeOutputInconsistentWithStateAtMajorStepFlag);
  const char_T** getErrorStatusPtr();
  time_T getStepSize() const;
  time_T getFinalTime() const;
  const int_T* getSampleHitArray() const;
  boolean_T* getStopRequestedPtr();
  time_T getTFinal() const;
  void setTFinal(time_T aTFinal);
  time_T* getTFinalPtr();
  time_T* getTPtr() const;
  void setTPtr(time_T* aTPtr);
  time_T** getTPtrPtr();
  time_T getTStart() const;
  time_T* getTStartPtr();
  time_T getTimeOfLastOutput() const;
  time_T* getTimeOfLastOutputPtr();
  boolean_T getZCCacheNeedsReset() const;
  void setZCCacheNeedsReset(boolean_T aZCCacheNeedsReset);
  time_T get_TimeOfLastOutput() const;
};

// Block parameters (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern P_mj_monitorTune_ROS_T mj_monitorTune_ROS_P;

#ifdef __cplusplus

}

#endif

// Block signals (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern struct B_mj_monitorTune_ROS_T mj_monitorTune_ROS_B;

#ifdef __cplusplus

}

#endif

// Block states (default storage)
extern struct DW_mj_monitorTune_ROS_T mj_monitorTune_ROS_DW;

#ifdef __cplusplus

extern "C"
{

#endif

  // Model entry point functions
  extern void mj_monitorTune_ROS_initialize(void);
  extern void mj_monitorTune_ROS_step(void);
  extern void mj_monitorTune_ROS_terminate(void);

#ifdef __cplusplus

}

#endif

// Real-time Model object
#ifdef __cplusplus

extern "C"
{

#endif

  extern RT_MODEL_mj_monitorTune_ROS_T *const mj_monitorTune_ROS_M;

#ifdef __cplusplus

}

#endif

extern volatile boolean_T stopRequested;
extern volatile boolean_T runModel;

//-
//  These blocks were eliminated from the model due to optimizations:
//
//  Block '<Root>/Display' : Unused code path elimination
//  Block '<S3>/Rate Transition1' : Unused code path elimination
//  Block '<S3>/Rate Transition3' : Unused code path elimination
//  Block '<S4>/Reshape' : Reshape block reduction


//-
//  The generated code includes comments that allow you to trace directly
//  back to the appropriate location in the model.  The basic format
//  is <system>/block_name, where system is the system number (uniquely
//  assigned by Simulink) and block_name is the name of the block.
//
//  Use the MATLAB hilite_system command to trace the generated code back
//  to the model.  For example,
//
//  hilite_system('<S3>')    - opens system 3
//  hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
//
//  Here is the system hierarchy for this model
//
//  '<Root>' : 'mj_monitorTune_ROS'
//  '<S1>'   : 'mj_monitorTune_ROS/Blank Message'
//  '<S2>'   : 'mj_monitorTune_ROS/Header Assignment'
//  '<S3>'   : 'mj_monitorTune_ROS/MuJoCo Plant'
//  '<S4>'   : 'mj_monitorTune_ROS/MuJoCo RGB Parser'
//  '<S5>'   : 'mj_monitorTune_ROS/Publish'
//  '<S6>'   : 'mj_monitorTune_ROS/Publish1'
//  '<S7>'   : 'mj_monitorTune_ROS/Write Image'
//  '<S8>'   : 'mj_monitorTune_ROS/MuJoCo Plant/sensorToBus'
//  '<S9>'   : 'mj_monitorTune_ROS/MuJoCo Plant/uPortExpander'
//  '<S10>'  : 'mj_monitorTune_ROS/MuJoCo RGB Parser/image flip fcn'
//  '<S11>'  : 'mj_monitorTune_ROS/Write Image/Blank Message'
//  '<S12>'  : 'mj_monitorTune_ROS/Write Image/MATLAB Function'

#endif                                 // mj_monitorTune_ROS_h_
