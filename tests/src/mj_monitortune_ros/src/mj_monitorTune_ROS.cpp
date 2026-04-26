//
//  mj_monitorTune_ROS.cpp
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


#include "mj_monitorTune_ROS.h"
#include "mj_monitorTune_ROS_types.h"
#include "rtwtypes.h"
#include <string.h>
#include "rmw/qos_profiles.h"
#include <stddef.h>
#include "mj_monitorTune_ROS_private.h"

extern "C"
{

#include "rt_nonfinite.h"

}

// Block signals (default storage)
B_mj_monitorTune_ROS_T mj_monitorTune_ROS_B;

// Block states (default storage)
DW_mj_monitorTune_ROS_T mj_monitorTune_ROS_DW;

// Real-time model
RT_MODEL_mj_monitorTune_ROS_T mj_monitorTune_ROS_M_ =
  RT_MODEL_mj_monitorTune_ROS_T();
RT_MODEL_mj_monitorTune_ROS_T *const mj_monitorTune_ROS_M =
  &mj_monitorTune_ROS_M_;

// Forward declaration for local functions
static void mj_monit_ImageWriter_writeImage(const uint8_T img[921600], uint8_T
  data[921600]);
static void mj_monitorTu_WriteImageFcnBlock(const uint8_T image[921600], uint8_T
  Data[940000], uint8_T Encoding[128]);
static void mj_monitorT_Publisher_setupImpl(const
  ros_slros2_internal_block_Pub_T *obj);
static void mj_monito_Publisher_setupImpl_l(const
  ros_slros2_internal_block_Pub_T *obj);
static void rate_scheduler(void);

//
//         This function updates active task flag for each subrate.
//         The function is called at model base rate, hence the
//         generated code self-manages all its subrates.
//
static void rate_scheduler(void)
{
  // Compute which subrates run during the next base time step.  Subrates
  //  are an integer multiple of the base rate counter.  Therefore, the subtask
  //  counter is reset when it reaches its limit (zero means run).

  (mj_monitorTune_ROS_M->Timing.TaskCounters.TID[1])++;
  if ((mj_monitorTune_ROS_M->Timing.TaskCounters.TID[1]) > 1) {// Sample time: [0.2s, 0.0s] 
    mj_monitorTune_ROS_M->Timing.TaskCounters.TID[1] = 0;
  }

  mj_monitorTune_ROS_M->Timing.sampleHits[1] =
    (mj_monitorTune_ROS_M->Timing.TaskCounters.TID[1] == 0) ? 1 : 0;
}

// Function for MATLAB Function: '<S7>/MATLAB Function'
static void mj_monit_ImageWriter_writeImage(const uint8_T img[921600], uint8_T
  data[921600])
{
  for (int32_T k = 0; k < 3; k++) {
    for (int32_T b_k = 0; b_k < 640; b_k++) {
      for (int32_T c_k = 0; c_k < 480; c_k++) {
        mj_monitorTune_ROS_B.image[(k + 3 * b_k) + 1920 * c_k] = img[(b_k * 480
          + c_k) + k * 307200];
      }
    }
  }

  memcpy((void *)&data[0], (void *)&mj_monitorTune_ROS_B.image[0], (uint32_T)
         ((size_t)921600 * sizeof(uint8_T)));
}

// Function for MATLAB Function: '<S7>/MATLAB Function'
static void mj_monitorTu_WriteImageFcnBlock(const uint8_T image[921600], uint8_T
  Data[940000], uint8_T Encoding[128])
{
  memset(&Encoding[0], 0, sizeof(uint8_T) << 7U);
  Encoding[0] = 114U;
  Encoding[1] = 103U;
  Encoding[2] = 98U;
  Encoding[3] = 56U;
  mj_monit_ImageWriter_writeImage(image, mj_monitorTune_ROS_B.Data1);
  memcpy(&Data[0], &mj_monitorTune_ROS_B.Data1[0], 921600U * sizeof(uint8_T));
}

static void mj_monitorT_Publisher_setupImpl(const
  ros_slros2_internal_block_Pub_T *obj)
{
  rmw_qos_profile_t qos_profile;
  sJ4ih70VmKcvCeguWN0mNVF lifespan;
  sJ4ih70VmKcvCeguWN0mNVF liveliness_lease_duration;
  char_T b_zeroDelimTopic[9];
  static const char_T b_zeroDelimTopic_0[9] = "/arm_imu";
  qos_profile = rmw_qos_profile_default;

  // Start for MATLABSystem: '<S5>/SinkBlock'
  mj_monitorTune_ROS_B.deadline_m.sec = 0.0;
  mj_monitorTune_ROS_B.deadline_m.nsec = 0.0;
  lifespan.sec = 0.0;
  lifespan.nsec = 0.0;
  liveliness_lease_duration.sec = 0.0;
  liveliness_lease_duration.nsec = 0.0;
  SET_QOS_VALUES(qos_profile, RMW_QOS_POLICY_HISTORY_KEEP_LAST, (size_t)2.0,
                 RMW_QOS_POLICY_DURABILITY_VOLATILE,
                 RMW_QOS_POLICY_RELIABILITY_RELIABLE,
                 mj_monitorTune_ROS_B.deadline_m, lifespan,
                 RMW_QOS_POLICY_LIVELINESS_AUTOMATIC, liveliness_lease_duration,
                 (bool)obj->QOSAvoidROSNamespaceConventions);
  for (int32_T i = 0; i < 9; i++) {
    // Start for MATLABSystem: '<S5>/SinkBlock'
    b_zeroDelimTopic[i] = b_zeroDelimTopic_0[i];
  }

  Pub_mj_monitorTune_ROS_136.createPublisher(&b_zeroDelimTopic[0], qos_profile);
}

static void mj_monito_Publisher_setupImpl_l(const
  ros_slros2_internal_block_Pub_T *obj)
{
  rmw_qos_profile_t qos_profile;
  sJ4ih70VmKcvCeguWN0mNVF lifespan;
  sJ4ih70VmKcvCeguWN0mNVF liveliness_lease_duration;
  char_T b_zeroDelimTopic[14];
  static const char_T b_zeroDelimTopic_0[14] = "/block_camera";
  qos_profile = rmw_qos_profile_default;

  // Start for MATLABSystem: '<S6>/SinkBlock'
  mj_monitorTune_ROS_B.deadline.sec = 0.0;
  mj_monitorTune_ROS_B.deadline.nsec = 0.0;
  lifespan.sec = 0.0;
  lifespan.nsec = 0.0;
  liveliness_lease_duration.sec = 0.0;
  liveliness_lease_duration.nsec = 0.0;
  SET_QOS_VALUES(qos_profile, RMW_QOS_POLICY_HISTORY_KEEP_LAST, (size_t)1.0,
                 RMW_QOS_POLICY_DURABILITY_VOLATILE,
                 RMW_QOS_POLICY_RELIABILITY_RELIABLE,
                 mj_monitorTune_ROS_B.deadline, lifespan,
                 RMW_QOS_POLICY_LIVELINESS_AUTOMATIC, liveliness_lease_duration,
                 (bool)obj->QOSAvoidROSNamespaceConventions);
  for (int32_T i = 0; i < 14; i++) {
    // Start for MATLABSystem: '<S6>/SinkBlock'
    b_zeroDelimTopic[i] = b_zeroDelimTopic_0[i];
  }

  Pub_mj_monitorTune_ROS_143.createPublisher(&b_zeroDelimTopic[0], qos_profile);
}

// Model step function
void mj_monitorTune_ROS_step(void)
{
  int32_T ntIdx0;
  int32_T ntIdx1;
  int32_T ntIdx2;
  int32_T uElOffset1;
  int32_T uElOffset2;
  int32_T yElIdx;
  uint8_T xtmp;
  boolean_T tmp;

  // S-Function (mj_sfun): '<S3>/S-Function'

  // Level2 S-Function Block: '<S3>/S-Function' (mj_sfun)
  {
    SimStruct *rts = mj_monitorTune_ROS_M->childSfunctions[0];
    sfcnOutputs(rts,0);
  }

  // RateTransition: '<S3>/Rate Transition2'
  tmp = (mj_monitorTune_ROS_M->Timing.TaskCounters.TID[1] == 0);
  if (tmp) {
    // PermuteDimensions: '<S4>/Permute Dimensions'
    yElIdx = 0;
    uElOffset2 = 0;
    for (ntIdx2 = 0; ntIdx2 < 3; ntIdx2++) {
      uElOffset1 = uElOffset2;
      for (ntIdx1 = 0; ntIdx1 < 640; ntIdx1++) {
        for (ntIdx0 = 0; ntIdx0 < 480; ntIdx0++) {
          mj_monitorTune_ROS_B.PermuteDimensions[yElIdx + ntIdx0] =
            mj_monitorTune_ROS_B.SFunction_o2[(ntIdx0 * 1920 + uElOffset1) +
            2764800];
        }

        yElIdx += 480;
        uElOffset1 += 3;
      }

      uElOffset2++;
    }

    // End of PermuteDimensions: '<S4>/Permute Dimensions'

    // MATLAB Function: '<S4>/image flip fcn'
    for (yElIdx = 0; yElIdx < 3; yElIdx++) {
      for (uElOffset2 = 0; uElOffset2 < 640; uElOffset2++) {
        for (ntIdx2 = 0; ntIdx2 < 240; ntIdx2++) {
          uElOffset1 = (480 * uElOffset2 + ntIdx2) + 307200 * yElIdx;
          xtmp = mj_monitorTune_ROS_B.PermuteDimensions[uElOffset1];
          ntIdx1 = ((480 * uElOffset2 - ntIdx2) + 307200 * yElIdx) + 479;
          mj_monitorTune_ROS_B.PermuteDimensions[uElOffset1] =
            mj_monitorTune_ROS_B.PermuteDimensions[ntIdx1];
          mj_monitorTune_ROS_B.PermuteDimensions[ntIdx1] = xtmp;
        }
      }
    }

    // End of MATLAB Function: '<S4>/image flip fcn'

    // MATLAB Function: '<S7>/MATLAB Function' incorporates:
    //   Constant: '<S11>/Constant'

    memcpy(&mj_monitorTune_ROS_B.HeaderAssign.data[0],
           &mj_monitorTune_ROS_P.Constant_Value.data[0], 940000U * sizeof
           (uint8_T));
    mj_monitorTu_WriteImageFcnBlock(mj_monitorTune_ROS_B.PermuteDimensions,
      mj_monitorTune_ROS_B.HeaderAssign.data,
      mj_monitorTune_ROS_B.HeaderAssign.encoding);
  }

  // End of RateTransition: '<S3>/Rate Transition2'

  // BusAssignment: '<Root>/Bus Assignment' incorporates:
  //   Constant: '<S1>/Constant'
  //   MATLABSystem: '<S8>/parser'
  //
  mj_monitorTune_ROS_B.BusAssignment_i = mj_monitorTune_ROS_P.Constant_Value_g;

  //  next index to write from.
  mj_monitorTune_ROS_B.BusAssignment_i.orientation.x =
    mj_monitorTune_ROS_B.SFunction_o1[0];
  mj_monitorTune_ROS_B.BusAssignment_i.orientation.y =
    mj_monitorTune_ROS_B.SFunction_o1[1];
  mj_monitorTune_ROS_B.BusAssignment_i.orientation.z =
    mj_monitorTune_ROS_B.SFunction_o1[2];
  mj_monitorTune_ROS_B.BusAssignment_i.orientation.w =
    mj_monitorTune_ROS_B.SFunction_o1[3];

  // MATLABSystem: '<S5>/SinkBlock'
  Pub_mj_monitorTune_ROS_136.publish(&mj_monitorTune_ROS_B.BusAssignment_i);
  if (tmp) {
    // Outputs for Atomic SubSystem: '<Root>/Header Assignment'
    // Switch: '<S2>/Switch1' incorporates:
    //   Constant: '<S2>/Constant1'
    //   StringConstant: '<S2>/String Constant1'

    if (mj_monitorTune_ROS_P.Constant1_Value != 0.0) {
      strncpy(&mj_monitorTune_ROS_B.Switch1[0],
              &mj_monitorTune_ROS_P.StringConstant1_String[0], 255U);
      mj_monitorTune_ROS_B.Switch1[255] = '\x00';
    } else {
      // ASCIIToString: '<S2>/ASCII to String' incorporates:
      //   BusAssignment: '<S7>/Bus Assignment'
      //   Constant: '<S11>/Constant'

      for (ntIdx2 = 0; ntIdx2 < 128; ntIdx2++) {
        mj_monitorTune_ROS_B.Switch1[ntIdx2] = static_cast<int8_T>
          (mj_monitorTune_ROS_P.Constant_Value.header.frame_id[ntIdx2]);
        mj_monitorTune_ROS_B.Switch1[ntIdx2 + 128] = '\x00';
      }

      // End of ASCIIToString: '<S2>/ASCII to String'
    }

    // End of Switch: '<S2>/Switch1'

    // StringToASCII: '<S2>/String To ASCII' incorporates:
    //   BusAssignment: '<S2>/HeaderAssign'

    strncpy((char_T *)&mj_monitorTune_ROS_B.HeaderAssign.header.frame_id[0],
            &mj_monitorTune_ROS_B.Switch1[0], 128U);

    // MATLABSystem: '<S2>/Current Time'
    currentROS2TimeBus(&mj_monitorTune_ROS_B.HeaderAssign.header.stamp);

    // Switch: '<S2>/Switch' incorporates:
    //   Constant: '<S2>/Constant'

    if (!(mj_monitorTune_ROS_P.Constant_Value_f != 0.0)) {
      // BusAssignment: '<S2>/HeaderAssign' incorporates:
      //   BusAssignment: '<S7>/Bus Assignment'
      //   Constant: '<S11>/Constant'

      mj_monitorTune_ROS_B.HeaderAssign.header.stamp =
        mj_monitorTune_ROS_P.Constant_Value.header.stamp;
    }

    // End of Switch: '<S2>/Switch'

    // BusAssignment: '<S2>/HeaderAssign' incorporates:
    //   BusAssignment: '<S7>/Bus Assignment'
    //   Constant: '<S11>/Constant'
    //   StringLength: '<S2>/String Length'

    mj_monitorTune_ROS_B.HeaderAssign.header.frame_id_SL_Info.ReceivedLength =
      mj_monitorTune_ROS_P.Constant_Value.header.frame_id_SL_Info.ReceivedLength;
    mj_monitorTune_ROS_B.HeaderAssign.height = 480U;
    mj_monitorTune_ROS_B.HeaderAssign.width = 640U;
    mj_monitorTune_ROS_B.HeaderAssign.encoding_SL_Info.CurrentLength = 4U;
    mj_monitorTune_ROS_B.HeaderAssign.encoding_SL_Info.ReceivedLength = 4U;
    mj_monitorTune_ROS_B.HeaderAssign.is_bigendian =
      mj_monitorTune_ROS_P.Constant_Value.is_bigendian;
    mj_monitorTune_ROS_B.HeaderAssign.step = 1920U;
    mj_monitorTune_ROS_B.HeaderAssign.data_SL_Info.CurrentLength = 921600U;
    mj_monitorTune_ROS_B.HeaderAssign.data_SL_Info.ReceivedLength = 921600U;
    mj_monitorTune_ROS_B.HeaderAssign.header.frame_id_SL_Info.CurrentLength =
      strlen(&mj_monitorTune_ROS_B.Switch1[0]);

    // End of Outputs for SubSystem: '<Root>/Header Assignment'

    // MATLABSystem: '<S6>/SinkBlock'
    Pub_mj_monitorTune_ROS_143.publish(&mj_monitorTune_ROS_B.HeaderAssign);
  }

  // Constant: '<Root>/Constant1'
  mj_monitorTune_ROS_B.Constant1 = mj_monitorTune_ROS_P.Constant1_Value_j;

  // Constant: '<S9>/Constant'
  mj_monitorTune_ROS_B.Constant = mj_monitorTune_ROS_P.Constant_Value_e;

  // Update for S-Function (mj_sfun): '<S3>/S-Function'
  // Level2 S-Function Block: '<S3>/S-Function' (mj_sfun)
  {
    SimStruct *rts = mj_monitorTune_ROS_M->childSfunctions[0];
    sfcnUpdate(rts,0);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  // Update absolute time for base rate
  // The "clockTick0" counts the number of times the code of this task has
  //  been executed. The absolute time is the multiplication of "clockTick0"
  //  and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
  //  overflow during the application lifespan selected.

  mj_monitorTune_ROS_M->Timing.t[0] =
    ((time_T)(++mj_monitorTune_ROS_M->Timing.clockTick0)) *
    mj_monitorTune_ROS_M->Timing.stepSize0;
  rate_scheduler();
}

// Model initialize function
void mj_monitorTune_ROS_initialize(void)
{
  // Registration code

  // initialize non-finites
  rt_InitInfAndNaN(sizeof(real_T));
  rtsiSetSolverName(&mj_monitorTune_ROS_M->solverInfo,"FixedStepDiscrete");
  mj_monitorTune_ROS_M->solverInfoPtr = (&mj_monitorTune_ROS_M->solverInfo);

  // Initialize timing info
  {
    int_T *mdlTsMap = mj_monitorTune_ROS_M->Timing.sampleTimeTaskIDArray;
    mdlTsMap[0] = 0;
    mdlTsMap[1] = 1;
    mj_monitorTune_ROS_M->Timing.sampleTimeTaskIDPtr = (&mdlTsMap[0]);
    mj_monitorTune_ROS_M->Timing.sampleTimes =
      (&mj_monitorTune_ROS_M->Timing.sampleTimesArray[0]);
    mj_monitorTune_ROS_M->Timing.offsetTimes =
      (&mj_monitorTune_ROS_M->Timing.offsetTimesArray[0]);

    // task periods
    mj_monitorTune_ROS_M->Timing.sampleTimes[0] = (0.1);
    mj_monitorTune_ROS_M->Timing.sampleTimes[1] = (0.2);

    // task offsets
    mj_monitorTune_ROS_M->Timing.offsetTimes[0] = (0.0);
    mj_monitorTune_ROS_M->Timing.offsetTimes[1] = (0.0);
  }

  mj_monitorTune_ROS_M->setTPtr(&mj_monitorTune_ROS_M->Timing.tArray[0]);

  {
    int_T *mdlSampleHits = mj_monitorTune_ROS_M->Timing.sampleHitArray;
    mdlSampleHits[0] = 1;
    mdlSampleHits[1] = 1;
    mj_monitorTune_ROS_M->Timing.sampleHits = (&mdlSampleHits[0]);
  }

  mj_monitorTune_ROS_M->setTFinal(-1);
  mj_monitorTune_ROS_M->Timing.stepSize0 = 0.1;
  mj_monitorTune_ROS_M->solverInfoPtr = (&mj_monitorTune_ROS_M->solverInfo);
  mj_monitorTune_ROS_M->Timing.stepSize = (0.1);
  rtsiSetFixedStepSize(&mj_monitorTune_ROS_M->solverInfo, 0.1);
  rtsiSetSolverMode(&mj_monitorTune_ROS_M->solverInfo, SOLVER_MODE_SINGLETASKING);

  // child S-Function registration
  {
    RTWSfcnInfo *sfcnInfo = &mj_monitorTune_ROS_M->NonInlinedSFcns.sfcnInfo;
    mj_monitorTune_ROS_M->sfcnInfo = (sfcnInfo);
    rtssSetErrorStatusPtr(sfcnInfo, mj_monitorTune_ROS_M->getErrorStatusPtr());
    mj_monitorTune_ROS_M->Sizes.numSampTimes = (2);
    rtssSetNumRootSampTimesPtr(sfcnInfo,
      &mj_monitorTune_ROS_M->Sizes.numSampTimes);
    mj_monitorTune_ROS_M->NonInlinedSFcns.taskTimePtrs[0] =
      (mj_monitorTune_ROS_M->getTPtrPtr()[0]);
    mj_monitorTune_ROS_M->NonInlinedSFcns.taskTimePtrs[1] =
      (mj_monitorTune_ROS_M->getTPtrPtr()[1]);
    rtssSetTPtrPtr(sfcnInfo,mj_monitorTune_ROS_M->NonInlinedSFcns.taskTimePtrs);
    rtssSetTStartPtr(sfcnInfo, mj_monitorTune_ROS_M->getTStartPtr());
    rtssSetTFinalPtr(sfcnInfo, mj_monitorTune_ROS_M->getTFinalPtr());
    rtssSetTimeOfLastOutputPtr(sfcnInfo,
      mj_monitorTune_ROS_M->getTimeOfLastOutputPtr());
    rtssSetStepSizePtr(sfcnInfo, &mj_monitorTune_ROS_M->Timing.stepSize);
    rtssSetStopRequestedPtr(sfcnInfo, mj_monitorTune_ROS_M->getStopRequestedPtr());
    rtssSetDerivCacheNeedsResetPtr(sfcnInfo,
      &mj_monitorTune_ROS_M->derivCacheNeedsReset);
    rtssSetZCCacheNeedsResetPtr(sfcnInfo,
      &mj_monitorTune_ROS_M->zCCacheNeedsReset);
    rtssSetContTimeOutputInconsistentWithStateAtMajorStepPtr(sfcnInfo,
      &mj_monitorTune_ROS_M->CTOutputIncnstWithState);
    rtssSetSampleHitsPtr(sfcnInfo, &mj_monitorTune_ROS_M->Timing.sampleHits);
    rtssSetPerTaskSampleHitsPtr(sfcnInfo,
      &mj_monitorTune_ROS_M->Timing.perTaskSampleHits);
    rtssSetSimModePtr(sfcnInfo, &mj_monitorTune_ROS_M->simMode);
    rtssSetSolverInfoPtr(sfcnInfo, &mj_monitorTune_ROS_M->solverInfoPtr);
  }

  mj_monitorTune_ROS_M->Sizes.numSFcns = (1);

  // register each child
  {
    (void) memset(static_cast<void *>
                  (&mj_monitorTune_ROS_M->NonInlinedSFcns.childSFunctions[0]), 0,
                  1*sizeof(SimStruct));
    mj_monitorTune_ROS_M->childSfunctions =
      (&mj_monitorTune_ROS_M->NonInlinedSFcns.childSFunctionPtrs[0]);
    mj_monitorTune_ROS_M->childSfunctions[0] =
      (&mj_monitorTune_ROS_M->NonInlinedSFcns.childSFunctions[0]);

    // Level2 S-Function Block: mj_monitorTune_ROS/<S3>/S-Function (mj_sfun)
    {
      SimStruct *rts = mj_monitorTune_ROS_M->childSfunctions[0];

      // timing info
      time_T *sfcnPeriod =
        mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.sfcnPeriod;
      time_T *sfcnOffset =
        mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.sfcnOffset;
      int_T *sfcnTsMap = mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.sfcnTsMap;
      (void) memset(static_cast<void*>(sfcnPeriod), 0,
                    sizeof(time_T)*1);
      (void) memset(static_cast<void*>(sfcnOffset), 0,
                    sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts, &mj_monitorTune_ROS_M->NonInlinedSFcns.blkInfo2[0]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &mj_monitorTune_ROS_M->NonInlinedSFcns.inputOutputPortInfo2[0]);

      // Set up the mdlInfo pointer
      ssSetRTWSfcnInfo(rts, mj_monitorTune_ROS_M->sfcnInfo);

      // Allocate memory of model methods 2
      {
        ssSetModelMethods2(rts, &mj_monitorTune_ROS_M->NonInlinedSFcns.methods2
                           [0]);
      }

      // Allocate memory of model methods 3
      {
        ssSetModelMethods3(rts, &mj_monitorTune_ROS_M->NonInlinedSFcns.methods3
                           [0]);
      }

      // Allocate memory of model methods 4
      {
        ssSetModelMethods4(rts, &mj_monitorTune_ROS_M->NonInlinedSFcns.methods4
                           [0]);
      }

      // Allocate memory for states auxilliary information
      {
        ssSetStatesInfo2(rts, &mj_monitorTune_ROS_M->
                         NonInlinedSFcns.statesInfo2[0]);
        ssSetPeriodicStatesInfo(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.periodicStatesInfo[0]);
      }

      // inputs
      {
        _ssSetNumInputPorts(rts, 1);
        ssSetPortInfoForInputs(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.inputPortInfo[0]);
        ssSetPortInfoForInputs(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.inputPortInfo[0]);
        _ssSetPortInfo2ForInputUnits(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.inputPortUnits[0]);
        ssSetInputPortUnit(rts, 0, 0);
        _ssSetPortInfo2ForInputCoSimAttribute(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.inputPortCoSimAttribute[0]);
        ssSetInputPortIsContinuousQuantity(rts, 0, 0);

        // port 0
        {
          real_T const **sfcnUPtrs = (real_T const **)
            &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.UPtrs0;
          sfcnUPtrs[0] = &mj_monitorTune_ROS_B.Constant1;
          sfcnUPtrs[1] = &mj_monitorTune_ROS_B.Constant;
          ssSetInputPortSignalPtrs(rts, 0, (InputPtrsType)&sfcnUPtrs[0]);
          _ssSetInputPortNumDimensions(rts, 0, 1);
          ssSetInputPortWidthAsInt(rts, 0, 2);
        }
      }

      // outputs
      {
        ssSetPortInfoForOutputs(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.outputPortInfo[0]);
        ssSetPortInfoForOutputs(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.outputPortInfo[0]);
        _ssSetNumOutputPorts(rts, 4);
        _ssSetPortInfo2ForOutputUnits(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.outputPortUnits[0]);
        ssSetOutputPortUnit(rts, 0, 0);
        ssSetOutputPortUnit(rts, 1, 0);
        ssSetOutputPortUnit(rts, 2, 0);
        ssSetOutputPortUnit(rts, 3, 0);
        _ssSetPortInfo2ForOutputCoSimAttribute(rts,
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.outputPortCoSimAttribute
          [0]);
        ssSetOutputPortIsContinuousQuantity(rts, 0, 0);
        ssSetOutputPortIsContinuousQuantity(rts, 1, 0);
        ssSetOutputPortIsContinuousQuantity(rts, 2, 0);
        ssSetOutputPortIsContinuousQuantity(rts, 3, 0);

        // port 0
        {
          _ssSetOutputPortNumDimensions(rts, 0, 1);
          ssSetOutputPortWidthAsInt(rts, 0, 5);
          ssSetOutputPortSignal(rts, 0, ((real_T *)
            mj_monitorTune_ROS_B.SFunction_o1));
        }

        // port 1
        {
          _ssSetOutputPortNumDimensions(rts, 1, 1);
          ssSetOutputPortWidthAsInt(rts, 1, 3686401);
          ssSetOutputPortSignal(rts, 1, ((uint8_T *)
            mj_monitorTune_ROS_B.SFunction_o2));
        }

        // port 2
        {
          _ssSetOutputPortNumDimensions(rts, 2, 1);
          ssSetOutputPortWidthAsInt(rts, 2, 1228801);
          ssSetOutputPortSignal(rts, 2, ((real32_T *)
            mj_monitorTune_ROS_B.SFunction_o3));
        }

        // port 3
        {
          _ssSetOutputPortNumDimensions(rts, 3, 1);
          ssSetOutputPortWidthAsInt(rts, 3, 3686401);
          ssSetOutputPortSignal(rts, 3, ((uint8_T *)
            mj_monitorTune_ROS_B.SFunction_o4));
        }
      }

      // path info
      ssSetModelName(rts, "S-Function");
      ssSetPath(rts, "mj_monitorTune_ROS/MuJoCo Plant/S-Function");
      ssSetRTModel(rts,mj_monitorTune_ROS_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      // parameters
      {
        mxArray **sfcnParams = (mxArray **)
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.params;
        ssSetSFcnParamsCount(rts, 17);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)mj_monitorTune_ROS_P.SFunction_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)mj_monitorTune_ROS_P.SFunction_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)mj_monitorTune_ROS_P.SFunction_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)mj_monitorTune_ROS_P.SFunction_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)mj_monitorTune_ROS_P.SFunction_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)mj_monitorTune_ROS_P.SFunction_P6_Size);
        ssSetSFcnParam(rts, 6, (mxArray*)mj_monitorTune_ROS_P.SFunction_P7_Size);
        ssSetSFcnParam(rts, 7, (mxArray*)mj_monitorTune_ROS_P.SFunction_P8_Size);
        ssSetSFcnParam(rts, 8, (mxArray*)mj_monitorTune_ROS_P.SFunction_P9_Size);
        ssSetSFcnParam(rts, 9, (mxArray*)mj_monitorTune_ROS_P.SFunction_P10_Size);
        ssSetSFcnParam(rts, 10, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P11_Size);
        ssSetSFcnParam(rts, 11, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P12_Size);
        ssSetSFcnParam(rts, 12, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P13_Size);
        ssSetSFcnParam(rts, 13, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P14_Size);
        ssSetSFcnParam(rts, 14, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P15_Size);
        ssSetSFcnParam(rts, 15, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P16_Size);
        ssSetSFcnParam(rts, 16, (mxArray*)
                       mj_monitorTune_ROS_P.SFunction_P17_Size);
      }

      // work vectors
      ssSetIWork(rts, (int_T *) &mj_monitorTune_ROS_DW.SFunction_IWORK[0]);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &mj_monitorTune_ROS_M->NonInlinedSFcns.Sfcn0.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        ssSetNumDWorkAsInt(rts, 1);

        // IWORK
        ssSetDWorkWidthAsInt(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &mj_monitorTune_ROS_DW.SFunction_IWORK[0]);
      }

      // registration
      mj_sfun(rts);
      sfcnInitializeSizes(rts);
      sfcnInitializeSampleTimes(rts);

      // adjust sample time
      ssSetSampleTime(rts, 0, 0.1);
      ssSetOffsetTime(rts, 0, 0.0);
      sfcnTsMap[0] = 0;

      // set compiled values of dynamic vector attributes
      ssSetNumNonsampledZCsAsInt(rts, 0);

      // Update connectivity flags for each port
      _ssSetInputPortConnected(rts, 0, 1);
      _ssSetOutputPortConnected(rts, 0, 1);
      _ssSetOutputPortConnected(rts, 1, 1);
      _ssSetOutputPortConnected(rts, 2, 1);
      _ssSetOutputPortConnected(rts, 3, 1);
      _ssSetOutputPortBeingMerged(rts, 0, 0);
      _ssSetOutputPortBeingMerged(rts, 1, 0);
      _ssSetOutputPortBeingMerged(rts, 2, 0);
      _ssSetOutputPortBeingMerged(rts, 3, 0);

      // Update the BufferDstPort flags for each input port
      ssSetInputPortBufferDstPort(rts, 0, -1);
    }
  }

  // Start for S-Function (mj_sfun): '<S3>/S-Function'
  // Level2 S-Function Block: '<S3>/S-Function' (mj_sfun)
  {
    SimStruct *rts = mj_monitorTune_ROS_M->childSfunctions[0];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  // Start for Constant: '<Root>/Constant1'
  mj_monitorTune_ROS_B.Constant1 = mj_monitorTune_ROS_P.Constant1_Value_j;

  // Start for Constant: '<S9>/Constant'
  mj_monitorTune_ROS_B.Constant = mj_monitorTune_ROS_P.Constant_Value_e;

  // SystemInitialize for Atomic SubSystem: '<Root>/Header Assignment'
  // Start for MATLABSystem: '<S2>/Current Time'
  mj_monitorTune_ROS_DW.obj.matlabCodegenIsDeleted = false;
  mj_monitorTune_ROS_DW.obj.isInitialized = 1;
  mj_monitorTune_ROS_DW.obj.isSetupComplete = true;

  // End of SystemInitialize for SubSystem: '<Root>/Header Assignment'

  // Start for MATLABSystem: '<S5>/SinkBlock'
  mj_monitorTune_ROS_DW.obj_o.QOSAvoidROSNamespaceConventions = false;
  mj_monitorTune_ROS_DW.obj_o.matlabCodegenIsDeleted = false;
  mj_monitorTune_ROS_DW.obj_o.isSetupComplete = false;
  mj_monitorTune_ROS_DW.obj_o.isInitialized = 1;
  mj_monitorT_Publisher_setupImpl(&mj_monitorTune_ROS_DW.obj_o);
  mj_monitorTune_ROS_DW.obj_o.isSetupComplete = true;

  // Start for MATLABSystem: '<S6>/SinkBlock'
  mj_monitorTune_ROS_DW.obj_i.QOSAvoidROSNamespaceConventions = false;
  mj_monitorTune_ROS_DW.obj_i.matlabCodegenIsDeleted = false;
  mj_monitorTune_ROS_DW.obj_i.isSetupComplete = false;
  mj_monitorTune_ROS_DW.obj_i.isInitialized = 1;
  mj_monito_Publisher_setupImpl_l(&mj_monitorTune_ROS_DW.obj_i);
  mj_monitorTune_ROS_DW.obj_i.isSetupComplete = true;
}

// Model terminate function
void mj_monitorTune_ROS_terminate(void)
{
  // Terminate for S-Function (mj_sfun): '<S3>/S-Function'
  // Level2 S-Function Block: '<S3>/S-Function' (mj_sfun)
  {
    SimStruct *rts = mj_monitorTune_ROS_M->childSfunctions[0];
    sfcnTerminate(rts);
  }

  // Terminate for MATLABSystem: '<S5>/SinkBlock'
  if (!mj_monitorTune_ROS_DW.obj_o.matlabCodegenIsDeleted) {
    mj_monitorTune_ROS_DW.obj_o.matlabCodegenIsDeleted = true;
    if ((mj_monitorTune_ROS_DW.obj_o.isInitialized == 1) &&
        mj_monitorTune_ROS_DW.obj_o.isSetupComplete) {
      Pub_mj_monitorTune_ROS_136.resetPublisherPtr();//();
    }
  }

  // End of Terminate for MATLABSystem: '<S5>/SinkBlock'

  // Terminate for Atomic SubSystem: '<Root>/Header Assignment'
  // Terminate for MATLABSystem: '<S2>/Current Time'
  if (!mj_monitorTune_ROS_DW.obj.matlabCodegenIsDeleted) {
    mj_monitorTune_ROS_DW.obj.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S2>/Current Time'
  // End of Terminate for SubSystem: '<Root>/Header Assignment'

  // Terminate for MATLABSystem: '<S6>/SinkBlock'
  if (!mj_monitorTune_ROS_DW.obj_i.matlabCodegenIsDeleted) {
    mj_monitorTune_ROS_DW.obj_i.matlabCodegenIsDeleted = true;
    if ((mj_monitorTune_ROS_DW.obj_i.isInitialized == 1) &&
        mj_monitorTune_ROS_DW.obj_i.isSetupComplete) {
      Pub_mj_monitorTune_ROS_143.resetPublisherPtr();//();
    }
  }

  // End of Terminate for MATLABSystem: '<S6>/SinkBlock'
}

boolean_T RT_MODEL_mj_monitorTune_ROS_T::getStopRequested() const
{
  return (Timing.stopRequestedFlag);
}

void RT_MODEL_mj_monitorTune_ROS_T::setStopRequested(boolean_T aStopRequested)
{
  (Timing.stopRequestedFlag = aStopRequested);
}

boolean_T RT_MODEL_mj_monitorTune_ROS_T::getDerivCacheNeedsReset() const
{
  return derivCacheNeedsReset;
}

void RT_MODEL_mj_monitorTune_ROS_T::setDerivCacheNeedsReset(boolean_T
  aDerivCacheNeedsReset)
{
  derivCacheNeedsReset = aDerivCacheNeedsReset;
}

const char_T* RT_MODEL_mj_monitorTune_ROS_T::getErrorStatus() const
{
  return (errorStatus);
}

void RT_MODEL_mj_monitorTune_ROS_T::setErrorStatus(const char_T* const
  aErrorStatus)
{
  (errorStatus = aErrorStatus);
}

boolean_T RT_MODEL_mj_monitorTune_ROS_T::
  getContTimeOutputInconsistentWithStateAtMajorStepFlag() const
{
  return CTOutputIncnstWithState;
}

void RT_MODEL_mj_monitorTune_ROS_T::
  setContTimeOutputInconsistentWithStateAtMajorStepFlag(boolean_T
  aContTimeOutputInconsistentWithStateAtMajorStepFlag)
{
  CTOutputIncnstWithState = aContTimeOutputInconsistentWithStateAtMajorStepFlag;
}

const char_T** RT_MODEL_mj_monitorTune_ROS_T::getErrorStatusPtr()
{
  return &errorStatus;
}

time_T RT_MODEL_mj_monitorTune_ROS_T::getStepSize() const
{
  return Timing.stepSize;
}

time_T RT_MODEL_mj_monitorTune_ROS_T::getFinalTime() const
{
  return Timing.tFinal;
}

const int_T* RT_MODEL_mj_monitorTune_ROS_T::getSampleHitArray() const
{
  return Timing.sampleHitArray;
}

boolean_T* RT_MODEL_mj_monitorTune_ROS_T::getStopRequestedPtr()
{
  return &(Timing.stopRequestedFlag);
}

time_T RT_MODEL_mj_monitorTune_ROS_T::getTFinal() const
{
  return (Timing.tFinal);
}

void RT_MODEL_mj_monitorTune_ROS_T::setTFinal(time_T aTFinal)
{
  (Timing.tFinal = aTFinal);
}

time_T* RT_MODEL_mj_monitorTune_ROS_T::getTFinalPtr()
{
  return &(Timing.tFinal);
}

time_T* RT_MODEL_mj_monitorTune_ROS_T::getTPtr() const
{
  return (Timing.t);
}

void RT_MODEL_mj_monitorTune_ROS_T::setTPtr(time_T* aTPtr)
{
  (Timing.t = aTPtr);
}

time_T** RT_MODEL_mj_monitorTune_ROS_T::getTPtrPtr()
{
  return &(Timing.t);
}

time_T RT_MODEL_mj_monitorTune_ROS_T::getTStart() const
{
  return (Timing.tStart);
}

time_T* RT_MODEL_mj_monitorTune_ROS_T::getTStartPtr()
{
  return &(Timing.tStart);
}

time_T RT_MODEL_mj_monitorTune_ROS_T::getTimeOfLastOutput() const
{
  return (Timing.timeOfLastOutput);
}

time_T* RT_MODEL_mj_monitorTune_ROS_T::getTimeOfLastOutputPtr()
{
  return &(Timing.timeOfLastOutput);
}

boolean_T RT_MODEL_mj_monitorTune_ROS_T::getZCCacheNeedsReset() const
{
  return zCCacheNeedsReset;
}

void RT_MODEL_mj_monitorTune_ROS_T::setZCCacheNeedsReset(boolean_T
  aZCCacheNeedsReset)
{
  zCCacheNeedsReset = aZCCacheNeedsReset;
}

time_T RT_MODEL_mj_monitorTune_ROS_T::get_TimeOfLastOutput() const
{
  return Timing.timeOfLastOutput;
}
