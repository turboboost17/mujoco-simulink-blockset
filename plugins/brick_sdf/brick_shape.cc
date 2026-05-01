#include "brick_shape.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <optional>
#include <utility>

#include <mujoco/mjplugin.h>
#include <mujoco/mujoco.h>

namespace mujoco::plugin::brick_sdf {
namespace {

constexpr mjtNum kMetersToMillimeters = 1000.0;
constexpr mjtNum kMillimetersToMeters = 0.001;
constexpr mjtNum kStudPitch = 8.0;
constexpr mjtNum kStudRadius = 2.4;
constexpr mjtNum kStudHeight = 1.8;
constexpr mjtNum kBodyClearance = 0.2;
constexpr mjtNum kPlateHeight = 3.2;
constexpr mjtNum kRoundRadius = 0.1;
constexpr mjtNum kStudRoundRadius = 0.12;
constexpr mjtNum kSocketRadius = 2.6;
constexpr mjtNum kSocketDepth = 2.1;
constexpr mjtNum kSocketOpenExtension = 0.4;
constexpr mjtNum kSocketRoundRadius = 0.12;
constexpr mjtNum kMinimumSocketRoofThickness = 1.3;
constexpr mjtNum kMinimumSize = 0.05;
constexpr int kMaximumStudCount = 32;

struct BrickSpec {
  int studX;
  int studY;
  int height;
  mjtNum bodyX;
  mjtNum bodyY;
  mjtNum bodyZ;
};

mjtNum ParseAttributeValue(const char* value, mjtNum fallback) {
  if (!value || value[0] == '\0') {
    return fallback;
  }

  char* parseEnd = nullptr;
  mjtNum parsed = static_cast<mjtNum>(std::strtod(value, &parseEnd));
  if (parseEnd == value || !std::isfinite(parsed)) {
    return fallback;
  }

  while (parseEnd && *parseEnd != '\0') {
    if (!std::isspace(static_cast<unsigned char>(*parseEnd))) {
      return fallback;
    }
    ++parseEnd;
  }

  return parsed;
}

int RoundAndClampCount(mjtNum value, int minimum, int maximum) {
  if (!std::isfinite(value)) {
    return minimum;
  }
  int rounded = static_cast<int>(std::lround(value));
  return std::clamp(rounded, minimum, maximum);
}

BrickSpec MakeSpec(const mjtNum attributes[BrickAttribute::nattribute]) {
  BrickSpec spec{};
  spec.studX = RoundAndClampCount(attributes[0], 1, kMaximumStudCount);
  spec.studY = RoundAndClampCount(attributes[1], 1, kMaximumStudCount);
  spec.height = RoundAndClampCount(attributes[2], 1, 3);
  spec.bodyX = kStudPitch * spec.studX - kBodyClearance;
  spec.bodyY = kPlateHeight * spec.height;
  spec.bodyZ = kStudPitch * spec.studY - kBodyClearance;
  return spec;
}

void ParseAttributes(mjtNum attribute[BrickAttribute::nattribute],
           const char* const values[BrickAttribute::nattribute]) {
  for (int attributeIndex = 0;
     attributeIndex < BrickAttribute::nattribute;
       ++attributeIndex) {
    attribute[attributeIndex] = ParseAttributeValue(
        values ? values[attributeIndex] : nullptr,
    BrickAttribute::defaults[attributeIndex]);
  }

  BrickSpec spec = MakeSpec(attribute);
  attribute[0] = static_cast<mjtNum>(spec.studX);
  attribute[1] = static_cast<mjtNum>(spec.studY);
  attribute[2] = static_cast<mjtNum>(spec.height);
}

mjtNum Length2(mjtNum first, mjtNum second) {
  return std::sqrt(first * first + second * second);
}

mjtNum Length3(mjtNum first, mjtNum second, mjtNum third) {
  return std::sqrt(first * first + second * second + third * third);
}

mjtNum MaxComponent3(mjtNum first, mjtNum second, mjtNum third) {
  return std::max(first, std::max(second, third));
}

mjtNum SdBox(const mjtNum point[3], const mjtNum halfExtents[3]) {
  mjtNum deltaX = std::abs(point[0]) - halfExtents[0];
  mjtNum deltaY = std::abs(point[1]) - halfExtents[1];
  mjtNum deltaZ = std::abs(point[2]) - halfExtents[2];

  mjtNum outsideX = std::max(deltaX, static_cast<mjtNum>(0));
  mjtNum outsideY = std::max(deltaY, static_cast<mjtNum>(0));
  mjtNum outsideZ = std::max(deltaZ, static_cast<mjtNum>(0));
  mjtNum outside = Length3(outsideX, outsideY, outsideZ);
  mjtNum inside = std::min(MaxComponent3(deltaX, deltaY, deltaZ),
                           static_cast<mjtNum>(0));
  return outside + inside;
}

mjtNum SdRoundBox(const mjtNum point[3], const mjtNum halfExtents[3],
                  mjtNum radius) {
  mjtNum roundedHalfExtents[3] = {
      std::max(halfExtents[0] - radius, kMinimumSize),
      std::max(halfExtents[1] - radius, kMinimumSize),
      std::max(halfExtents[2] - radius, kMinimumSize)};
  return SdBox(point, roundedHalfExtents) - radius;
}

mjtNum SdRoundedCylinderY(const mjtNum point[3], mjtNum radius,
                          mjtNum halfHeight, mjtNum roundRadius) {
  mjtNum clampedRoundRadius = std::min(
      std::min(roundRadius, radius - kMinimumSize), halfHeight - kMinimumSize);
  clampedRoundRadius = std::max(clampedRoundRadius, static_cast<mjtNum>(0));
  mjtNum radial = Length2(point[0], point[2]) - (radius - clampedRoundRadius);
  mjtNum axial = std::abs(point[1]) - (halfHeight - clampedRoundRadius);
  mjtNum outsideRadial = std::max(radial, static_cast<mjtNum>(0));
  mjtNum outsideAxial = std::max(axial, static_cast<mjtNum>(0));
  mjtNum outside = Length2(outsideRadial, outsideAxial);
  mjtNum inside = std::min(std::max(radial, axial), static_cast<mjtNum>(0));
  return outside + inside - clampedRoundRadius;
}

mjtNum NearestGridCoordinate(mjtNum value, int count, mjtNum pitch) {
  mjtNum firstCoordinate = -0.5 * static_cast<mjtNum>(count - 1) * pitch;
  mjtNum nearestIndex = std::round((value - firstCoordinate) / pitch);
  nearestIndex = std::clamp(nearestIndex, static_cast<mjtNum>(0),
                            static_cast<mjtNum>(count - 1));
  return firstCoordinate + nearestIndex * pitch;
}

mjtNum BodyDistance(const mjtNum pointMillimeters[3], const BrickSpec& spec) {
  mjtNum outerHalf[3] = {0.5 * spec.bodyX, 0.5 * spec.bodyY,
                         0.5 * spec.bodyZ};
  return SdRoundBox(pointMillimeters, outerHalf, kRoundRadius);
}

mjtNum TopStudDistance(const mjtNum pointMillimeters[3], const BrickSpec& spec) {
  mjtNum studCenterX = NearestGridCoordinate(pointMillimeters[0], spec.studX,
                                             kStudPitch);
  mjtNum studCenterZ = NearestGridCoordinate(pointMillimeters[2], spec.studY,
                                             kStudPitch);
  mjtNum studCenterY = 0.5 * spec.bodyY + 0.5 * kStudHeight;
  mjtNum studPoint[3] = {pointMillimeters[0] - studCenterX,
                         pointMillimeters[1] - studCenterY,
                         pointMillimeters[2] - studCenterZ};
  return SdRoundedCylinderY(studPoint, kStudRadius, 0.5 * kStudHeight,
                            kStudRoundRadius);
}

mjtNum BottomSocketDistance(const mjtNum pointMillimeters[3],
                            const BrickSpec& spec) {
  mjtNum maxSocketDepth =
      std::max(spec.bodyY - kMinimumSocketRoofThickness,
               static_cast<mjtNum>(0));
  mjtNum socketDepth = std::min(kSocketDepth, maxSocketDepth);
  if (socketDepth <= kMinimumSize) {
    return std::numeric_limits<mjtNum>::max();
  }

  mjtNum socketCenterX = NearestGridCoordinate(pointMillimeters[0], spec.studX,
                                               kStudPitch);
  mjtNum socketCenterZ = NearestGridCoordinate(pointMillimeters[2], spec.studY,
                                               kStudPitch);
  mjtNum socketHeight = socketDepth + kSocketOpenExtension;
  mjtNum socketCenterY = -0.5 * spec.bodyY + 0.5 * socketDepth -
                         0.5 * kSocketOpenExtension;
  mjtNum socketPoint[3] = {pointMillimeters[0] - socketCenterX,
                           pointMillimeters[1] - socketCenterY,
                           pointMillimeters[2] - socketCenterZ};
  return SdRoundedCylinderY(socketPoint, kSocketRadius, 0.5 * socketHeight,
                            kSocketRoundRadius);
}

mjtNum DistanceMillimeters(const mjtNum pointMeters[3],
                           const mjtNum attributes[BrickAttribute::nattribute]) {
  BrickSpec spec = MakeSpec(attributes);
  mjtNum pointMillimeters[3] = {pointMeters[0] * kMetersToMillimeters,
                                pointMeters[1] * kMetersToMillimeters,
                                pointMeters[2] * kMetersToMillimeters};

  mjtNum shape = BodyDistance(pointMillimeters, spec);
  shape = std::min(shape, TopStudDistance(pointMillimeters, spec));
  shape = std::max(shape, -BottomSocketDistance(pointMillimeters, spec));
  return shape;
}

void FillAabb(mjtNum aabb[6],
              const mjtNum attributes[BrickAttribute::nattribute]) {
  BrickSpec spec = MakeSpec(attributes);
  constexpr mjtNum margin = 0.5 * kMillimetersToMeters;
  aabb[0] = 0;
  aabb[1] = 0.5 * kStudHeight * kMillimetersToMeters;
  aabb[2] = 0;
  aabb[3] = 0.5 * spec.bodyX * kMillimetersToMeters + margin;
  aabb[4] = 0.5 * (spec.bodyY + kStudHeight) * kMillimetersToMeters + margin;
  aabb[5] = 0.5 * spec.bodyZ * kMillimetersToMeters + margin;
}

}  // namespace

std::optional<BrickShape> BrickShape::Create(const mjModel* model, mjData* data,
                                             int instance) {
  (void)data;
  return BrickShape(model, instance);
}

BrickShape::BrickShape(const mjModel* model, int instance) {
  const char* values[BrickAttribute::nattribute] = {};
  for (int attributeIndex = 0;
       attributeIndex < BrickAttribute::nattribute;
       ++attributeIndex) {
    values[attributeIndex] = mj_getPluginConfig(
        model, instance, BrickAttribute::names[attributeIndex]);
  }
  ParseAttributes(attribute, values);
}

mjtNum BrickShape::Distance(const mjtNum point[3]) const {
  return DistanceMillimeters(point, attribute) * kMillimetersToMeters;
}

void BrickShape::Gradient(mjtNum gradient[3], const mjtNum point[3]) const {
  constexpr mjtNum epsilon = 1e-6;

  for (int axis = 0; axis < 3; ++axis) {
    mjtNum plus[3] = {point[0], point[1], point[2]};
    mjtNum minus[3] = {point[0], point[1], point[2]};
    plus[axis] += epsilon;
    minus[axis] -= epsilon;
    gradient[axis] = (Distance(plus) - Distance(minus)) / (2 * epsilon);
  }
}

void BrickShape::RegisterPlugin() {
  mjpPlugin plugin;
  mjp_defaultPlugin(&plugin);

  plugin.name = "mujoco.sdf.brick";
  plugin.capabilityflags |= mjPLUGIN_SDF;
  plugin.nattribute = BrickAttribute::nattribute;
  plugin.attributes = BrickAttribute::names;
  plugin.nstate = +[](const mjModel* model, int instance) {
    (void)model;
    (void)instance;
    return 0;
  };
  plugin.init = +[](const mjModel* model, mjData* data, int instance) {
    auto brickOrNull = BrickShape::Create(model, data, instance);
    if (!brickOrNull.has_value()) {
      return -1;
    }
    data->plugin_data[instance] = reinterpret_cast<uintptr_t>(
        new BrickShape(std::move(*brickOrNull)));
    return 0;
  };
  plugin.destroy = +[](mjData* data, int instance) {
    delete reinterpret_cast<BrickShape*>(data->plugin_data[instance]);
    data->plugin_data[instance] = 0;
  };
  plugin.reset = +[](const mjModel* model, mjtNum* pluginState,
                     void* pluginData, int instance) {
    (void)model;
    (void)pluginState;
    (void)pluginData;
    (void)instance;
  };
  plugin.compute = +[](const mjModel* model, mjData* data, int instance,
                       int capabilityBit) {
    (void)model;
    (void)data;
    (void)instance;
    (void)capabilityBit;
  };
  plugin.sdf_distance = +[](const mjtNum point[3], const mjData* data,
                            int instance) {
    auto* brick = reinterpret_cast<BrickShape*>(data->plugin_data[instance]);
    return brick->Distance(point);
  };
  plugin.sdf_gradient = +[](mjtNum gradient[3], const mjtNum point[3],
                            const mjData* data, int instance) {
    auto* brick = reinterpret_cast<BrickShape*>(data->plugin_data[instance]);
    brick->Gradient(gradient, point);
  };
  plugin.sdf_staticdistance = +[](const mjtNum point[3],
                                  const mjtNum* attributes) {
    return DistanceMillimeters(point, attributes) * kMillimetersToMeters;
  };
  plugin.sdf_aabb = +[](mjtNum aabb[6], const mjtNum* attributes) {
    FillAabb(aabb, attributes);
  };
  plugin.sdf_attribute = +[](mjtNum attribute[], const char* names[],
                             const char* values[]) {
    (void)names;
    ParseAttributes(attribute, values);
  };

  mjp_registerPlugin(&plugin);
}

}  // namespace mujoco::plugin::brick_sdf