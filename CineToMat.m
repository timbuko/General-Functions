%Read Cine File to and save as .mat 
clear all;close all;clc

fileDir='E:\Digital Holography\2023_3_3 Fixed double shock';
filelead='2023_03_03_Cam_23872_Cine1';
saveDir='E:';

Chunk = 500; %number of frames that are read before saving to .matfile
NNframes = 0; %number of frames read. Set to 0 to read all frames in .cine


%%
tic
addpath('C:\Program Files\Phantom\Phantom Functions')
LoadPhantomLibraries();
RegisterPhantom(true);

fileName=[fileDir,'\',filelead,'.cine'];
m=matfile([saveDir,'\',filelead,'.mat'],'Writable',true);

% Get cine info
[HRES, cineHandle] = PhNewCineFromFile(fileName);
if (HRES<0)
	[message] = PhGetErrorMessage( HRES );
    error(['Cine handle creation error: ' message]);
end
%get cine saved range
pFirstIm = libpointer('int32Ptr',0);
PhGetCineInfo(cineHandle, PhFileConst.GCI_FIRSTIMAGENO, pFirstIm);
firstIm = double(pFirstIm.Value);
pImCount = libpointer('uint32Ptr',0);
PhGetCineInfo(cineHandle, PhFileConst.GCI_IMAGECOUNT, pImCount);
lastIm = int32(firstIm + double(pImCount.Value) - 1);
%get cine image buffer size
pInfVal = libpointer('uint32Ptr',0);
PhGetCineInfo(cineHandle, PhFileConst.GCI_MAXIMGSIZE, pInfVal);
maxImgSizeInBytes = double(pInfVal.Value);
%The image flip for GetCineImage function is inhibated.
pInfVal = libpointer('int32Ptr',false);
PhSetCineInfo(cineHandle, PhFileConst.GCI_VFLIPVIEWACTIVE, pInfVal);
if NNframes == 0; Nframes=double(pImCount.Value);
else; Nframes = min(NNframes,double(pImCount.Value));end
% get cine frame rate
pInfVal = libpointer('uint32Ptr',0);
PhGetCineInfo(cineHandle, PhFileConst.GCI_FRAMERATE, pInfVal);
m.frameRate= double(pInfVal.Value);
%get cine exposure in microsec
pInfVal = libpointer('uint32Ptr',0);
PhGetCineInfo(cineHandle, PhFileConst.GCI_EXPOSURENS, pInfVal);
m.exposureSec = double(pInfVal.Value)*1e-9;


% Create the image range to be read
clear BlockBegin BlockChunk;
if Chunk>Nframes;Chunk=Nframes;end
Nblock=floor((Nframes)/Chunk); BlockBegin=(0:Nblock-1)*Chunk+1+firstIm; BlockChunk=ones(1,Nblock)*Chunk;
if BlockBegin(Nblock)+Chunk<=firstIm+Nframes
    BlockBegin(Nblock+1)=BlockBegin(Nblock)+Chunk;
    BlockChunk(Nblock+1)=Nframes-(BlockBegin(Nblock)+Chunk-1-firstIm);
    Nblock=Nblock+1;
end


fprintf('Processing cine image ')
f=fprintf(['(1 out of ',num2str(Nframes),')']);
for iblock=1:Nblock
    imgRange.First = BlockBegin(iblock); imgRange.Cnt = BlockChunk(iblock);
    [HRES, unshiftedIm, imgHeader] = PhGetCineImage(cineHandle, imgRange, imgRange.Cnt*maxImgSizeInBytes);

    % Read image information from header
    isColorImage = IsColorHeader(imgHeader);
    imgSizeInBytes = (imgHeader.biBitCount/8)*imgHeader.biWidth*imgHeader.biHeight;
    imWidthInBytes = (imgHeader.biBitCount/8)*imgHeader.biWidth;
    if (Is16BitHeader(imgHeader)); imDataWidth = imWidthInBytes/2;
    else; imDataWidth = imWidthInBytes; end

    memoryWarning(Chunk,imgHeader) 
    Images = uint16(zeros([imgHeader.biHeight,imgHeader.biWidth,imgRange.Cnt]));
    if isempty(who(m,'vidFrame')); m.vidFrame=uint16(zeros([imgHeader.biHeight,imgHeader.biWidth,Nframes]));end
    
% Transform 1D image pixels to 1D/3D image pixels to be used with MATLAB
    if (HRES >= 0)
        for n = 1:imgRange.Cnt
            pp=BlockBegin(iblock)+n-1-firstIm;
            [unshiftedImBuf] = ExtractImageMatrixFromImageBuffer(unshiftedIm(((n-1)*imgSizeInBytes+1:n*imgSizeInBytes)), imgHeader);
            if (isColorImage); samplespp = 3; else; samplespp = 1; end
            bps = GetEffectiveBitsFromIH(imgHeader);
            [matlabIm, unshiftedImBuf] = ConstructMatlabImage(unshiftedImBuf, imDataWidth, imgHeader.biHeight, samplespp, bps);
            Images(:,:,n) = matlabIm;
            
            if mod(pp,round(Nframes/10))==0
                fprintf(repmat('\b',1,f))
                f=fprintf(['(',num2str(pp),' out of ',num2str(Nframes),')\n']);
            end
        end
    end
    m.vidFrame(:,:,BlockBegin(iblock):BlockBegin(iblock)+BlockChunk(iblock)-1)=Images;
end
PhDestroyCine(cineHandle);
     

fprintf('\n\n\nSaved to %s.mat\n\n',filelead)

toc

function memoryWarning(Chunk,imgHeader)
    mem=memory;mem=mem.MemAvailableAllArrays*0.8;
    if 2*Chunk*imgHeader.biHeight*imgHeader.biWidth > mem
        rec = floor(mem/(2*imgHeader.biHeight*imgHeader.biWidth));
        warning(['The size of video you are trying to load may exceed ',...
            'available RAM, it is recommended to use a Chunk<%d'],rec)
        disp('Paused: Press any key to continue')
        pause
    end
end
