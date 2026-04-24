classdef t_SegmentationVideo < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'NewFeature','SegmentationVideo'})

        function segmentationVideoFileWrites(testCase)
            testCase.assumeEqual(exist('mj_segmentation_video','file'), 2, ...
                'mj_segmentation_video not on path');

            % 2 frames, 8x8
            vid = zeros(8,8,3,2,'uint8');
            vid(:,:,1,:) = 1;              % id=0 everywhere
            vid(1:4,1:4,2,1) = 1; vid(1:4,1:4,1,1) = 0; % one patch id>=256
            xml = which('dummy.xml');
            testCase.assumeNotEmpty(xml);

            tmpFile = fullfile(tempdir, ['segvid_' char(java.util.UUID.randomUUID) '.mp4']);
            cleanup = onCleanup(@() safeDelete(tmpFile));

            try
                mj_segmentation_video(vid, xml, tmpFile, 'FrameRate', 10);
                testCase.verifyTrue(exist(tmpFile,'file')==2, 'Video file not created');
                info = dir(tmpFile);
                testCase.verifyGreaterThan(info.bytes, 0, 'Video file is empty');
            catch me
                testCase.verifyFail(sprintf('mj_segmentation_video failed: %s', me.message));
            end
        end
    end
end

function safeDelete(f)
    try; delete(f); catch; end %#ok<NOSEMI>
end
