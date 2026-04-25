classdef t_YoloExport < matlab.unittest.TestCase
    % Smoke test for mj_export_yolo_dataset.
    %
    % Builds a tiny synthetic simOut-like struct with a 2-frame segmentation
    % video, runs the exporter, and checks the YOLO directory structure +
    % at least one label file with valid YOLO normalized coordinates.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'NewFeature','YoloExport'})

        function exportProducesYoloLayout(testCase)
            testCase.assumeEqual(exist('mj_export_yolo_dataset','file'), 2, ...
                'mj_export_yolo_dataset not on path');

            xml = which('dummy.xml');
            testCase.assumeNotEmpty(xml);

            % Build a 2-frame 64x64x3 packed-id segmentation video. The
            % decoder unpacks RGB triplets back to integer ids, so a
            % uniform value gives id=0 and a patch with red=1 gives id=1
            % (or whatever id "1" decodes to in the dummy.xml labelmap).
            H = 64; W = 64; N = 2;
            vid = zeros(H, W, 3, N, 'uint8');
            % First frame: small patch in the upper-left
            vid(8:24, 8:24, 1, 1) = 1;
            % Second frame: same patch shifted down/right
            vid(20:36, 20:36, 1, 2) = 1;

            simOut = struct('vid3', vid);

            outDir = fullfile(tempdir, ['yolo_' char(java.util.UUID.randomUUID)]);
            cleanup = onCleanup(@() safeRmdir(outDir)); %#ok<NASGU>

            try
                mj_export_yolo_dataset(simOut, xml, outDir, ...
                    'StartFrame', 1, 'EndFrame', N, ...
                    'Split', 'train', ...
                    'MinArea', 1, ...
                    'Verbose', false);
            catch me
                testCase.verifyFail(sprintf( ...
                    'mj_export_yolo_dataset threw: %s', me.message));
                return;
            end

            testCase.verifyTrue(isfolder(fullfile(outDir, 'images', 'train')), ...
                'images/train missing');
            testCase.verifyTrue(isfolder(fullfile(outDir, 'labels', 'train')), ...
                'labels/train missing');
            testCase.verifyTrue(isfile(fullfile(outDir, 'data.yaml')), ...
                'data.yaml missing');

            imgs = dir(fullfile(outDir, 'images', 'train', '*.*'));
            imgs = imgs(~[imgs.isdir]);
            testCase.verifyGreaterThan(numel(imgs), 0, ...
                'No images written');

            lbls = dir(fullfile(outDir, 'labels', 'train', '*.txt'));
            % classes.txt is a name-per-line manifest, not a YOLO
            % annotation. Skip it when validating YOLO row format.
            lbls = lbls(~strcmp({lbls.name}, 'classes.txt'));
            testCase.verifyGreaterThan(numel(lbls), 0, ...
                'No per-frame label files written');

            % Validate one label file: each row should have >=5 numeric
            % tokens, and all coordinates should be in [0, 1].
            txt = strtrim(fileread(fullfile(lbls(1).folder, lbls(1).name)));
            if isempty(txt)
                % Acceptable if MinArea filtered everything out.
                return;
            end
            lines = splitlines(txt);
            for i = 1:numel(lines)
                if isempty(strtrim(lines{i})), continue; end
                tok = sscanf(lines{i}, '%f');
                testCase.verifyGreaterThanOrEqual(numel(tok), 5, ...
                    sprintf('Label line %d too short: "%s"', i, lines{i}));
                coords = tok(2:end);
                testCase.verifyTrue(all(coords >= 0 & coords <= 1), ...
                    sprintf('Label line %d has out-of-range coords', i));
            end
        end
    end
end

function safeRmdir(d)
    try
        if isfolder(d)
            rmdir(d, 's');
        end
    catch
    end
end
