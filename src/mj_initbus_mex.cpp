// This mex function generates a Simulink bus using "Simulink.Bus.createObject"
//  1. The generated bus is named uniquely using std::hash
//  2. If a bus with same name already exists, it will not regenerate
//  3. std::hash is assumed to return unique hash within a MATLAB instance

// MATLAB and Simulink are registered trademarks of The MathWorks, Inc.
// Copyright 2022-2023 The MathWorks, Inc.

#include "mex.hpp"
#include "mexAdapter.hpp"
#include "MatlabDataArray.hpp"
#include "mj.hpp"
#include <iostream>
#include <mutex>

static std::mutex mut;

class MexFunction: public matlab::mex::Function
{
    private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
    std::ostringstream stream;
    matlab::data::ArrayFactory af;

    public:

    void operator()
    (matlab::mex::ArgumentList outputs, matlab::mex::ArgumentList inputs) 
    {
        // serialize this function as it accesses files and base workspace
        // Donot want one call of this function to delete a temporary base workspace variable while another instance is still using it
        
        std::lock_guard<std::mutex> lock(mut);

        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        // Inputs: xmlPath, [optional] camWidths (scalar or vector), [optional] camHeights (scalar or vector)
        if(inputs.size() < 1)
        {
            printError("Expected at least 1 input (xmlPath). Optional: camWidths, camHeights");
        }

        std::string pathStr;
        if(inputs[0].getType() == ArrayType::CHAR)
        {
            CharArray path = inputs[0];
            pathStr = path.toAscii();
        }
        else
        {
            printError("Only char array allowed as first input (xmlPath)");
        }

        // Parse optional camera resolution arrays
        std::vector<int> camWidths;
        std::vector<int> camHeights;
        
        if(inputs.size() >= 2)
        {
            TypedArray<double> widthArr = inputs[1];
            for(auto val : widthArr)
            {
                camWidths.push_back(static_cast<int>(val));
            }
        }
        
        if(inputs.size() >= 3)
        {
            TypedArray<double> heightArr = inputs[2];
            for(auto val : heightArr)
            {
                camHeights.push_back(static_cast<int>(val));
            }
        }

        std::shared_ptr<MujocoModelInstance> mi = std::make_shared<MujocoModelInstance>();
        if(mi->initMdl(pathStr, false, false) != 0)
        {
            printError("Unable to load file");
        }
        mi->cami = cameraBusInterface(mi->get_m(), camWidths, camHeights);

        int outputIndex = 0;

        // input bus
        auto ci = mi->ci;
        std::string controlBusStr = inputBusGen(ci);
        outputs[outputIndex++] = af.createCharArray(controlBusStr);

        // sensor bus
        auto si = mi->si;
        std::string sensorBusStr = sensorBusGen(si);
        outputs[outputIndex++] = af.createCharArray(sensorBusStr);

        // rgb bus
        auto cami = mi->cami;
        std::string rgbBusStr = rgbBusGen(cami);
        outputs[outputIndex++] = af.createCharArray(rgbBusStr);

        // depth bus
        std::string depthBusStr = depthBusGen(cami);
        outputs[outputIndex++] = af.createCharArray(depthBusStr);
        
        // segmentation bus
        std::string segmentationBusStr = segmentationBusGen(cami);
        outputs[outputIndex++] = af.createCharArray(segmentationBusStr);

        // data length output
        ArrayDimensions lengthOutputdim{5, 1};
        outputs[outputIndex++] = af.createArray<uint32_t>(lengthOutputdim, {ci.count, si.scalarCount, cami.rgbLength, cami.depthLength, cami.segLength});

        // displayOnMATLAB(stream);   

    }

    int cameraOverrideValue(const std::vector<int>& values, int camIndex)
    {
        if(values.empty())
        {
            return 0;
        }
        if(values.size() == 1)
        {
            return values[0];
        }
        if(camIndex < static_cast<int>(values.size()))
        {
            return values[camIndex];
        }
        return 0;
    }

    offscreenSize effectiveCameraSize(const mjModel* model, int camIndex, const std::vector<int>& camWidths, const std::vector<int>& camHeights)
    {
        int effWidth = cameraOverrideValue(camWidths, camIndex);
        int effHeight = cameraOverrideValue(camHeights, camIndex);

        if((effWidth <= 0 || effHeight <= 0) && model != nullptr)
        {
            if(camIndex >= 0 && camIndex < model->ncam && model->cam_resolution != nullptr)
            {
                int cameraWidth = model->cam_resolution[2*camIndex + 0];
                int cameraHeight = model->cam_resolution[2*camIndex + 1];
                if(cameraWidth > 0 && cameraHeight > 0)
                {
                    effWidth = cameraWidth;
                    effHeight = cameraHeight;
                }
            }
        }

        if((effWidth <= 0 || effHeight <= 0) && model != nullptr)
        {
            if(model->vis.global.offwidth > 0 && model->vis.global.offheight > 0)
            {
                effWidth = model->vis.global.offwidth;
                effHeight = model->vis.global.offheight;
            }
        }

        if(effWidth <= 0 || effHeight <= 0)
        {
            effWidth = 640;
            effHeight = 480;
        }

        offscreenSize size;
        size.width = static_cast<unsigned>(effWidth);
        size.height = static_cast<unsigned>(effHeight);
        return size;
    }

    cameraInterface cameraBusInterface(const mjModel* model, const std::vector<int>& camWidths, const std::vector<int>& camHeights)
    {
        cameraInterface cami;
        if(model == nullptr || model->ncam <= 0 || model->name_camadr == nullptr || model->names == nullptr)
        {
            return cami;
        }

        cami.count = static_cast<unsigned>(model->ncam);
        unsigned long rgbAddr = 0;
        unsigned long depthAddr = 0;
        unsigned long segAddr = 0;

        for(int camIndex = 0; camIndex < model->ncam; camIndex++)
        {
            char *namePointer = model->names + model->name_camadr[camIndex];
            cami.names.push_back(std::string(namePointer));

            offscreenSize size = effectiveCameraSize(model, camIndex, camWidths, camHeights);
            cami.size.push_back(size);
            cami.rgbAddr.push_back(rgbAddr);
            cami.depthAddr.push_back(depthAddr);
            cami.segAddr.push_back(segAddr);

            rgbAddr += 3*size.height*size.width;
            depthAddr += size.height*size.width;
            segAddr += 3*size.height*size.width;
        }

        cami.rgbLength = rgbAddr;
        cami.depthLength = depthAddr;
        cami.segLength = segAddr;
        return cami;
    }

    std::string sensorBusGen(sensorInterface si)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        if(si.count == 0)
        {
            std::string busStr="mj_bus_sensor_";
            busStr += std::to_string(si.hash());
            return emptyBusGen(busStr);
        }

        // struct generation
        StructArray busStruct = af.createStructArray({1}, si.names);
        for(unsigned int index=0; index<si.count; index++)
        {
            std::string name = si.names[index];
            ArrayDimensions sensorDim{si.dim[index],1};
            busStruct[0][name] = af.createArray<double>(sensorDim);
        }

        // name the bus with a identifier unique to block outputs/inputs
        std::string busStr="mj_bus_sensor_";
        busStr += std::to_string(si.hash());

        return busGen(busStr, busStruct);
    }

    std::string inputBusGen(controlInterface ci)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        if(ci.count == 0)
        {
            std::string busStr="mj_bus_input_";
            busStr += std::to_string(ci.hash());
            return emptyBusGen(busStr);
        }

        // struct generation
        StructArray busStruct = af.createStructArray({1}, ci.names);
        for(unsigned int index=0; index<ci.count; index++)
        {
            std::string name = ci.names[index];
            busStruct[0][name] = af.createArray<double>({1,1});
        }

        // name the bus with a identifier unique to block outputs/inputs
        std::string busStr="mj_bus_input_";
        busStr += std::to_string(ci.hash());

        return busGen(busStr, busStruct);
    }

    std::string rgbBusGen(cameraInterface cami)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        if(cami.count == 0)
        {
            std::string busStr="mj_bus_rgb_";
            busStr += std::to_string(cami.hash());
            return emptyBusGen(busStr);
        }

        // struct generation
        StructArray busStruct = af.createStructArray({1}, cami.names);
        for(unsigned int index=0; index<cami.count; index++)
        {
            std::string name = cami.names[index];
            ArrayDimensions outputDim{cami.size[index].height, cami.size[index].width, 3};
            busStruct[0][name] = af.createArray<uint8_t>(outputDim);
        }

        // name the bus with a identifier unique to block outputs/inputs
        std::string busStr="mj_bus_rgb_";
        busStr += std::to_string(cami.hash());

        return busGen(busStr, busStruct);
    }

    std::string depthBusGen(cameraInterface cami)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        if(cami.count == 0)
        {
            std::string busStr="mj_bus_depth_";
            busStr += std::to_string(cami.hash());
            return emptyBusGen(busStr);
        }

        // struct generation
        StructArray busStruct = af.createStructArray({1}, cami.names);
        for(unsigned int index=0; index<cami.count; index++)
        {
            std::string name = cami.names[index];
            ArrayDimensions outputDim{cami.size[index].height, cami.size[index].width};
            busStruct[0][name] = af.createArray<float>(outputDim);
        }

        // name the bus with a identifier unique to block outputs/inputs
        std::string busStr="mj_bus_depth_";
        busStr += std::to_string(cami.hash());

        return busGen(busStr, busStruct);
    }

    std::string segmentationBusGen(cameraInterface cami)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        if(cami.count == 0)
        {
            std::string busStr="mj_bus_segmentation_";
            busStr += std::to_string(cami.hash());
            return emptyBusGen(busStr);
        }

        // struct generation
        StructArray busStruct = af.createStructArray({1}, cami.names);
        for(unsigned int index=0; index<cami.count; index++)
        {
            std::string name = cami.names[index];
            ArrayDimensions outputDim{cami.size[index].height, cami.size[index].width, 3};
            busStruct[0][name] = af.createArray<uint8_t>(outputDim);
        }

        // name the bus with a identifier unique to block outputs/inputs
        std::string busStr="mj_bus_segmentation_";
        busStr += std::to_string(cami.hash());

        return busGen(busStr, busStruct);
    }

    std::string emptyBusGen(std::string busStr)
    {
        using namespace matlab::data;
        using namespace matlab::engine;

        auto outputStream = std::shared_ptr<matlab::engine::StreamBuffer>();
        auto errorStream = std::shared_ptr<matlab::engine::StreamBuffer>();
        std::vector<matlab::data::Array> emptyArgs;
        auto structVector = matlabPtr->feval(u"struct", 1, emptyArgs, outputStream, errorStream);
        return busGen(busStr, structVector[0]);
    }

    std::string busGen(std::string busStr, matlab::data::Array busStruct)
    {
        using namespace matlab::data;
        using namespace matlab::mex;
        using namespace matlab::engine;

        // bus generation from struct
        auto outputStream = std::shared_ptr<matlab::engine::StreamBuffer>();
        auto errorStream = std::shared_ptr<matlab::engine::StreamBuffer>();

        // check for existence of bus
        std::vector<matlab::data::Array> args({af.createScalar(busStr)});

        std::vector<matlab::data::Array> result;
        result = matlabPtr->feval(u"mj_busExist", 1, args, outputStream, errorStream);

        matlab::data::TypedArray<double> returnedValues(std::move(result[0]));
        double alreadyExistsDouble = returnedValues[0];

        int alreadyExists = static_cast<int>(std::round(alreadyExistsDouble));

        if (!alreadyExists)
        {
            // If exists, do not generate the bus again
            auto arg = std::vector<matlab::data::Array>({busStruct});
            auto outputVector = matlabPtr->feval(u"Simulink.Bus.createObject", 1, arg, outputStream, errorStream);

            matlab::data::StructArray outputStructArray = outputVector[0];

            auto val = outputStructArray[0]["busName"];
            if(val.getType() == ArrayType::CHAR)
            {
                CharArray valChar = val;
                std::string clearCmd = "clear('" + valChar.toAscii() + "');";
                auto busTempVariable = matlabPtr->getVariable(valChar.toAscii(), WorkspaceType::BASE);
                matlabPtr->setVariable(busStr, busTempVariable, WorkspaceType::BASE);
                matlabPtr->eval(convertUTF8StringToUTF16String("evalin base "+clearCmd));
            }
            else
            {
                printError("busName field has to be a char array");
            }
        }
        return busStr;
    }

    void displayOnMATLAB(std::ostringstream& stream) 
    {
        // Pass stream content to MATLAB fprintf function
        matlabPtr->feval(u"fprintf", 0, std::vector<matlab::data::Array>({ af.createScalar(stream.str()) }));
        // Clear stream buffer
        stream.str("");
    }

    void printError(std::string err)
    {
        matlabPtr->feval(u"error", 0,
                std::vector<matlab::data::Array>(
                    { af.createScalar(err) }));
    }

};

