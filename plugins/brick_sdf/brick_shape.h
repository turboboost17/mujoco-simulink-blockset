#pragma once

#include <optional>

#include <mujoco/mjdata.h>
#include <mujoco/mjmodel.h>
#include <mujoco/mjtnum.h>

namespace mujoco::plugin::brick_sdf {

struct BrickAttribute {
  static constexpr int nattribute = 3;
  static constexpr char const* names[nattribute] = {
      "stud_x", "stud_y", "height"};
  static constexpr mjtNum defaults[nattribute] = {4, 2, 3};
};

class BrickShape {
 public:
  static std::optional<BrickShape> Create(const mjModel* model, mjData* data,
                                          int instance);
  BrickShape(BrickShape&&) = default;
  ~BrickShape() = default;

  mjtNum Distance(const mjtNum point[3]) const;
  void Gradient(mjtNum gradient[3], const mjtNum point[3]) const;

  static void RegisterPlugin();

  mjtNum attribute[BrickAttribute::nattribute];

 private:
  BrickShape(const mjModel* model, int instance);
};

}  // namespace mujoco::plugin::brick_sdf