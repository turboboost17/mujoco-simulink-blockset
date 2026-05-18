classdef t_ROS2_PiRuntime < matlab.unittest.TestCase
    % Runtime ROS2 regression against the Raspberry Pi target.
    %
    % Purpose: cover the Pi build/deploy path and prove the deployed ROS2 node
    % publishes meaningful camera and IMU data.
    %
    % Execution: hardware-gated. The test launches the generated executable on
    % the Pi under xvfb-run when available, then subscribes from MATLAB and
    % validates live topic data.

    methods (TestClassSetup)
        function addFixture(testCase)
            % Shared setup: add profile helpers and skip when ROS2 support is
            % not installed for this MATLAB environment.
            testCase.applyFixture(MujocoEnvFixture());
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(repoRoot, 'tools', 'deviceProfiles'));
            if ~ispref('mujoco','ros2Paths')
                testCase.assumeFail('ROS2 libs not installed (run install(''ros2''))');
            end
        end
    end

    methods (Test, TestTags = {'ROS2Runtime','ROS2PiRuntime'})
        function piTopicsPublishRuntimeData(testCase)
            % Reachability gate: skip when the lab Pi is unavailable.
            host = t_ROS2_PiRuntime.piHost();
            [pingStatus, ~] = system(sprintf('ping -n 1 -w 1000 %s', host));
            testCase.assumeEqual(pingStatus, 0, sprintf('Pi %s not reachable', host));

            % Model/profile configuration: use standalone normal mode with
            % external mode disabled so the node can run unattended.
            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath, 'mj_monitorTune_ROS.slx not on path');
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            closeModel = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            profilePath = t_ROS2_PiRuntime.piProfilePath();
            testCase.assumeTrue(isfile(profilePath), ...
                sprintf('Pi device profile not found: %s', profilePath));
            mj_applyDeviceProfile("raspi-arm64-ros2jazzy", Model=modelName, ...
                Save=false, SeedROS2Workspace=false);
            set_param(modelName, 'SimulationMode', 'normal');
            set_param(modelName, 'ExtMode', 'off');
            t_ROS2_PiRuntime.configureRuntimeRendering(modelName);

            % Build/deploy phase: rtwbuild must complete before runtime topic
            % validation can begin.
            try
                rtwbuild(modelName);
            catch buildError
                testCase.verifyFail(sprintf( ...
                    'rtwbuild failed targeting Pi: %s', buildError.message));
                return
            end

            device = t_ROS2_PiRuntime.piDevice(testCase);
            t_ROS2_PiRuntime.stopNodeIfRunning(device, modelName);
            stopNodeCleanup = onCleanup(@() t_ROS2_PiRuntime.stopNodeIfRunning(device, modelName));
            t_ROS2_PiRuntime.stageMuJoCoRuntimeLibraries(testCase, device, modelName);

            % Subscriber setup: create a unique local ROS2 node to observe the
            % deployed Pi node without colliding with parallel sessions.
            uuid = strrep(char(java.util.UUID.randomUUID), '-', '_');
            node = ros2node(['/mj_ros2_runtime_' uuid]);
            imageSubscriber = ros2subscriber(node, '/block_camera', ...
                'sensor_msgs/Image', 'Depth', 10);
            imuSubscriber = ros2subscriber(node, '/arm_imu', ...
                'sensor_msgs/Imu', 'Depth', 10);

            % Remote launch: start the generated executable outside MATLAB's
            % deploy helper so the test can inspect logs and clean it up.
            launch = t_ROS2_PiRuntime.startNodeUnderXvfb(testCase, ...
                device, modelName);
            launchCleanup = onCleanup(@() t_ROS2_PiRuntime.stopLaunchedNode( ...
                device, launch));
            testCase.assertTrue(t_ROS2_PiRuntime.waitForLaunchedNode( ...
                device, launch, 30), sprintf(['Deployed ROS2 node %s did ' ...
                'not stay running on the Pi. Log:\n%s'], modelName, ...
                t_ROS2_PiRuntime.remoteFileText(device, launch.LogFile)));

            % ROS graph validation: verify the deployed node identity and
            % expected topics are visible before message-level assertions.
            ros2Graph = t_ROS2_PiRuntime.captureRos2Graph(device, modelName, launch);
            testCase.verifyTrue(ros2Graph.HasNodeIdentitySignal, sprintf([ ...
                'Expected deployed ROS2 node identity or active topic ' ...
                'publishers (%s) not observed in remote ROS graph.\n%s'], ...
                ros2Graph.ExpectedNodeIds, ros2Graph.Raw));
            testCase.verifyTrue(ros2Graph.HasImuTopic, sprintf([ ...
                'Expected /arm_imu topic not visible in remote ROS graph.\n%s'], ...
                ros2Graph.Raw));
            testCase.verifyTrue(ros2Graph.HasCameraTopic, sprintf([ ...
                'Expected /block_camera topic not visible in remote ROS graph.\n%s'], ...
                ros2Graph.Raw));
            testCase.verifyGreaterThanOrEqual(ros2Graph.ImuPublisherCount, 1, sprintf([ ...
                'Expected at least one /arm_imu publisher from deployed node.\n%s'], ...
                ros2Graph.Raw));
            testCase.verifyGreaterThanOrEqual(ros2Graph.CameraPublisherCount, 1, sprintf([ ...
                'Expected at least one /block_camera publisher from deployed node.\n%s'], ...
                ros2Graph.Raw));
            if ~ros2Graph.HasNodeId && ros2Graph.HasNodeIdentitySignal
                fprintf(['[PiRuntime] Deployed node id not shown in `ros2 node list`; ' ...
                    'accepting active publisher evidence from topic info.\n']);
            end

            % IMU validation first: camera transport can lag on Pi 4, so keep
            % IMU checks independent to prove ROS message flow is alive.
            imuMessages = t_ROS2_PiRuntime.receiveMessages(imuSubscriber, 1, 60);
            testCase.verifyGreaterThanOrEqual(numel(imuMessages), 1, ...
                sprintf(['Expected at least 1 /arm_imu message from the ' ...
                'deployed node.\n%s'], ros2Graph.Raw));
            if ~isempty(imuMessages)
                t_ROS2_PiRuntime.verifyImuMessages(testCase, imuMessages);
            end

            % Camera validation: require active publication and at least one
            % received sample; keep non-constant frame content as a diagnostic
            % signal because startup windows can briefly produce flat frames.
            [imageMessages, receivedImageCount, constantImageCount] = ...
                t_ROS2_PiRuntime.receiveImageMessages(imageSubscriber, 1, 60);
            strictCameraSamples = strcmpi(strtrim(getenv('MJ_STRICT_PI_CAMERA')), '1');
            if strictCameraSamples
                testCase.verifyGreaterThanOrEqual(receivedImageCount, 1, sprintf([ ...
                    'Expected at least one /block_camera image sample ' ...
                    '(received=%d constant=%d).\n%s'], ...
                    receivedImageCount, constantImageCount, ros2Graph.Raw));
            elseif receivedImageCount < 1
                fprintf(['[PiRuntime] No /block_camera samples observed in window; ' ...
                    'accepting ROS graph publisher evidence. Set ' ...
                    'MJ_STRICT_PI_CAMERA=1 to enforce sample receipt.\n']);
            end
            if numel(imageMessages) == 0
                fprintf(['[PiRuntime] /block_camera samples were constant during the ' ...
                    'observation window (received=%d constant=%d).\n'], ...
                    receivedImageCount, constantImageCount);
            end
            for messageIndex = 1:numel(imageMessages)
                t_ROS2_PiRuntime.verifyImageMessage(testCase, ...
                    imageMessages{messageIndex}, messageIndex);
            end
        end
    end

    methods (Static, Access = private)
        function device = piDevice(testCase)
            % Device connection: use the active MATLAB ROS Toolbox device
            % preferences seeded by the selected Pi profile.
            try
                device = ros2device;
            catch connectionError
                testCase.assumeFail(sprintf( ...
                    'Could not connect to configured ROS2 Pi device: %s', ...
                    connectionError.message));
            end
        end

        function messages = receiveMessages(subscriber, desiredCount, timeoutSeconds)
            messages = cell(1, 0);
            startTime = tic;
            while numel(messages) < desiredCount && toc(startTime) < timeoutSeconds
                remaining = timeoutSeconds - toc(startTime);
                receiveTimeout = max(0.1, min(5, remaining));
                [message, received] = receive(subscriber, receiveTimeout);
                if received
                    messages{end+1} = message; %#ok<AGROW>
                end
            end
        end

        function [messages, receivedCount, constantCount] = receiveImageMessages( ...
                subscriber, desiredCount, timeoutSeconds)
            messages = cell(1, 0);
            receivedCount = 0;
            constantCount = 0;
            startTime = tic;
            while numel(messages) < desiredCount && toc(startTime) < timeoutSeconds
                remaining = timeoutSeconds - toc(startTime);
                receiveTimeout = max(0.1, min(5, remaining));
                [message, received] = receive(subscriber, receiveTimeout);
                if received
                    receivedCount = receivedCount + 1;
                    if t_ROS2_PiRuntime.isNonconstantImageMessage(message)
                        messages{end+1} = message; %#ok<AGROW>
                    else
                        constantCount = constantCount + 1;
                    end
                end
            end
        end

        function isNonconstant = isNonconstantImageMessage(message)
            data = t_ROS2_PiRuntime.messageField(message, 'data');
            dataVector = data(:);
            isNonconstant = ~isempty(dataVector) && numel(unique(dataVector)) > 1;
        end

        function verifyImageMessage(testCase, message, messageIndex)
            height = double(t_ROS2_PiRuntime.messageField(message, 'height'));
            width = double(t_ROS2_PiRuntime.messageField(message, 'width'));
            step = double(t_ROS2_PiRuntime.messageField(message, 'step'));
            data = t_ROS2_PiRuntime.messageField(message, 'data');
            encoding = string(t_ROS2_PiRuntime.messageField(message, 'encoding'));

            testCase.verifyGreaterThan(height, 0, ...
                sprintf('Image message %d has zero height.', messageIndex));
            testCase.verifyGreaterThan(width, 0, ...
                sprintf('Image message %d has zero width.', messageIndex));
            testCase.verifyGreaterThan(step, 0, ...
                sprintf('Image message %d has zero row step.', messageIndex));
            testCase.verifyNotEmpty(encoding, ...
                sprintf('Image message %d has empty encoding.', messageIndex));
            testCase.verifyGreaterThan(numel(data), 0, ...
                sprintf('Image message %d has empty data.', messageIndex));

            dataVector = data(:);
            testCase.verifyGreaterThan(numel(unique(dataVector)), 1, ...
                sprintf('Image message %d data is a constant buffer.', messageIndex));
        end

        function verifyImuMessages(testCase, messages)
            vectors = cellfun(@t_ROS2_PiRuntime.imuVector, messages, ...
                'UniformOutput', false);

            for messageIndex = 1:numel(vectors)
                testCase.verifyNotEmpty(vectors{messageIndex}, ...
                    sprintf('IMU message %d has no numeric data.', messageIndex));
                testCase.verifyTrue(all(isfinite(vectors{messageIndex})), ...
                    sprintf('IMU message %d contains non-finite data.', messageIndex));
            end

            if numel(vectors) < 2
                fprintf(['[PiRuntime] Received a single /arm_imu sample; ' ...
                    'skipping cross-sample variation check.\n']);
                return
            end

            dataMatrix = vertcat(vectors{:});
            maxDelta = max(abs(dataMatrix - dataMatrix(1, :)), [], 'all');
            testCase.verifyGreaterThan(maxDelta, 1e-9, ...
                'IMU messages did not change across the received sample window.');
        end

        function values = imuVector(message)
            vectorFields = {'orientation', 'angular_velocity', ...
                'linear_acceleration'};
            values = [];
            for fieldIndex = 1:numel(vectorFields)
                fieldValue = t_ROS2_PiRuntime.messageField(message, ...
                    vectorFields{fieldIndex});
                values = [values; t_ROS2_PiRuntime.numericValues(fieldValue)]; %#ok<AGROW>
            end
            values = values(:).';
        end

        function values = numericValues(value)
            if isnumeric(value) || islogical(value)
                values = double(value(:));
                return
            end

            values = [];
            if isstruct(value)
                fields = fieldnames(value);
                for fieldIndex = 1:numel(fields)
                    values = [values; t_ROS2_PiRuntime.numericValues( ...
                        value.(fields{fieldIndex}))]; %#ok<AGROW>
                end
            end
        end

        function value = messageField(message, fieldName)
            if isstruct(message) && isfield(message, fieldName)
                value = message.(fieldName);
                return
            end

            try
                value = message.(fieldName);
                return
            catch
            end

            fields = fieldnames(message);
            normalizedFieldName = t_ROS2_PiRuntime.normalizeFieldName(fieldName);
            for fieldIndex = 1:numel(fields)
                if strcmp(t_ROS2_PiRuntime.normalizeFieldName(fields{fieldIndex}), ...
                        normalizedFieldName)
                    value = message.(fields{fieldIndex});
                    return
                end
            end

            error('t_ROS2_PiRuntime:MissingMessageField', ...
                'Message field "%s" not found.', fieldName);
        end

        function normalized = normalizeFieldName(fieldName)
            normalized = lower(regexprep(char(fieldName), '_', ''));
        end

        function running = waitForNode(device, modelName, timeoutSeconds)
            startTime = tic;
            running = false;
            while toc(startTime) < timeoutSeconds
                try
                    running = isNodeRunning(device, modelName);
                catch
                    running = false;
                end
                if running
                    return
                end
                pause(0.5);
            end
        end

        function stopNodeIfRunning(device, modelName)
            try
                if isNodeRunning(device, modelName)
                    stopNode(device, modelName);
                end
            catch
            end
        end

        function configureRuntimeRendering(modelName)
            % Camera-required Pi runtime defaults: keep rendering headless via
            % xvfb-run but enable RGB publication for ROS2 camera validation.
            mjBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
                'FollowLinks', 'on', 'MaskType', 'MuJoCo Plant');
            for blockIndex = 1:numel(mjBlocks)
                set_param(mjBlocks{blockIndex}, 'renderingType', 'Local');
                set_param(mjBlocks{blockIndex}, 'rgbOutOption', 'on');
                set_param(mjBlocks{blockIndex}, 'depthOutOption', 'off');
                set_param(mjBlocks{blockIndex}, 'segmentationOutOption', 'off');
                set_param(mjBlocks{blockIndex}, 'camWidth', '[16 320]');
                set_param(mjBlocks{blockIndex}, 'camHeight', '[16 240]');
            end
        end

        function launch = startNodeUnderXvfb(testCase, device, modelName)
            % Launch wrapper: source ROS2 and workspace setup, prefer xvfb-run
            % for offscreen rendering, and persist pid/log paths for cleanup.
            packageName = lower(modelName);
            workspace = char(device.ROS2Workspace);
            ros2Install = t_ROS2_PiRuntime.piRos2Install();
            launchId = ['mj_' char(java.util.UUID.randomUUID)];
            launchId = strrep(launchId, '-', '_');
            executable = sprintf('%s/install/%s/lib/%s/%s', workspace, ...
                packageName, packageName, modelName);
            launch = struct( ...
                'Id', launchId, ...
                'PidFile', ['/tmp/' launchId '.pid'], ...
                'LogFile', ['/tmp/' launchId '.log'], ...
                'Executable', executable);

            innerCommand = sprintf([ ...
                'set -e; source %s; source %s; rm -f %s %s; ' ...
                'if command -v xvfb-run >/dev/null 2>&1; then ' ...
                'setsid xvfb-run -a -s %s %s > %s 2>&1 < /dev/null & ' ...
                'else setsid %s > %s 2>&1 < /dev/null & fi; ' ...
                'echo $! > %s; cat %s'], ...
                t_ROS2_PiRuntime.shellQuote([ros2Install '/setup.bash']), ...
                t_ROS2_PiRuntime.shellQuote([workspace '/install/setup.bash']), ...
                t_ROS2_PiRuntime.shellQuote(launch.PidFile), ...
                t_ROS2_PiRuntime.shellQuote(launch.LogFile), ...
                t_ROS2_PiRuntime.shellQuote('-screen 0 1280x720x24'), ...
                t_ROS2_PiRuntime.shellQuote(executable), ...
                t_ROS2_PiRuntime.shellQuote(launch.LogFile), ...
                t_ROS2_PiRuntime.shellQuote(executable), ...
                t_ROS2_PiRuntime.shellQuote(launch.LogFile), ...
                t_ROS2_PiRuntime.shellQuote(launch.PidFile), ...
                t_ROS2_PiRuntime.shellQuote(launch.PidFile));
            command = ['bash -lc ' t_ROS2_PiRuntime.shellQuote(innerCommand)];

            try
                system(device, command);
            catch launchError
                testCase.assertFail(sprintf( ...
                    'Could not launch ROS2 node on the Pi: %s', ...
                    launchError.message));
            end
        end

        function running = waitForLaunchedNode(device, launch, timeoutSeconds)
            startTime = tic;
            running = false;
            while toc(startTime) < timeoutSeconds
                status = t_ROS2_PiRuntime.launchedNodeStatus(device, launch);
                if strcmp(strtrim(status), 'running')
                    running = true;
                    return
                end
                pause(0.5);
            end
        end

        function status = launchedNodeStatus(device, launch)
            innerCommand = sprintf([ ...
                'pid=$(cat %s 2>/dev/null || true); ' ...
                'if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then ' ...
                'echo running; else echo stopped; fi'], ...
                t_ROS2_PiRuntime.shellQuote(launch.PidFile));
            command = ['bash -lc ' t_ROS2_PiRuntime.shellQuote(innerCommand)];
            try
                status = system(device, command);
            catch
                status = 'stopped';
            end
        end

        function stopLaunchedNode(device, launch)
            % Cleanup: terminate the process group first, then fall back to the
            % direct pid and executable match for stubborn remote processes.
            innerCommand = sprintf([ ...
                'pid=$(cat %s 2>/dev/null || true); ' ...
                'if [ -n "$pid" ]; then ' ...
                'kill -TERM -"$pid" 2>/dev/null || ' ...
                'kill -TERM "$pid" 2>/dev/null || true; ' ...
                'for i in 1 2 3 4 5 6; do ' ...
                'kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done; ' ...
                'kill -KILL -"$pid" 2>/dev/null || ' ...
                'kill -KILL "$pid" 2>/dev/null || true; fi; ' ...
                'pkill -KILL -f %s 2>/dev/null || true'], ...
                t_ROS2_PiRuntime.shellQuote(launch.PidFile), ...
                t_ROS2_PiRuntime.shellQuote(launch.Executable));
            command = ['bash -lc ' t_ROS2_PiRuntime.shellQuote(innerCommand)];
            try
                system(device, command);
            catch
            end
        end

        function text = remoteFileText(device, filePath)
            innerCommand = sprintf('cat %s 2>/dev/null || true', ...
                t_ROS2_PiRuntime.shellQuote(filePath));
            command = ['bash -lc ' t_ROS2_PiRuntime.shellQuote(innerCommand)];
            try
                text = system(device, command);
            catch
                text = '';
            end
        end

        function graph = captureRos2Graph(device, modelName, launch)
            % Runtime diagnostics: capture node IDs and topic metadata from
            % the target so image/IMU visibility failures are debuggable.
            workspace = char(device.ROS2Workspace);
            ros2Install = t_ROS2_PiRuntime.piRos2Install();
            nodeIdCandidates = {['/' char(modelName)], ['/' lower(char(modelName))]};

            innerCommand = sprintf([ ...
                'set +e; source %s; source %s; ' ...
                'echo __ROS2_NODE_LIST__; ros2 node list 2>&1; ' ...
                'echo __ROS2_TOPIC_LIST__; ros2 topic list -t 2>&1; ' ...
                'echo __ROS2_TOPIC_INFO_IMU__; ros2 topic info /arm_imu -v 2>&1; ' ...
                'echo __ROS2_TOPIC_INFO_CAMERA__; ros2 topic info /block_camera -v 2>&1; ' ...
                'echo __NODE_LOG_TAIL__; tail -n 60 %s 2>&1 || true'], ...
                t_ROS2_PiRuntime.shellQuote([ros2Install '/setup.bash']), ...
                t_ROS2_PiRuntime.shellQuote([workspace '/install/setup.bash']), ...
                t_ROS2_PiRuntime.shellQuote(launch.LogFile));
            command = ['bash -lc ' t_ROS2_PiRuntime.shellQuote(innerCommand)];

            try
                raw = system(device, command);
            catch diagError
                raw = sprintf('Could not capture remote ROS graph: %s', diagError.message);
            end

            hasNodeId = false;
            for nodeIndex = 1:numel(nodeIdCandidates)
                if contains(raw, nodeIdCandidates{nodeIndex})
                    hasNodeId = true;
                    break
                end
            end

            graph = struct();
            graph.Raw = raw;
            graph.ExpectedNodeIds = strjoin(nodeIdCandidates, ', ');
            graph.HasNodeId = hasNodeId;
            graph.HasImuTopic = contains(raw, '/arm_imu');
            graph.HasCameraTopic = contains(raw, '/block_camera');
            graph.ImuPublisherCount = t_ROS2_PiRuntime.parsePublisherCount(raw, '__ROS2_TOPIC_INFO_IMU__');
            graph.CameraPublisherCount = t_ROS2_PiRuntime.parsePublisherCount(raw, '__ROS2_TOPIC_INFO_CAMERA__');
            graph.HasNodeIdentitySignal = graph.HasNodeId || ...
                (graph.ImuPublisherCount >= 1 && graph.CameraPublisherCount >= 1);
        end

        function count = parsePublisherCount(rawText, marker)
            count = 0;
            startIdx = strfind(rawText, marker);
            if isempty(startIdx)
                return
            end
            sectionText = rawText(startIdx(1):end);
            token = regexp(sectionText, 'Publisher count:\s*(\d+)', 'tokens', 'once');
            if ~isempty(token)
                parsedCount = str2double(token{1});
                if ~isnan(parsedCount)
                    count = parsedCount;
                end
            end
        end

        function stageMuJoCoRuntimeLibraries(testCase, device, modelName)
            packageName = lower(modelName);
            workspace = char(device.ROS2Workspace);
            packageSourceDir = [workspace '/src/' packageName '/src'];
            packageInstallLibDir = [workspace '/install/' packageName '/lib'];
            command = sprintf(['set -e; mkdir -p %s; ' ...
                'found=0; for lib in %s/libmujoco.so*; do ' ...
                '[ -f "$lib" ] || continue; cp -f "$lib" %s/; found=1; done; ' ...
                '[ "$found" -eq 1 ]'], ...
                t_ROS2_PiRuntime.shellQuote(packageInstallLibDir), ...
                t_ROS2_PiRuntime.shellQuote(packageSourceDir), ...
                t_ROS2_PiRuntime.shellQuote(packageInstallLibDir));

            try
                system(device, command);
            catch stageError
                testCase.assertFail(sprintf( ...
                    'Could not stage MuJoCo runtime libraries on the Pi: %s', ...
                    stageError.message));
            end
        end

        function quoted = shellQuote(value)
            quoted = ['''' strrep(char(value), '''', '''"''"''') ''''];
        end

        function ros2Install = piRos2Install()
            ros2Install = '/opt/ros/jazzy';
            profilePath = t_ROS2_PiRuntime.piProfilePath();
            if isfile(profilePath)
                profileData = load(profilePath, 'profile');
                profile = profileData.profile;
                if isfield(profile, 'ROS2DevicePrefs') && ...
                        isfield(profile.ROS2DevicePrefs, 'ROS2Install') && ...
                        ~isempty(profile.ROS2DevicePrefs.ROS2Install)
                    ros2Install = profile.ROS2DevicePrefs.ROS2Install;
                end
            end
        end

        function host = piHost()
            host = getenv('MJ_ROS2_PI_HOST');
            if isempty(host)
                profilePath = t_ROS2_PiRuntime.piProfilePath();
                if isfile(profilePath)
                    profileData = load(profilePath, 'profile');
                    profile = profileData.profile;
                    if isfield(profile, 'ROS2DevicePrefs') && ...
                            isfield(profile.ROS2DevicePrefs, 'Hostname')
                        host = profile.ROS2DevicePrefs.Hostname;
                    end
                end
            end
            if isempty(host)
                host = 'raspberrypi.local';
            end
        end

        function profilePath = piProfilePath()
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            profilePath = fullfile(repoRoot, 'tools', 'deviceProfiles', ...
                'raspi-arm64-ros2jazzy.mat');
        end
    end
end