function makeInfo = rtwmakecfg()
%RTWMAKECFG Make MuJoCo S-function sources visible to Simulink Coder.
%
% Simulink checks non-inlined S-function source availability before the
% model PostCodeGenCommand runs. Keep the source registration here minimal;
% platform libraries and ROS 2 packaging are still handled in
% mj_postcodegen_grt via RTW.BuildInfo.

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    srcPath = fullfile(repoRoot, 'src');

    makeInfo.includePath = {srcPath};
    makeInfo.sourcePath = {srcPath};
    makeInfo.sources = {'mj_sfun.cpp', 'mj.cpp'};
end