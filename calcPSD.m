function [Sxx,f] = calcPSD(data,fs,varargin)
%CalcPSD Power Spectral Density
% [Sxx,F] = calcPSD(DATA,FS) calculates the power spectral density of the
% data given. For matrices, the calculation is applied to each column. For
% N-D arrays, the calculation operates on the first non-singleton
% dimension. (This organization follows the MATLAB fft function). A vector
% of frequencies F to go along with Sxx is calculated using the sample
% frequency FS. 
% 
% [Sxx,F] = calcPSD(DATA,FS,Nblocks) is the Sxx calculated by splitting the
% data into Nblocks blocks, calculating the Sxx for each, then averaging
% the Sxx for each block to get a block averaged Sxx
%   
% [Sxx,F] = calcPSD(DATA,FS,Nblocks,DIM) applies the calculation across the
% dimension DIM
% 
% The DATA,FS pairs can be followed by parameter/value pair to specify
% additional properties
% 
% --- "window" ---
%    "hanning" (default) | "none"
%
%   Windowing can be used to relieve end effects in the spectra. These will
%   decrease leakage of energy into frequencies around a peak, but will
%   make the peaks wider
% 
% --- "overlap" ---
%      0 (default) | scalar between 0 and 1
% 
%   The overlap option uses the Welch methods and makes the blocks used in
%   block averaging overlap. For example if overlap is set to 0.5, that
%   means the blocks will overlap by 50%.
% 
% 
% --- "blockSize" ---
%       calculated in function (default) | positive scalar less than the
%       total number of data points in the vector
% 
%   This allows you to set the size of the blocks instead of the number of
%   blocks used for block averaging.
%
% 
% 
%   For length N input vector x, the power spectral density is a length
%   N vector Sxx, with elements
%   
%       Sxx(k) = |ck|^2*N/fsamp
%                           N
%           where ck = 1/N sum x(j)*exp(-2*pi*1i*k*(j-1)/N), 1 <= k <= N
%                          j=1
% Other notes:
%
% - Last data points are cut off so that N/Nblock is integer
% - if # blocks =[] then 1 blocks will be used
% - dim determines which dimension is used as vector. 
%   example: dim=2 --> rows will be treated as vector
% - If data is a multidimensional array, then the first array dimension whose...
%     size does not equal 1 is treated as in the vector case
%
% Written by Timothy Bukowski 2/22/2023
%% Parser
p = inputParser;
validdata = @(x) isnumeric(x) && ndims(x)<=3;
defaultNblock = 1;
defaultdim = find(size(data)~=1,1);
defaultwindow = 'hanning';
validwindows = {'hanning','none'};
checkwindows = @(x) any(validatestring(x,validwindows));
validoverlap = @(x) isnumeric(x) && (x>=0) && (x<1); 

addRequired(p,'data',validdata)
addRequired(p,'fs',@isnumeric)
addOptional(p,'Nblock',defaultNblock,@isnumeric);
addOptional(p,'dim',defaultdim)
addParameter(p,'window',defaultwindow,checkwindows)
addParameter(p,'overlap',0,validoverlap)
addParameter(p,'blockSize',0)

parse(p,data,fs,varargin{:})
dim = p.Results.dim;
Nblock = p.Results.Nblock;
if isempty(Nblock);Nblock=1;end
overlap = p.Results.overlap;

%% Calculation
permutation=[dim,2,3];permutation(dim)=1;
data=permute(data,permutation); %convert data so vector is dim 1

if overlap ==0
if p.Results.blockSize~=0 
    chop = mod(size(data,1),p.Results.blockSize);
else
    chop = mod(size(data,1),Nblock);
end
data=data(1:end-chop,:,:); %shorten data so N/Nblock is int
end

if p.Results.blockSize~=0
    NN=p.Results.blockSize;
else
    N=size(data,1);
    NN=N/Nblock;
end

f=(0:NN-1)'*fs/NN;
if overlap~=0
    xPadded = [data;zeros(floor(NN*overlap),1)];
    Nblock = ceil(length(data)/(NN*(1-overlap)))-2;
    data = zeros(NN,Nblock);
    for i = 1:Nblock
        start = round((i-1)*NN*(1-overlap) + 1)
    st = start+NN-1
        data(:,i) = xPadded(start:start+NN-1);
    end
end
if strcmp(p.Results.window, 'hanning')
    win=0.5*(1-cos(2*pi*(1:NN)/NN)); %Hanning Window
    win2=meshgrid(win,1:Nblock)';
    x1=reshape(data,NN,Nblock,size(p.Results.data,2),[]).*win2;
    ck=sqrt(8/3)*fft(x1,[],1)/NN;
elseif strcmp(p.Results.window, 'none')
    x1=reshape(data,NN,Nblock,size(p.Results.data,2),[]);
    ck=fft(x1,[],1)/NN;
end

Sxx=squeeze(mean(abs(ck).^2/(fs/NN),2));
Sxx=permute(Sxx,permutation); %convert data back to original form
end