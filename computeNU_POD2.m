function [POD_Modes, a, energy,varargout] = computeNU_POD2(data,w)
%Weighted POD

%% Get data in right form (rows - space, cols - time)
%1

if ndims(data)==3 %If 3D matrix
    TT = size(data,3); %TT time indicies    
    ind = find(~isnan(sum(data,3))); %ind - indices with no nans at any time
%2
    WF = zeros(length(ind),TT);
    for i = 1:TT
        WF3 = data(:,:,i); 
        WF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
    end
    %At this point have matrix with each column all the spatial points for a given time 
    
elseif ndims(data)==2 %If 2D matrix
    TT = size(data,2);
    ind = find(~isnan(sum(data,2))); %ind - indices with no nans at any time
    WF = data(ind,:);
end
    %At this point have matrix with each column all the spatial points for a given time
    %dim of WF are lenght(ind) by TT

%%  Calculation
[M,N]=size(WF);
[id1 id2]=size(w);
if id1==1
    wi=w(ind);
elseif id2==1
    wi=w(ind)';
end
wj=wi';

WFMean = mean(WF,2); %temporal mean
WF = WF - repmat(WFMean,1,N); %subtract temporal mean
wf=WF.*sqrt(wj);
clear WF WFMean

if 1%M<=N %Direct Method
%     R = zeros(M);
%     for i = 1:N
%         R=R+wf(:,i)*wf(:,i)'; 
%         if mod(i,round(TT/20))==0;disp([num2str(i/TT*100),' %']);end
%     end
%     R=R/N; %R is temporal average AA'
    R=(wf*wf')/N;
    
    [Vectors,Values]=eig(R);
    clear R
    [Vectors, Values] = sortem(Vectors,Values); 
    energy = diag(Values)/sum(sum(Values)); 
    Psi_tild=Vectors;
    a=wf'*Psi_tild;
    
% elseif M>N %Snapshot method
%     A=zeros(N);
%     for i=1:M
%         A=A+wf(i,:)'*wf(i,:);
%         if mod(i,round(M/20))==0;disp([num2str(i/M*100),' %']);end
%     end
%     A=A/N;
%     [Vectors,Values]=eig(A);
%     [Vectors, Values] = sortem(Vectors,Values); 
%     energy = diag(Values)/sum(sum(Values));
%     cumEnergy=cumsum(energy);
%     Psi=zeros(M,N);
%     for i=1:M
%         for n=1:N
%             Psi(i,:)=Psi(i,:)+wf(i,n)*Vectors(n,:);
%         end
%         if mod(i,round(M/20))==0;disp([num2str(i/M*100),' %']);end
%     end
%     Psi=Psi/N;
%     for k=1:N
%         Psi_tild(:,k)=Psi(:,k)/sqrt(Values(k,k)/N);
%         a(:,k)=sqrt(Values(k,k)*N)*Vectors(:,k);
%     end
end

Modes=Psi_tild./sqrt(wj);
%% Convert back to original form
if ndims(data)==3
ModeShapes = NaN(size(WF2,1),size(WF2,2),length(energy));
    for i = 1:length(energy)%convert Modes back from col vector to grid (each sheet is a mode)
        CurrMode = NaN(size(WF2,1),size(WF2,2));
        CurrMode(ind)=Modes(:,i);%Modes cols are different modes, rows are locations
        ModeShapes(:,:,i)=CurrMode;%Modeshape puts modes back grid location
    end
elseif ndims(data)==2
        ModeShapes = NaN(size(WF2,1),length(energy));
    for i = 1:length(energy)
        ModeShapes(ind,i)=CurrMode;
    end
end

POD_Modes=ModeShapes;
varargout{1}=ind;
end