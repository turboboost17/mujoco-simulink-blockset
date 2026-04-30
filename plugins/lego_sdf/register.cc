#include <mujoco/mjplugin.h>

#include "lego_brick.h"

namespace mujoco::plugin::lego_sdf {

mjPLUGIN_LIB_INIT(lego_sdf) {
  LegoBrick::RegisterPlugin();
}

}  // namespace mujoco::plugin::lego_sdf