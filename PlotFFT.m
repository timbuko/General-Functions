function PlotFFT(t,V,fs)

% figure()
subplot(1,2,1)
plot(t,V);
xlabel('Time (s)')
ylabel('Voltage (mV)')
title('OG Signal vs time')


%Do FFT
Y=fft(V);
Ymag=abs(Y);
N=length(V);
fbase=[1:round(N/2)-1]*fs/N;
subplot(1,2,2),
plot(fbase,Ymag(2:round(N/2)))
% loglog(fbase,Ymag(2:round(N/2)))
xlabel('Frequency (Hz)')
ylabel('Amplitude')
title('FFT')