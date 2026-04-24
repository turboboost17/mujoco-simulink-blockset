classdef t_SegmentationIDs < matlab.unittest.TestCase
    % New-feature tests (from seg repo): scene-level segmentation label map
    % and enhanced mj_segmentation_decoder.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'NewFeature','SegmentationIDs'})

        function labelmapMexExists(testCase)
            testCase.verifyEqual(exist('mj_labelmap_mex','file'), 3, ...
                'mj_labelmap_mex MEX not built');
        end

        function xmlLabelmapReturnsTable(testCase)
            testCase.assumeEqual(exist('mj_xml_labelmap','file'), 2, ...
                'mj_xml_labelmap not on path');
            % Use the bundled test XML model
            xml = which('dummy.xml');
            testCase.assumeNotEmpty(xml);
            try
                t = mj_xml_labelmap(xml);
                testCase.verifyClass(t, 'table');
                testCase.verifyTrue(ismember('ID', t.Properties.VariableNames));
                testCase.verifyTrue(ismember('Name', t.Properties.VariableNames));
            catch me
                testCase.verifyFail(sprintf('mj_xml_labelmap failed: %s', me.message));
            end
        end

        function decoderAcceptsXmlLabelSource(testCase)
            testCase.assumeEqual(exist('mj_segmentation_decoder','file'), 2);
            % Synthesize a tiny seg image: all pixels encode ID=0 -> RGB (1,0,0)
            img = zeros(4,4,3,'uint8');
            img(:,:,1) = 1; % id=0
            xml = which('dummy.xml');
            testCase.assumeNotEmpty(xml);
            try
                [segIDs, segNames, ~] = mj_segmentation_decoder(img, xml);
                testCase.verifyEqual(size(segIDs), [4 4]);
                testCase.verifyClass(segNames, 'cell');
            catch me
                testCase.verifyFail(sprintf('decoder failed on XML label source: %s', me.message));
            end
        end
    end
end
