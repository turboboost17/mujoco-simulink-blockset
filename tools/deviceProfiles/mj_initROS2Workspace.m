function info = mj_initROS2Workspace(opts)
%MJ_INITROS2WORKSPACE Seed an empty ROS 2 colcon workspace on a remote device.
%
%   INFO = MJ_INITROS2WORKSPACE() reads host/user/password/ROS install/
%   workspace from getpref('ROS_Toolbox_ROS_Device') and, if
%   <ws>/install/setup.bash is missing, runs an empty `colcon build` so
%   that Simulink's DeviceDiagnostics no longer pops the "Configure ROS
%   device" dialog at the start of every `slbuild`.
%
%   Name-value arguments (OPTS):
%       Force   logical, default false. If true, seed even if
%               install/setup.bash already exists.
%
%   See also mj_applyDeviceProfile, mj_saveDeviceProfile, ros2device.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    opts.Force (1,1) logical = false
end

if ~ispref('ROS_Toolbox_ROS_Device')
    error('mj_initROS2Workspace:NoPrefs', ...
        'ROS_Toolbox_ROS_Device prefs are not set. Call ros2device(...) first.');
end
p = getpref('ROS_Toolbox_ROS_Device');

ssh = ros.codertarget.internal.ssh2client(p.Hostname, p.Username, p.Password, p.SSHPort);
checkCmd = sprintf('test -f %s/install/setup.bash && echo OK || echo MISSING', p.ROS2Workspace);
status = strtrim(execute(ssh, checkCmd));

info = struct('Hostname', p.Hostname, 'Workspace', p.ROS2Workspace, ...
    'ROS2Install', p.ROS2Install, 'Seeded', false, 'AlreadyValid', false);

if contains(status, 'OK') && ~opts.Force
    info.AlreadyValid = true;
    fprintf('ROS 2 workspace already valid: %s:%s (install/setup.bash present).\n', ...
        p.Hostname, p.ROS2Workspace);
    return
end

seedCmd = sprintf([ ...
    'mkdir -p %s/src && cd %s && ' ...
    'source %s/setup.bash && ' ...
    'colcon build --paths - 2>&1 | tail -n 10'], ...
    p.ROS2Workspace, p.ROS2Workspace, p.ROS2Install);
fprintf('Seeding ROS 2 workspace at %s:%s ...\n', p.Hostname, p.ROS2Workspace);
disp(execute(ssh, seedCmd));
info.Seeded = true;
end
