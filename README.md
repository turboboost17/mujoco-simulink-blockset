# Simulink Blockset for MuJoCo Simulator 

This repository provides a Simulink&reg; C-MEX S-Function block interface to the [MuJoCo&trade; physics engine](https://mujoco.org/).



Useful for,
1. Robot simulation (mobile, biomimetics, grippers, robotic arm)
2. Development of autonomous algorithms
3. Camera (RGB, Depth, Segmentation) rendering

## Installation Instructions

### MathWorks&reg; Products (https://www.mathworks.com)

- MATLAB&reg; (required)
- Simulink&reg; (required)
- Computer Vision Toolbox&trade; (optional)
- Robotics System Toolbox&trade; (optional)
- Control System Toolbox&trade; (optional)
- Simulink&reg; Coder&trade; (optional)
- ROS&reg; Toolbox&trade; (optional)

MATLAB R2024b or newer is recommended. Install MATLAB with the above products and then proceed to set up MuJoCo blocks.
- MuJoCo 3.7
- GLFW 3.3.7 (3.4 optional)

*Note - You will need to rebuild the S-Function when using a source checkout because the repository does not track generated binary files.*

### Simulink Blockset for MuJoCo
    
- (Linux users) Install GLFW library from Ubuntu terminal
    
    `sudo apt update && sudo apt install libglfw3 libglfw3-dev`
- Download the latest release of this repository (MATLAB Toolbox - MLTBX file)
- Open MATLAB R2022b or higher and install the downloaded MATLAB Toolbox file
- Run the setup function packaged in the toolbox. MuJoCo (and GLFW for Windows users) library is downloaded and added to MATLAB path.
    
    `>>mujoco_interface_setup`
- (Linux users) The default pathdef.m is likely not saveable in Linux. Save pathdef.m to new location as given in this [MATLAB answer](https://www.mathworks.com/matlabcentral/answers/1653435-how-to-use-savepath-for-adding-path-to-pathdef-m-in-linux).
    `savepath ~/Documents/MATLAB/pathdef.m`
    
## Usage
`>>mj_gettingStarted`
    
Open the example model and run it in normal simulation mode.

If the installation is successful, you should see a pendulum model running in a separate window and camera streams displayed by Video Viewer blocks (Computer Vision Toolbox).

*A dedicated graphics card is recommended for the best performance. Disable Video Viewer blocks if the model runs slow*

*(Linux users) - In case MATLAB crashes, it may be due to a glibc bug. Please follow this [bug report](https://www.mathworks.com/support/bugreports/2632298) for a workaround!*

### Blocks


MuJoCo Plant block steps MuJoCo engine, renders visualization window & camera, sets actuator data, and outputs sensor readings

It takes an XML (MJCF) as the main block parameter. It auto-detects the inputs, sensors, and cameras from XML to configure the block ports and sample time.

Inputs can either be a Simulink Bus or a vector.

Sensors are output as a Simulink Bus.

RGB and Depth buffers from cameras are output as vectors. These can be decoded to Simulink image/matrix using the RGB and Depth Parser blocks.  This version supports orthographic depth cameras with accurate depth measurements from inside the Depth Parser blocks.  For orthographic cameras it must be set to orthographic both in MuJoCo and the Depth camera block.

*Resolution changes — global `<global offwidth/offheight>`, MJCF per-camera `<camera resolution="W H">`, or the per-camera mask-driven `camWidth`/`camHeight` — now propagate to the RGB and Depth Parser blocks automatically via `mj_parser_maskinit.m`. Restarting MATLAB or manually clearing the workspace bus definitions is no longer required.*

## Z-Buffer Depth Resolution Control

To control Z-depth resolution for depth camera output, use `zfar`, `znear`, and `extent` parameters in your MJCF model.

### Depth Buffer Equations

**For Orthographic Cameras (linear depth):**
```
depth_meters = depth_buffer_value * (zfar - znear) + znear
```

**For Perspective Cameras (non-linear depth):**
```
depth_meters = znear / (1 - depth_buffer_value × (1 - znear/zfar))
```

### MuJoCo MJCF Parameter Relationships

In MuJoCo, the actual clipping planes are calculated as:
```
znear_actual = vis.map.znear × extent
zfar_actual = vis.map.zfar × extent
```

### Calculating Parameters for Required Resolution

**For 32-bit depth buffer (4,294,967,296 discrete values):**

**Orthographic Camera Resolution:**
```
resolution = (zfar_actual - znear_actual) / (2^32 - 1)
where:
zfar_actual = vis.map.zfar × extent
znear_actual = vis.map.znear × extent
```

**Example: 1 micron resolution with znear_actual = 0.054m:**
- Required zfar_actual = znear_actual + (1e-6 × (2^32 - 1)) = 0.054 + 4.295 = 4.349m
- If extent = 3: vis.map.zfar = 4.349/3 = 1.450, vis.map.znear = 0.054/3 = 0.018
- This gives actual resolution = (4.349 - 0.054) / (2^32 - 1) = 1.0 micron

**Perspective Camera Resolution (varies with depth):**
- Best resolution at znear plane: `resolution_near ≈ znear² / (zfar × 2^32)`
- Worst resolution at zfar plane: `resolution_far ≈ (zfar - znear)² / (znear × 2^32)`

### MJCF Configuration Example

```xml
<statistic extent="3" />  <!-- Required for controlling camera render depth resolution -->

<visual>
    <global offwidth="640" offheight="480" /> <!-- Camera H/V render resolution -->
    <map zfar="1.450" znear="0.018" />  <!-- For 1 micron resolution: znear_actual=0.054m, zfar_actual=4.349m -->
    <!-- <quality shadowsize="16384"/> -->
</visual>
```

**Configuration explanation:**
- `extent="3"` scales both clipping planes and depth resolution
- `znear_actual = 0.018 × 3 = 0.054m` (actual near clipping plane)
- `zfar_actual = 1.450 × 3 = 4.349m` (actual far clipping plane)
- Depth resolution = (4.349 - 0.054) / (2^32 - 1) = 1.0 micron


## Build Instructions (optional)

Steps for building/rebuilding the C-MEX S-Function code. These instructions are only required if you are cloning the repository instead of downloading the release.

### Windows:

- Install one of the following C++ Compiler
  - Microsoft&reg; Visual Studio&reg; 2022 or higher (recommended)
  - (or) [MinGW (GCC 12.2.0 or higher)](https://community.chocolatey.org/packages/mingw)
- Clone this repository
    
    `$ git clone git@github.com:turboboost17/mujoco-simulink-blockset.git`
- Launch MATLAB and open the repository folder
    - `>> install`
- Open tools/ 
    - Open setupBuild.m. In case you are using MinGW compiler, edit the file and set selectedCompilerWin to "MINGW".
    - `>> setupBuild`
    - `>> mex -setup c++`
    - `>> build`

### Ubuntu

- Install the tools required for compiling the S-Function

    `$ sudo apt update && sudo apt install build-essential git libglfw3 libglfw3-dev `
- Clone this repository

    `$ git clone git@github.com:turboboost17/mujoco-simulink-blockset.git`
- Launch MATLAB and open the repository folder. Run the install.m script.
    - `>> install`
- Open tools/ and run the following commands in MATLAB command Windows
    - `>> setupBuild`
    - `>> mex -setup c++`
    - `>> build`

## Tips and Tricks
- ***Code generation*** - The MuJoCo Plant block supports code generation (Simulink Coder) and monitor and tune for host target. Refer to mj_monitorTune.slx for more info.
- ***Performance improvement*** - In case you want to reduce the mask initialization overhead, you can directly use the underlying S-Function. Select the MuJoCo Plant block and Ctrl+U to look under the subsystem mask. Make sure to call the initialization functions (whenever the MJCF XML model changes).

## Limitations:

Linux Compatibility:

This blockset is only tested in Ubuntu 22.04 and Ubuntu 20.04. Other Ubuntu versions and distros are not supported.

### Software OpenGL:

This blockset does not work with software OpenGL. You can check whether MATLAB is using hardware GL with >>opengl info command.

In case you face graphics related issues, please try updating GLFW following the instructions given below!

## Bugs/Workarounds

### MATLAB R2023b MSVC Runtime Issue (Windows)

Some users have reported crashes (often involving `MSVCP140.dll` in the stack trace) when using this blockset with MATLAB R2023b, particularly after MSVC 2022 version 17.6.6. This seems related to an incompatibility between the MSVC runtime libraries shipped with MATLAB R2023b and MuJoCo 3.x.

**Workaround:** Replace the following DLLs in your MATLAB installation's `bin/win64` directory (e.g., `C:\Program Files\Matlab\R2023b\bin\win64`) with the corresponding versions from a local Microsoft Visual Studio 2022 (Professional or Community) installation (usually found under `C:\Program Files\Microsoft Visual Studio\2022\<Edition>\VC\Redist\MSVC\<version>\x64\Microsoft.VC143.CRT`):
*   `msvcp140.dll`
*   `msvcp140_1.dll`
*   `msvcp140_2.dll`
*   `msvcp140_atomic_wait.dll`
*   `msvcp140_codecvt_ids.dll`
*   `vcruntime140.dll` (Also recommended to replace)
*   `vcruntime140_1.dll` (Also recommended to replace)

**Disclaimer:** Modifying your MATLAB installation files is done at your own risk. Ensure you back up the original files before replacing them. This workaround might need adjustment depending on specific VS 2022 and MATLAB versions.

### Rebuild GLFW From Source 

In case MATLAB crashes while running getting started model and you see the following lines in stack trace,

`#10 0x00007fdaf8619f40 in glfwCreateWindow () at /lib/x86_64-linux-gnu/libglfw.so.3`

`#11 0x00007fdaf8675c4d in MujocoGUI::initInThread(offscreenSize*, bool)`,

Updating glfw could fix the issue.

Building glfw from source ([glfw main - commit id](https://github.com/glfw/glfw/tree/46cebb5081820418f2a20f3e90b07f9b1bd44b42)) and installing fixed this issue for me,
- sudo apt remove libglfw3 libglfw3-dev # Remove existing glfw
- mkdir ~/glfwupdated
- cd ~/gflwupdated
- git clone git@github.com:glfw/glfw.git
- sudo apt install cmake-qt-gui
- cmake-gui
- Set the source directory to the root of cloned repo
- mkdir build in the cloned repo
- Set the build directory
- In Cmake Gui settings - Select "BUILD_SHARED_LIBS" as well
- Configure and then generate
- Open a terminal in the build directory and run $make in terminal
- Once build goes through without any error, run $sudo make install in terminal
- sudo ldconfig (to refresh linker cache)
- Follow the build instructions for mujoco-simulink-blockset

## License

The license is available in the license.txt file within this repository. Similiar to BSD or MIT.

## Acknowledgments
For this fork, reference the repository and release or commit used:

Simulink Blockset for MuJoCo Simulator (https://github.com/turboboost17/mujoco-simulink-blockset), GitHub. Retrieved date.

This repository builds on the original MathWorks Robotics blockset:

Manoj Velmurugan. Simulink Blockset for MuJoCo Simulator (https://github.com/mathworks-robotics/mujoco-simulink-blockset), GitHub. Retrieved date.


Refer to the [MuJoCo repository](https://github.com/deepmind/mujoco) for guidelines on citing the MuJoCo physics engine.

The sample codes and API documentation provided for [MuJoCo](https://mujoco.readthedocs.io/en/latest/overview.html) and [GLFW](https://www.glfw.org/documentation) were used as reference material during development.

MuJoCo and GLFW libraries are dynamically linked against the S-Function and are required for running this blockset.

UR5e MJCF XML from [MuJoCo Menagerie](https://github.com/deepmind/mujoco_menagerie/tree/main/universal_robots_ur5e) was used for creating demo videos.

