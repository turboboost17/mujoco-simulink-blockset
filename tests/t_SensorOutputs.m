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
            % Loading a model with mujoco block should cause the base
            % workspace sensorBus variable to be defined during mask init.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath);
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            set_param(modelName, 'SimulationCommand', 'update');

            inBase = evalin('base', 'exist(''sensorBus'',''var'')==1');
            testCase.verifyTrue(inBase, 'sensorBus should be defined in base after mask init');
        end
    end
end
