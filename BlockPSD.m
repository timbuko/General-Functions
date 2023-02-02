function [PSD,f] = BlockPSD(data,fs,varargin)
%Block average with Hanning window to compute PSD
%Cuts off last data points so that N/Nblock is integer
%inputs: (data,fs,# blocks,dim)
%
% - if # blocks =[] then 100 blocks will be used
% - dim determines which dimension is used as vector. 
%   example: dim=2 --> rows will be treated as vector
% - If data is a multidimensional array, then the first array dimension whose...
%     size does not equal 1 is treated as in the vector case
%
%
if ndims(data)>3;error('Can''t input matrix with dim>3');end
Nblock=100;
dim=find(size(data)~=1,1);
if nargin>2&&~isempty(varargin{1})
    Nblock=varargin{1};
end
if nargin>3
    dim=varargin{2};
end

permutation=[dim,2,3];permutation(dim)=1;
data=permute(data,permutation); %convert data so vector is dim 1

data=data(1:end-mod(size(data,1),Nblock),:,:); %shorten data so N/Nblock is int
N=size(data,1);
NN=N/Nblock;
f=fs*(0:NN-1)'/NN;
win=0.5*(1-cos(2*pi*(1:NN)/NN)); %Hanning Window
win2=meshgrid(win,1:Nblock)';
% x1=reshape(data,NN,Nblock).*win2;
% ftv1=sqrt(8/3)*fft(x1)/NN;
% PSD=mean(abs(ftv1).^2/(fs/NN),2);

x1=reshape(data,NN,Nblock,size(data,2),[]).*win2;
ftv1=sqrt(8/3)*fft(x1,[],1)/NN;
PSD=squeeze(mean(abs(ftv1).^2/(fs/NN),2));
PSD=permute(PSD,permutation); %convert data back to original form
end