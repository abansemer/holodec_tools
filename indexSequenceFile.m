function [seqInfo, firstIm] = indexSequenceFile(thisSequenceFilePath)

   fileDir = dir(thisSequenceFilePath);
   fileSize = fileDir.bytes;
   fid = fopen( thisSequenceFilePath,'r');

   MagicNumber = fread(fid, 1, 'int32');
   if MagicNumber ~= 65261 % 0XFEED is the magic number
       error(sprintf('%s has the wrong magic number for a sequence file',thisSequenceFilePath)); %#ok<SPERR>
   end

   fileHeaderLength = 8192;

   fseek(fid, 548, 'bof'); % Get the image structure
   seqInfo.filename          = thisSequenceFilePath;
   seqInfo.imageSizeNx       = fread(fid, 1, 'uint32');
   seqInfo.imageSizeNy       = fread(fid, 1, 'uint32');
   seqInfo.imageBitDepth     = fread(fid, 1, 'uint32');
   seqInfo.imageBitDepthReal = fread(fid, 1, 'uint32');
   seqInfo.imageLengthBytes  = fread(fid, 1, 'uint32');
   seqInfo.imageFormat       = fread(fid, 1, 'uint32');

   % Get the number of images that are supposed to be in this file
   fseek(fid, 572, 'bof'); 
   seqInfo.numImages = fread(fid, 1, 'uint32');

   if (seqInfo.imageBitDepth ~= 8 || seqInfo.imageBitDepthReal ~= 8 || seqInfo.imageFormat ~= 100)
       error('This function only supports Monochrome 8-bit images');
   end

   % Get the spacing between images as they are separated by the image size + the 
   % image footer up to the next sector boundary.
   fseek(fid, 580, 'bof'); 
   seqInfo.imageSpacing = fread(fid, 1, 'uint32'); % Called TrueImageSize in the manual

   % Suggested frame rate
   fseek(fid, 584, 'bof');
   seqInfo.frameRate = fread(fid, 1, 'double');

   % Extended info
   fseek(fid, 616, 'bof');
   seqInfo.extendedHeader = fread(fid, 1, 'int32');

   time_t_roottime = datenum([1970 1 1 0 0 0]);

   shouldBeNumImages = round((fileSize - fileHeaderLength)/(seqInfo.imageSpacing));
   if seqInfo.numImages ~= shouldBeNumImages
       warning('File may be corrupted, the number of reported images does not match the file size.');
   end
   numImages = shouldBeNumImages;

   seqInfo.time=zeros(numImages,1);
   seqInfo.date=zeros(numImages,1);
   seqInfo.brightness=zeros(numImages,1);
   seqInfo.imagepointer=zeros(numImages,1);
   for cnt2 = 1:numImages
       frameNum = cnt2;
       offset = fileHeaderLength + (cnt2-1)*seqInfo.imageSpacing;
       fseek(fid,offset+seqInfo.imageLengthBytes,'bof');
       rawImTime(1) = fread(fid,1,'uint32=>double');
       rawImTime(2) = fread(fid,1,'uint16=>double');
       rawImTime(3) = fread(fid,1,'uint16=>double');
       rawImTime = rawImTime(1) + rawImTime(2)/1000 + rawImTime(3)/1e6;
       imTime = datenum( rawImTime/86400 + time_t_roottime);
       seqInfo.time(cnt2) = imTime;  %Contains time and date, use datestr to convert
       seqInfo.imagepointer(cnt2)=offset;

       %Read 10kB near the middle of the image to get an overall brightness
       fseek(fid,offset + seqInfo.imageLengthBytes/2,'bof');
       im = fread(fid,10000,'uint8=>uint8');
       seqInfo.brightness(cnt2)=mean(im);
       
   end % End iterating through images
   
   if nargout == 2
       %Read the first full hologram and save histogram and brightness
       fseek(fid, offset, 'bof');
       im = fread(fid, seqInfo.imageLengthBytes, 'uint8=>uint8');
       seqInfo.fullsizebrightness = mean(im);  %Brightness of a full image
       [seqInfo.histogram, seqInfo.histogram_edges] = histcounts(im, 0:1:255);
       firstIm = reshape(im, seqInfo.imageSizeNx, seqInfo.imageSizeNy)';
   end

   fclose(fid);

end
