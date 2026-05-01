#include <cstdio>

#include <mujoco/mujoco.h>

int main(int argc, char** argv) {
  if (argc != 3) {
    std::fprintf(stderr, "usage: brick_sdf_smoke <plugin_dir> <model.xml>\n");
    return 2;
  }

  const char* pluginDir = argv[1];
  const char* xmlPath = argv[2];

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

  for (int stepIndex = 0; stepIndex < 4; ++stepIndex) {
    mj_step(model, data);
  }

  std::printf("registered_slot=%d ngeom=%lld nmesh=%lld time=%.6f\n",
              pluginSlot, static_cast<long long>(model->ngeom),
              static_cast<long long>(model->nmesh), data->time);

  mj_deleteData(data);
  mj_deleteModel(model);
  return 0;
}