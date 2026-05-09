// Minimal C++ interface Wrapper over Mujoco C API

// Refer to MuJoCo website to learn more about the API
// MuJoCo is a trademark of DeepMind

// Copyright 2022-2023 The MathWorks, Inc.

#pragma once
#include "mujoco/mujoco.h"
// #include "glfw3.h"
#include <GLFW/glfw3.h>
#include <mutex>
#include <string>
#include <vector>
#include <chrono>
#include <thread>
#include <atomic>
#include <memory>
#include "semaphore.hpp"

// using namespace std::chrono_literals;

mjModel* mj_loadXMLWithPlugins(const std::string& file, const mjVFS* vfs, char* error, int error_sz);

class sensorInterface
{
    public:
    unsigned count;
    unsigned scalarCount; // number of individual data count. imu and rangefinder would give 4 scalars
    std::vector<std::string> names;
    std::vector<unsigned> dim;
    std::vector<unsigned> addr;

    std::size_t hash();
};

class controlInterface
{
    public:
    unsigned count;
    std::vector<std::string> names;

    std::size_t hash();
};

struct offscreenSize
{
    unsigned height;
    unsigned width;
};

// MuJoCo 3.x compatibility note: cameraInterface and related fields assume MuJoCo 3.3.1+ API.
// Fields such as m->ncam, m->name_camadr, and m->names are used for camera enumeration and naming.
// If upgrading MuJoCo, verify these fields remain compatible.
class cameraInterface
{
    public:
    // Number of cameras in the model (from mjModel->ncam)
    unsigned count = 0;
    // Camera names (from mjModel->names + mjModel->name_camadr[])
    std::vector<std::string> names;
    // Offscreen rendering size for each camera (populated from offscreen buffer size)
    std::vector<offscreenSize> size;
    // Address offsets for RGB data in the combined buffer (per camera)
    std::vector<unsigned long> rgbAddr;
    // Address offsets for depth data in the combined buffer (per camera)
    std::vector<unsigned long> depthAddr;
    // Address offsets for segmentation data in the combined buffer (per camera)
    std::vector<unsigned long> segAddr;
    // Total length of RGB buffer (sum of all cameras)
    unsigned long rgbLength = 0;
    // Total length of depth buffer (sum of all cameras)
    unsigned long depthLength = 0;
    // Total length of segmentation buffer (sum of all cameras)
    unsigned long segLength = 0;

    // Returns a hash of the interface for change detection
    std::size_t hash();
};

class MujocoGUI;
class MujocoModelInstance
{
    // This class is not designed to be moved or copied
private:
    mjData *d = NULL;
    mjModel *m = NULL;

    int initCameras();

    controlInterface getControlInterface();
    sensorInterface getSensorInterface();
    cameraInterface getCameraInterface();

    // disable copy constructor
    MujocoModelInstance(const MujocoModelInstance &mi);
public:
    std::mutex dMutex; // mutex for model data access 

    // cameras in the model instance
    std::vector<std::shared_ptr<MujocoGUI>> offscreenCam;
    
    // enable default contructor
    MujocoModelInstance() = default;
    ~MujocoModelInstance();

    int initMdl(std::string file, bool shouldInitCam = true, bool shouldGetCami = true);
    int initData();
    
    // Public accessor for camera interface (needed for per-camera resolution in mj_initbus_mex)
    cameraInterface getCameraInterfacePublic() { return getCameraInterface(); }

    // Cache for internal usage
    controlInterface ci;
    sensorInterface si;

    // Camera interface gets initialized in background rendering thread. Protect it with mutex
    cameraInterface cami;
    std::mutex camiMutex;

    double getSampleTime();
    mjModel *get_m();
    mjData *get_d();


    // Camera timing
    double lastRenderTime = 0;
    double cameraRenderInterval = 0.020;
    std::atomic<bool> isCameraDataNew = false;
    binarySemp cameraSync; // semp for syncing main thread and render camera thread
    std::atomic<bool> shouldCameraRenderNow = false;

    // Conditional rendering flags (set from S-Function parameters)
    bool renderRGB = true;
    bool renderDepth = true;
    bool renderSeg = true;

    void step(std::vector<double> u);
    std::vector<double> getSensor(unsigned index);
    size_t getCameraRGB(uint8_t *buffer, size_t maxBufferSize = 0);
    size_t getCameraDepth(float *buffer, size_t maxBufferSize = 0);
    size_t getCameraSegmentation(uint8_t *buffer, size_t maxBufferSize = 0);
};

enum glTarget
{
    MJ_WINDOW = 0,
    MJ_OFFSCREEN
};
enum guiErrCodes
{
    NO_ERR = 0,
    UNKNOWN_TARGET,
    WINDOW_CREATION_FAILED,
    OFFSCREEN_TARGET_NOT_SUPPORTED,
    RGBD_BUFFER_ALLOC_FAILED,
    GLFW_INIT_FAILED
};

class MujocoGUI
{
    // This class represents a GUI window or an offscreen buffer (used for rendering rgbd cameras)
    // GUI window can be common to multiple model instances (can overlap parallel simulations)

    private:
    mjvOption opt;
    mjrContext con;
    mjrRect viewport = {0, 0, 0, 0};
    glTarget target;

    // adding content to a scene based on current simulation state
    void refreshScene(MujocoModelInstance* mdlInstance);
    void addGeomsToScene(MujocoModelInstance* mdlInstance);
    
    public:
    GLFWwindow *window; // exposed for window callback management
    mjvCamera cam; // exposed for window callback management
    mjvScene scn;
    double zoomLevel = 1.0;

    // rendering asset/scene information
    std::vector<MujocoModelInstance*> mdlInstances;
    MujocoModelInstance* sceneAssetModel;

    // rgb and depth buffers for offscreen rendering
    std::mutex camBufferMutex;
    unsigned char* rgb = nullptr;
    float* depth = nullptr;
    unsigned char* segmentation = nullptr;

    // camera spec
    // MuJoCo 3.x compatibility: camType and camId are set for offscreen rendering (mjCAMERA_FIXED assumed)
    mjtCamera camType; // Camera type (e.g., mjCAMERA_FIXED)
    int camId;         // Camera index in the model

    // Per-camera resolution control (0 means use MJCF global offwidth/offheight)
    int desiredWidth = 0;
    int desiredHeight = 0;

    std::atomic<bool> exited = false;
    std::mutex modelInstancesLock;

    // Timing 
    bool isVsyncOn = false;
    std::chrono::microseconds renderInterval;
    std::chrono::time_point<std::chrono::steady_clock> lastRenderClockTime;

    // Initialization
    guiErrCodes init(std::shared_ptr<MujocoModelInstance> mdlInstance, glTarget target);
    guiErrCodes init(MujocoModelInstance* mdlInstance, glTarget target);
    void addMi(std::shared_ptr<MujocoModelInstance> mdlInstance);
    void addMi(MujocoModelInstance* mdlInstance);
    
    // Run these in a single background thread
    guiErrCodes initInThread(offscreenSize *offSize = NULL, bool stopAtOffScreenSizeCalc = false);
    int loopInThread();
    void releaseInThread();

    private:
    // block copy constructor (can lead to double free cases when copied/moved)
    MujocoGUI(const MujocoGUI &g);

    public:
    // Enable default constructior and destructor
    MujocoGUI() = default;
    ~MujocoGUI();
};
