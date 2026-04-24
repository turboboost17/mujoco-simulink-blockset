classdef t_SensorOutputs < matlab.unittest.TestCase
    % Validate sensor bus parsing and sensor port hooks.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'Core','SensorOutputs'})

        function sensorParserExists(testCase)
            testCase.verifyEqual(exist('mj_sensor_parser','file'), 2, ...
                'mj_sensor_parser should be on the path');
        end

        function sensorBusVariableSet(testCase)
            % After mask init, znear/zfar/sampleTime should be in base
            % and the parser block's OutputBusName should reference a
            % mj_bus_sensor_* bus object in base.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath);
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            set_param(modelName, 'SimulationCommand', 'update');

            testCase.verifyTrue( ...
                evalin('base', 'exist(''znear'',''var'')==1'), ...
                'znear should be assigned in base workspace by mask init');
            testCase.verifyTrue( ...
                evalin('base', 'exist(''zfar'',''var'')==1'), ...
                'zfar should be assigned in base workspace by mask init');
            testCase.verifyTrue( ...
                evalin('base', 'exist(''sampleTime'',''var'')==1'), ...
                'sampleTime should be assigned in base workspace by mask init');
        end
    end
end
