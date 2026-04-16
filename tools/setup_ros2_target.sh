#!/bin/bash
# SETUP_ROS2_TARGET Install MuJoCo and GLFW dependencies on a ROS2 target device.
#
# Usage:
#   ./setup_ros2_target.sh [MUJOCO_SO_PATH]
#
# This script installs the system packages required for building and running
# Simulink-generated ROS2 nodes that use the MuJoCo blockset:
#   - libglfw3-dev (GLFW headers and shared library)
#   - libgl-dev    (OpenGL headers and shared library)
#
# If a path to libmujoco.so is provided, it is installed to /usr/local/lib
# and ldconfig is run to update the dynamic linker cache.
#
# Supported architectures: x86_64 (amd64), aarch64 (arm64)
# Supported targets: Remote device (Raspberry Pi, Jetson), WSL2, Docker container
#
# Copyright 2024-2026 The MathWorks, Inc.

set -euo pipefail

MUJOCO_SO="${1:-}"
ARCH=$(uname -m)

echo "=== MuJoCo-Simulink ROS2 Target Setup ==="
echo "Architecture: $ARCH"
echo "Hostname:     $(hostname)"
echo ""

# Validate architecture
case "$ARCH" in
    x86_64|aarch64)
        echo "Supported architecture detected."
        ;;
    *)
        echo "WARNING: Unsupported architecture '$ARCH'. Proceeding anyway."
        ;;
esac

# Install system packages
echo ""
echo "=== Installing system packages ==="
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    libglfw3-dev \
    libgl-dev \
    build-essential \
    cmake

echo "GLFW and OpenGL development packages installed."

# Verify GLFW installation
if pkg-config --exists glfw3 2>/dev/null; then
    GLFW_VER=$(pkg-config --modversion glfw3)
    echo "GLFW version: $GLFW_VER"
else
    echo "WARNING: pkg-config cannot find glfw3. Build may fail."
fi

# Install MuJoCo shared library if provided
if [ -n "$MUJOCO_SO" ]; then
    echo ""
    echo "=== Installing MuJoCo shared library ==="

    if [ ! -f "$MUJOCO_SO" ]; then
        echo "ERROR: File not found: $MUJOCO_SO"
        exit 1
    fi

    # Copy to /usr/local/lib and create symlinks
    BASENAME=$(basename "$MUJOCO_SO")
    sudo cp "$MUJOCO_SO" /usr/local/lib/
    sudo chmod 644 "/usr/local/lib/$BASENAME"

    # Create version-agnostic symlink: libmujoco.so.3.4.0 -> libmujoco.so
    if [[ "$BASENAME" =~ ^libmujoco\.so\..+ ]]; then
        sudo ln -sf "/usr/local/lib/$BASENAME" /usr/local/lib/libmujoco.so
        echo "Created symlink: libmujoco.so -> $BASENAME"
    fi

    sudo ldconfig
    echo "MuJoCo shared library installed to /usr/local/lib/"

    # Verify
    if ldconfig -p | grep -q libmujoco; then
        echo "Verified: libmujoco found in ldconfig cache."
    else
        echo "WARNING: libmujoco not found in ldconfig cache."
    fi
else
    echo ""
    echo "=== MuJoCo shared library ==="
    echo "No MuJoCo .so path provided."
    echo "The Simulink deployment archive will bundle libmujoco.so automatically."
    echo "If you need to install it manually:"
    echo "  ./setup_ros2_target.sh /path/to/libmujoco.so.3.4.0"
fi

# Install MuJoCo headers if not present
if [ ! -d /usr/local/include/mujoco ]; then
    echo ""
    echo "NOTE: MuJoCo headers not found at /usr/local/include/mujoco/"
    echo "Headers are bundled in the Simulink deployment archive."
    echo "No manual header installation is needed."
fi

echo ""
echo "=== Setup Complete ==="
echo "Target device is ready for MuJoCo-Simulink ROS2 builds."
echo ""
echo "Next steps:"
echo "  1. In MATLAB, run: install('ros2')      % prefetch Linux MuJoCo binaries"
echo "  2. In Simulink, click: Build Model       % generates .tgz and deploys"
echo "  3. On target, run:  colcon build          % (automatic if BuildAction='Build and load')"
