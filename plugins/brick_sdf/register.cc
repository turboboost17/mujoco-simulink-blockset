#include <mujoco/mjplugin.h>

#include "brick_shape.h"

namespace mujoco::plugin::brick_sdf {

mjPLUGIN_LIB_INIT(brick_sdf) {
  BrickShape::RegisterPlugin();
}

}  // namespace mujoco::plugin::brick_sdf