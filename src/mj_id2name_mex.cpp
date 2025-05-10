#include "mex.hpp"
#include "mexAdapter.hpp"
#include "MatlabDataArray.hpp"
#include "mj.hpp"
#include <cstdlib>
#include <string>

// Note: This function relies on the mj.hpp interface

class MexFunction: public matlab::mex::Function
{
private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
    matlab::data::ArrayFactory af;

    void error(const std::string& message) {
        matlabPtr->feval(u"error", 0, 
            std::vector<matlab::data::Array>({af.createScalar(message)}));
    }

public:
    void operator()(matlab::mex::ArgumentList outputs, matlab::mex::ArgumentList inputs) 
    {
        // Check inputs
        if (inputs.size() != 3) {
            error("Three inputs required: model, objectType, and objectID");
        }
        
        // Input 1: Handle to mjModel*
        if (inputs[0].getType() != matlab::data::ArrayType::UINT64 && 
            inputs[0].getType() != matlab::data::ArrayType::INT64) {
            error("First argument must be a pointer to mjModel");
        }
        
        // Input 2: Object type (int)
        if (inputs[1].getType() != matlab::data::ArrayType::DOUBLE || 
            inputs[1].getNumberOfElements() != 1) {
            error("Second argument must be a scalar object type (mjObj)");
        }
        
        // Input 3: Object ID (int)
        if (inputs[2].getType() != matlab::data::ArrayType::DOUBLE || 
            inputs[2].getNumberOfElements() != 1) {
            error("Third argument must be a scalar object ID");
        }
        
        // Extract inputs
        mjModel* m = nullptr;
        if (inputs[0].getType() == matlab::data::ArrayType::UINT64) {
            matlab::data::TypedArray<uint64_t> modelPtr = inputs[0];
            m = reinterpret_cast<mjModel*>(static_cast<uintptr_t>(modelPtr[0]));
        } else {
            matlab::data::TypedArray<int64_t> modelPtr = inputs[0];
            m = reinterpret_cast<mjModel*>(static_cast<uintptr_t>(modelPtr[0]));
        }
        
        matlab::data::TypedArray<double> objTypeArr = inputs[1];
        int objType = static_cast<int>(objTypeArr[0]);
        
        matlab::data::TypedArray<double> objIdArr = inputs[2];
        int objId = static_cast<int>(objIdArr[0]);
        
        // Call MuJoCo API to get the name
        const char* name = mj_id2name(m, objType, objId);
        
        // Create output
        if (name != nullptr) {
            outputs[0] = af.createCharArray(name);
        } else {
            outputs[0] = af.createCharArray("");
        }
    }
};