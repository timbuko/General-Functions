function varargout=stdConv(data,fs,percentError)
%Calculate and plot convergence of the standard deviation. 
%Input percent error as decimal
%First output Tconv, Second output IdxConv
x=data;
n = 1:length(data);
meanx=cumsum(x)./n';
varx = cumsum((x-meanx).^2)./(n-1)';
stdx = sqrt(varx);
i=length(data);
plot([1:length(x)]/fs,stdx);
hold on; plot([0 i/fs],[stdx(end) stdx(end)],'r'); xlim([0,i/fs])
plot([0 i/fs],[stdx(end)*(1+percentError) stdx(end)*(1+percentError)],'--r');
plot([0 i/fs],[stdx(end)*(1-percentError) stdx(end)*(1-percentError)],'--r');
legend('Data','Std of entire dataset',[num2str(100*percentError),'% error'])
Idxconv=find(stdx>stdx(end)*(1+percentError)|stdx<stdx(end)*(1-percentError),1,'last')+1;
Tconv=Idxconv/fs;
hold off;


varargout={Tconv,Idxconv};
end