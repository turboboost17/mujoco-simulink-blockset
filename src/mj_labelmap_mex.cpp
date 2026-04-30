#include "mex.hpp"
#include "mexAdapter.hpp"
#include "MatlabDataArray.hpp"
#include "mj.hpp"
#include <string>

// mj_labelmap_mex  Load MJCF model and return scene-level segid mapping.
//
//   [geomNames, bodyNames, ngeom, geomBodyIds, nbody, ...
//    segIds, segObjTypes, segObjIds, segNames, nscenegeom] = mj_labelmap_mex(xmlPath)
//
// Loads an MJCF XML file via mj_loadXML, builds the abstract scene with
// mjv_updateScene (same code path as runtime), then reads back the segid
// assigned to each scene geom.
//
// MuJoCo segmentation (mjRND_SEGMENT + mjRND_IDCOLOR) encodes the segid
// field of each mjvGeom as:  pixel_color = segid + 1.
// The segid is NOT the model geom index -- it is the position in the
// mjvScene.geoms[] array, assigned during mjv_updateScene/mjv_addGeoms.
//
// Outputs 1-5: model-level information (unchanged from before).
// Outputs 6-10: scene-level segid mapping (the correct IDs for decoding
//               segmentation images).
//
// Inputs
//   xmlPath      - char or string, absolute path to top-level MJCF XML.
//
// Outputs
//   geomNames    - ngeom-by-1 cell of char (model geom names)
//   bodyNames    - ngeom-by-1 cell of char (parent body names)
//   ngeom        - double scalar, total model geoms
//   geomBodyIds  - ngeom-by-1 double (model body index per geom)
//   nbody        - double scalar, total model bodies
//   segIds       - nscenegeom-by-1 double (segid for each scene geom)
//   segObjTypes  - nscenegeom-by-1 double (mjOBJ_GEOM=5, etc.)
//   segObjIds    - nscenegeom-by-1 double (model-level object id)
//   segNames     - nscenegeom-by-1 cell of char (name for each scene geom)
//   nscenegeom   - double scalar, number of scene geoms

class MexFunction : public matlab::mex::Function
{
private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
    matlab::data::ArrayFactory af;

    void error(const std::string& message) {
        matlabPtr->feval(u"error", 0,
            std::vector<matlab::data::Array>({af.createScalar(message)}));
    }

public:
    void operator()(matlab::mex::ArgumentList outputs,
                    matlab::mex::ArgumentList inputs)
    {
        // --- validate input --------------------------------------------------
        if (inputs.size() != 1) {
            error("One input required: path to MJCF XML file");
        }

        std::string xmlPath;
        if (inputs[0].getType() == matlab::data::ArrayType::MATLAB_STRING) {
            matlab::data::StringArray sa = inputs[0];
            xmlPath = std::string(sa[0]);
        } else if (inputs[0].getType() == matlab::data::ArrayType::CHAR) {
            matlab::data::CharArray ca = inputs[0];
            xmlPath = ca.toAscii();
        } else {
            error("Input must be a string or char (path to MJCF XML file)");
        }

        // --- load model ------------------------------------------------------
        char err[1000] = "";
        mjModel* m = mj_loadXMLWithPlugins(xmlPath, nullptr, err, 1000);
        if (!m) {
            error(std::string("mj_loadXML failed: ") + err);
        }

        int ngeom = m->ngeom;
        int nbody = m->nbody;

        // --- build model-level output cell arrays ----------------------------
        auto geomNames = af.createCellArray(
            {static_cast<size_t>(ngeom), 1});
        auto bodyNames = af.createCellArray(
            {static_cast<size_t>(ngeom), 1});
        auto geomBodyIds = af.createArray<double>(
            {static_cast<size_t>(ngeom), 1});

        for (int i = 0; i < ngeom; i++) {
            const char* gn = mj_id2name(m, mjOBJ_GEOM, i);
            geomNames[i][0] = af.createCharArray(
                (gn && gn[0] != '\0') ? gn : "");

            int bid = m->geom_bodyid[i];
            geomBodyIds[i] = static_cast<double>(bid);
            const char* bn = mj_id2name(m, mjOBJ_BODY, bid);
            bodyNames[i][0] = af.createCharArray(
                (bn && bn[0] != '\0') ? bn : "");
        }

        // --- build scene and get segid mapping (outputs 6-10) ----------------
        int nscenegeom = 0;
        matlab::data::CellArray segNames = af.createCellArray({1, 1});
        matlab::data::TypedArray<double> segIdsArr = af.createArray<double>({1, 1});
        matlab::data::TypedArray<double> segObjTypesArr = af.createArray<double>({1, 1});
        matlab::data::TypedArray<double> segObjIdsArr = af.createArray<double>({1, 1});

        if (outputs.size() >= 6) {
            // Create data and compute forward kinematics for initial pose
            mjData* d = mj_makeData(m);
            if (d) {
                mj_forward(m, d);

                // Allocate abstract scene (no OpenGL needed)
                mjvScene scn;
                mjv_defaultScene(&scn);
                mjv_makeScene(m, &scn, 2000);

                // Default options and camera (matches mj.cpp runtime)
                mjvOption opt;
                mjv_defaultOption(&opt);

                mjvCamera cam;
                mjv_defaultCamera(&cam);
                // Use free camera looking at model center
                cam.type = mjCAMERA_FREE;
                for (int i = 0; i < 3; i++) {
                    cam.lookat[i] = m->stat.center[i];
                }
                cam.distance = m->stat.extent * 1.5;

                // Build scene with ALL categories (same as mj.cpp)
                mjv_updateScene(m, d, &opt, nullptr, &cam, mjCAT_ALL, &scn);

                nscenegeom = scn.ngeom;

                // Build output arrays
                segIdsArr = af.createArray<double>(
                    {static_cast<size_t>(nscenegeom), 1});
                segObjTypesArr = af.createArray<double>(
                    {static_cast<size_t>(nscenegeom), 1});
                segObjIdsArr = af.createArray<double>(
                    {static_cast<size_t>(nscenegeom), 1});
                segNames = af.createCellArray(
                    {static_cast<size_t>(nscenegeom), 1});

                for (int i = 0; i < nscenegeom; i++) {
                    const mjvGeom& sg = scn.geoms[i];
                    segIdsArr[i] = static_cast<double>(sg.segid);
                    segObjTypesArr[i] = static_cast<double>(sg.objtype);
                    segObjIdsArr[i] = static_cast<double>(sg.objid);

                    // Build a human-readable name
                    std::string name;
                    if (sg.objtype == mjOBJ_GEOM && sg.objid >= 0 && sg.objid < ngeom) {
                        const char* gn = mj_id2name(m, mjOBJ_GEOM, sg.objid);
                        int bid = m->geom_bodyid[sg.objid];
                        const char* bn = mj_id2name(m, mjOBJ_BODY, bid);

                        std::string gname = (gn && gn[0]) ? gn : ("geom_" + std::to_string(sg.objid));
                        std::string bname = (bn && bn[0]) ? bn : (bid == 0 ? "world" : "");

                        if (!bname.empty()) {
                            name = bname + "/" + gname;
                        } else {
                            name = gname;
                        }
                    } else {
                        // Non-geom scene objects (sites, tendons, decor, etc.)
                        const char* typeName = mju_type2Str(sg.objtype);
                        name = std::string(typeName ? typeName : "unknown") +
                               "_" + std::to_string(sg.objid);
                    }
                    segNames[i][0] = af.createCharArray(name);
                }

                mjv_freeScene(&scn);
                mj_deleteData(d);
            }
        }

        // --- clean up --------------------------------------------------------
        mj_deleteModel(m);

        // --- return ----------------------------------------------------------
        outputs[0] = std::move(geomNames);
        if (outputs.size() >= 2) outputs[1] = std::move(bodyNames);
        if (outputs.size() >= 3) outputs[2] = af.createScalar<double>(
                                                   static_cast<double>(ngeom));
        if (outputs.size() >= 4) outputs[3] = std::move(geomBodyIds);
        if (outputs.size() >= 5) outputs[4] = af.createScalar<double>(
                                                   static_cast<double>(nbody));
        if (outputs.size() >= 6) outputs[5] = std::move(segIdsArr);
        if (outputs.size() >= 7) outputs[6] = std::move(segObjTypesArr);
        if (outputs.size() >= 8) outputs[7] = std::move(segObjIdsArr);
        if (outputs.size() >= 9) outputs[8] = std::move(segNames);
        if (outputs.size() >= 10) outputs[9] = af.createScalar<double>(
                                                    static_cast<double>(nscenegeom));
    }
};
