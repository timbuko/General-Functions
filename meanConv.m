function varargout=meanConv(data,fs,percentError)
%Calculate and plot convergence of the mean. 
%Input percent error as decimal
%First output Tconv, Second output IdxConv
x=data;
meanx=cumsum(data)./(1:length(data))';

i=length(data);
plot([1:length(x)]/fs,meanx);
hold on; plot([0 i/fs],[meanx(end) meanx(end)],'r'); xlim([0,i/fs])
plot([0 i/fs],[meanx(end)*(1+percentError) meanx(end)*(1+percentError)],'--r');
plot([0 i/fs],[meanx(end)*(1-percentError) meanx(end)*(1-percentError)],'--r');
legend('Data','Mean of entire dataset',[num2str(100*percentError),'% error'])
Idxconv=find(meanx>meanx(end)*(1+percentError)|meanx<meanx(end)*(1-percentError),1,'last')+1;
Tconv=Idxconv/fs;
hold off;


varargout={Tconv,Idxconv};
end