function [PSD,f] = BlockPSD(data,fs,varargin)
%Block average with Hanning window to compute PSD
Nblock=10;
if nargin==3
    Nblock=varargin{1};
end
N=length(data);
NN=N/Nblock;
f=fs*[0:NN-1]'/NN;
win=1-cos([1:NN]*pi/NN).^2;
win2=meshgrid(win,[1:Nblock])';
x1=reshape(data,NN,Nblock).*win2;
ftv1=sqrt(8/3)*fft(x1)/NN;
PSD=mean(abs(ftv1).^2/(fs/NN),2);

end