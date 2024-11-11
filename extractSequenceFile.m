function imFilename = extractSequenceFile(thisSequenceFilePath, frameNum, imagePrefix, imagePath)
   % Extract and save a single image from a sequence file as a PNG.

   fileSize = dir(thisSequenceFilePath);
   fileSize = fileSize.bytes;

   % Make sure output directory ends with file separation
   if imagePath(end) ~= filesep; imagePath=[imagePath filesep]; end;

   fid = fopen(thisSequenceFilePath,'r');

   fileHeaderLength = 8192;

   fseek(fid, 548, 'bof'); % Get the image structure
   fileInfo.imageSizeNx       = fread(fid, 1, 'uint32');
   fileInfo.imageSizeNy       = fread(fid, 1, 'uint32');
   fileInfo.imageBitDepth     = fread(fid, 1, 'uint32');
   fileInfo.imageBitDepthReal = fread(fid, 1, 'uint32');
   fileInfo.imageLengthBytes  = fread(fid, 1, 'uint32');
   fileInfo.imageFormat       = fread(fid, 1, 'uint32');

   fseek(fid, 580, 'bof');

   % Get the spacing between images as they are separated
   % by the image size + the image footer up to the next
   % sector boundary.
   fileInfo.imageSpacing = fread(fid, 1, 'uint32'); % Called TrueImageSize in the manual

   time_t_roottime = datenum([1970 1 1 0 0 0]);

   offset = fileHeaderLength + (frameNum-1)*fileInfo.imageSpacing;
   fseek(fid,offset+fileInfo.imageLengthBytes,'bof');
   rawImTime(1) = fread(fid,1,'uint32=>double');
   rawImTime(2) = fread(fid,1,'uint16=>double');
   rawImTime(3) = fread(fid,1,'uint16=>double');
   rawImTime = rawImTime(1) + rawImTime(2)/1000 + rawImTime(3)/1e6;
   imTime = datenum( rawImTime/86400 + time_t_roottime);
   imFilename = [imagePath imagePrefix datestr(imTime,'yyyy-mm-dd-HH-MM-SS-') ...
       sprintf('%06d.png', round(mod(rawImTime,1)*1e6))];
   fseek(fid,offset,'bof');
   im = fread(fid,fileInfo.imageLengthBytes,'uint8=>uint8');
   im = reshape(im,fileInfo.imageSizeNx,fileInfo.imageSizeNy)';
   fprintf('%d, %s\n',frameNum,imFilename);
   imwrite(im, imFilename);

   fclose(fid);
end
