% v0 = VideoWriter('perspective.mp4','MPEG-4');
% % Open the file for writing.
% vid = out.vid1;
% open(v0)
% % Create an array containing data from the sample still image, peppers.png. Write the image in A to the video file.
% 
% for k = 1:size(vid,4)
%    y = flipud(vid(:,:,:,k));
%    frame = y;%rot90(y, 2);
%    writeVideo(v0,frame);
% end
% close(v0)
% 
% %% Wrist Camera
% v0 = VideoWriter('wrist_cam.mp4','MPEG-4');
% % Open the file for writing.
% vid = out.vid0(:,:,:,:);
% open(v0)
% % Create an array containing data from the sample still image, peppers.png. Write the image in A to the video file.
% 
% for k = 1:size(vid,4)
%    y = flipud(vid(:,:,:,k));
%    frame = y;%rot90(y, 2);
%    writeVideo(v0,frame);
% end
% close(v0)
% 
% %% Workpiece Camera
% v0 = VideoWriter('workpiece_cam.mp4','MPEG-4');
% % Open the file for writing.
% vid = out.vid3(:,:,:,:);
% open(v0)
% % Create an array containing data from the sample still image, peppers.png. Write the image in A to the video file.
% 
% for k = 1:size(vid,4)
%    y = flipud(vid(:,:,:,k));
%    frame = y;%rot90(y, 2);
%    writeVideo(v0,frame);
% end
% close(v0)
% 


%% Wrist Depth
v0 = VideoWriter('depth.mp4','MPEG-4');
% Open the file for writing.
v0.FrameRate = 10; % Set to desired frames per second
% Open the file for writing.
vid = flipud(out.depthData(:,:,:,:));

open(v0)
% Create an array containing data from the sample still image, peppers.png. Write the image in A to the video file.
% lim_v = max(max(max(vid(:,:,end))))*1.5;

vid = mod(vid./1*255, 255);
vid = uint8(vid);
for k = 1:size(vid,3)
   frame = vid(:,:,k);%rot90(vid(:,:,k), 2);
   framed(:,:,1)=frame; framed(:,:,2)=frame; framed(:,:,3)=frame;
   writeVideo(v0,frame);
end
close(v0)