#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>

#include <mujoco/mujoco.h>

namespace {

double Norm3(const mjtNum* value) {
  return std::sqrt(static_cast<double>(value[0] * value[0] +
                                      value[1] * value[1] +
                                      value[2] * value[2]));
}

double Distance3(const mjtNum* first, const mjtNum* second) {
  double delta[3] = {static_cast<double>(first[0] - second[0]),
                     static_cast<double>(first[1] - second[1]),
                     static_cast<double>(first[2] - second[2])};
  return std::sqrt(delta[0] * delta[0] + delta[1] * delta[1] +
                   delta[2] * delta[2]);
}

double QuaternionDistance(const mjtNum* first, const mjtNum* second) {
  double dot = std::abs(static_cast<double>(first[0] * second[0] +
                                           first[1] * second[1] +
                                           first[2] * second[2] +
                                           first[3] * second[3]));
  dot = std::clamp(dot, 0.0, 1.0);
  return 2.0 * std::acos(dot);
}

int MaxSolverIterations(const mjData* data) {
  int maxIterations = 0;
  int islandCount = std::max(data->nisland, 1);
  for (int island = 0; island < islandCount && island < mjNISLAND; ++island) {
    maxIterations = std::max(maxIterations, data->solver_niter[island]);
  }
  return maxIterations;
}

bool ContactTouchesBody(const mjModel* model, const mjContact& contact,
                        int bodyId) {
  for (int side = 0; side < 2; ++side) {
    int geomId = contact.geom[side];
    if (geomId >= 0 && model->geom_bodyid[geomId] == bodyId) {
      return true;
    }
  }
  return false;
}

double ParsePositiveDouble(const char* text, double fallback) {
  if (!text) {
    return fallback;
  }
  char* parseEnd = nullptr;
  double value = std::strtod(text, &parseEnd);
  if (parseEnd == text || !std::isfinite(value) || value <= 0) {
    return fallback;
  }
  return value;
}

struct Metrics {
  double rmsLinearSpeed = 0;
  double rmsAngularSpeed = 0;
  double maxLinearSpeed = 0;
  double maxAngularSpeed = 0;
  double finalLinearSpeed = 0;
  double finalAngularSpeed = 0;
  double maxPositionDrift = 0;
  double finalPositionDrift = 0;
  double maxOrientationDrift = 0;
  double finalOrientationDrift = 0;
  double minTargetContactDistance = std::numeric_limits<double>::infinity();
  double meanStepSeconds = 0;
  double maxStepSeconds = 0;
  int settlingSamples = 0;
  int maxTargetContacts = 0;
  int maxTotalContacts = 0;
  int maxConstraints = 0;
  int maxSolverIterations = 0;
  int warningCount = 0;
};

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3 || argc > 6) {
    std::fprintf(stderr,
                 "usage: brick_sdf_stability <plugin_dir> <model.xml> "
                 "[body_name=brick_2] [duration=3] [settle_start=1]\n");
    return 2;
  }

  const char* pluginDir = argv[1];
  const char* xmlPath = argv[2];
  const char* bodyName = argc >= 4 ? argv[3] : "brick_2";
  double duration = argc >= 5 ? ParsePositiveDouble(argv[4], 3.0) : 3.0;
  double settleStart = argc >= 6 ? ParsePositiveDouble(argv[5], 1.0) : 1.0;
  settleStart = std::min(settleStart, duration);

  mj_loadAllPluginLibraries(pluginDir, nullptr);

  int pluginSlot = -1;
  const mjpPlugin* plugin = mjp_getPlugin("mujoco.sdf.brick", &pluginSlot);
  if (!plugin) {
    std::fprintf(stderr, "mujoco.sdf.brick was not registered\n");
    return 3;
  }

  char error[1024] = "";
  mjModel* model = mj_loadXML(xmlPath, nullptr, error, sizeof(error));
  if (!model) {
    std::fprintf(stderr, "mj_loadXML failed: %s\n", error);
    return 4;
  }

  mjData* data = mj_makeData(model);
  if (!data) {
    std::fprintf(stderr, "mj_makeData failed\n");
    mj_deleteModel(model);
    return 5;
  }

  int bodyId = mj_name2id(model, mjOBJ_BODY, bodyName);
  if (bodyId < 0) {
    std::fprintf(stderr, "body not found: %s\n", bodyName);
    mj_deleteData(data);
    mj_deleteModel(model);
    return 6;
  }

  int dofAddress = model->body_dofadr[bodyId];
  int dofCount = model->body_dofnum[bodyId];
  if (dofAddress < 0 || dofCount < 6) {
    std::fprintf(stderr, "body does not have a freejoint-like 6 dof block: %s\n",
                 bodyName);
    mj_deleteData(data);
    mj_deleteModel(model);
    return 7;
  }

  mj_forward(model, data);
  mjtNum initialPosition[3] = {data->xpos[3 * bodyId],
                              data->xpos[3 * bodyId + 1],
                              data->xpos[3 * bodyId + 2]};
  mjtNum initialQuaternion[4] = {data->xquat[4 * bodyId],
                                data->xquat[4 * bodyId + 1],
                                data->xquat[4 * bodyId + 2],
                                data->xquat[4 * bodyId + 3]};

  Metrics metrics;
  int initialWarnings[mjNWARNING] = {};
  for (int warning = 0; warning < mjNWARNING; ++warning) {
    initialWarnings[warning] = data->warning[warning].number;
  }

  int steps = 0;
  auto wallStart = std::chrono::steady_clock::now();
  while (data->time < duration) {
    auto stepStart = std::chrono::steady_clock::now();
    mj_step(model, data);
    auto stepEnd = std::chrono::steady_clock::now();
    double stepSeconds = std::chrono::duration<double>(stepEnd - stepStart).count();
    metrics.meanStepSeconds += stepSeconds;
    metrics.maxStepSeconds = std::max(metrics.maxStepSeconds, stepSeconds);
    ++steps;

    int targetContacts = 0;
    for (int contactIndex = 0; contactIndex < data->ncon; ++contactIndex) {
      const mjContact& contact = data->contact[contactIndex];
      if (ContactTouchesBody(model, contact, bodyId)) {
        ++targetContacts;
        metrics.minTargetContactDistance = std::min(
            metrics.minTargetContactDistance,
            static_cast<double>(contact.dist));
      }
    }

    metrics.maxTargetContacts = std::max(metrics.maxTargetContacts,
                                         targetContacts);
    metrics.maxTotalContacts = std::max(metrics.maxTotalContacts, data->ncon);
    metrics.maxConstraints = std::max(metrics.maxConstraints, data->nefc);
    metrics.maxSolverIterations = std::max(metrics.maxSolverIterations,
                                           MaxSolverIterations(data));

    if (data->time >= settleStart) {
      const mjtNum* qvel = data->qvel + dofAddress;
      double linearSpeed = Norm3(qvel);
      double angularSpeed = Norm3(qvel + 3);
      double positionDrift = Distance3(data->xpos + 3 * bodyId,
                                       initialPosition);
      double orientationDrift = QuaternionDistance(data->xquat + 4 * bodyId,
                                                   initialQuaternion);

      metrics.rmsLinearSpeed += linearSpeed * linearSpeed;
      metrics.rmsAngularSpeed += angularSpeed * angularSpeed;
      metrics.maxLinearSpeed = std::max(metrics.maxLinearSpeed, linearSpeed);
      metrics.maxAngularSpeed = std::max(metrics.maxAngularSpeed, angularSpeed);
      metrics.finalLinearSpeed = linearSpeed;
      metrics.finalAngularSpeed = angularSpeed;
      metrics.maxPositionDrift = std::max(metrics.maxPositionDrift,
                                          positionDrift);
      metrics.finalPositionDrift = positionDrift;
      metrics.maxOrientationDrift = std::max(metrics.maxOrientationDrift,
                                             orientationDrift);
      metrics.finalOrientationDrift = orientationDrift;
      ++metrics.settlingSamples;
    }
  }
  auto wallEnd = std::chrono::steady_clock::now();

  metrics.meanStepSeconds = steps > 0 ? metrics.meanStepSeconds / steps : 0;
  if (metrics.settlingSamples > 0) {
    metrics.rmsLinearSpeed = std::sqrt(metrics.rmsLinearSpeed /
                                       metrics.settlingSamples);
    metrics.rmsAngularSpeed = std::sqrt(metrics.rmsAngularSpeed /
                                        metrics.settlingSamples);
  }
  for (int warning = 0; warning < mjNWARNING; ++warning) {
    metrics.warningCount += data->warning[warning].number - initialWarnings[warning];
  }

  double wallSeconds = std::chrono::duration<double>(wallEnd - wallStart).count();
  double realTimeFactor = wallSeconds > 0 ? data->time / wallSeconds : 0;
  double maxPenetration = std::isfinite(metrics.minTargetContactDistance)
                              ? std::max(0.0, -metrics.minTargetContactDistance)
                              : 0.0;
  double score = 1000.0 * metrics.rmsLinearSpeed +
                 100.0 * metrics.rmsAngularSpeed +
                 1000.0 * metrics.finalPositionDrift +
                 100.0 * metrics.finalOrientationDrift +
                 500.0 * maxPenetration +
                 0.01 * metrics.maxSolverIterations;
  bool pass = metrics.warningCount == 0 &&
              metrics.finalLinearSpeed < 0.01 &&
              metrics.finalAngularSpeed < 0.25 &&
              metrics.rmsLinearSpeed < 0.01 &&
              metrics.rmsAngularSpeed < 0.25 &&
              metrics.finalPositionDrift < 0.004 &&
              metrics.finalOrientationDrift < 0.25 &&
              maxPenetration < 0.003;

  std::printf("registered_slot=%d body=%s body_id=%d duration=%.6f "
              "settle_start=%.6f timestep=%.6f steps=%d\n",
              pluginSlot, bodyName, bodyId, data->time, settleStart,
              model->opt.timestep, steps);
  std::printf("stability_pass=%d score=%.9g real_time_factor=%.6f "
              "mean_step_us=%.3f max_step_us=%.3f\n",
              pass ? 1 : 0, score, realTimeFactor,
              metrics.meanStepSeconds * 1e6, metrics.maxStepSeconds * 1e6);
  std::printf("linear_speed final=%.9g rms=%.9g max=%.9g\n",
              metrics.finalLinearSpeed, metrics.rmsLinearSpeed,
              metrics.maxLinearSpeed);
  std::printf("angular_speed final=%.9g rms=%.9g max=%.9g\n",
              metrics.finalAngularSpeed, metrics.rmsAngularSpeed,
              metrics.maxAngularSpeed);
  std::printf("pose_drift position_final=%.9g position_max=%.9g "
              "orientation_final=%.9g orientation_max=%.9g\n",
              metrics.finalPositionDrift, metrics.maxPositionDrift,
              metrics.finalOrientationDrift, metrics.maxOrientationDrift);
  std::printf("contacts target_max=%d total_max=%d max_penetration=%.9g "
              "constraints_max=%d solver_iter_max=%d warnings=%d\n",
              metrics.maxTargetContacts, metrics.maxTotalContacts,
              maxPenetration, metrics.maxConstraints,
              metrics.maxSolverIterations, metrics.warningCount);
  std::printf("final_position %.9g %.9g %.9g\n",
              data->xpos[3 * bodyId], data->xpos[3 * bodyId + 1],
              data->xpos[3 * bodyId + 2]);

  mj_deleteData(data);
  mj_deleteModel(model);
  return 0;
}