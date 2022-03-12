function [POD_Modes, Time_Coeff, energy,varargout] = computePOD(data)

% computePOD - Computes the POD modes, time coefficients for each mode, and
% energy for each mode for the data set inputted.
% 
% Syntax:  [POD_Modes, Time_Coeff, energy ] = computePOD(data)
% 
% Inputs: 
%    data     - Three dimensional data matrix inputted (space,space,time). 
%
% Outputs: 
%    POD_Modes  - POD modes
%    Time_Coeff - Time coefficients corresponding to each POD mode
%    energy     - Normalized eigenvalues of each POD mode

%Update:2/28/22 Fixed ndims==2 loop to only use WF(ind) -Tim

%1
if ndims(data)==3 %If 3D matrix
    WF2 = data;
    TT = size(WF2,3); %TT time indicies
    indtest = ones(size(WF2,1),size(WF2,2)); %spatial indicies
    for i = 1:TT
        indtest = indtest.*(isnan(WF2(:,:,i))==0);%find locations without nans at any time
    end
    ind = find(indtest); %ind - indices with no nans at any time
%2
    WF = zeros(length(ind),TT);
    for i = 1:TT
        WF3 = WF2(:,:,i); 
        WF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
    end
    %At this point have matrix with each column all the spatial points for a given time 
elseif ndims(data)==2 %If 2D matrix
    TT = size(data,2);
    WF2=data;
    indtest = ones(size(WF2,1),1);
    for i = 1:TT
        indtest = indtest.*(~isnan(WF2(:,i)));
%         indtest = indtest.*(isinf(WF(:,i))==0);
    end
    ind = find(indtest);
    WF = WF2(ind,:);
end
    %At this point have matrix with each column all the spatial points for a given time
    %dim of WF are lenght(ind) by TT

    
%3
[M,N]=size(WF);
tic
    WFMean = mean(WF,2); %temporal mean
    WF = WF - repmat(WFMean,1,N); %subtract temporal mean
    C = zeros(M);
    
    for i = 1:N
        C=C+WF(:,i)*WF(:,i)'; 
        if mod(i,round(N/20))==0;disp([num2str(i/N*100),' %']);end
    end
    C=C/TT; %C is temporal average AA'\        
toc
    [Modes, Values] = eig(C);
    [Modes, Values] = sortem(Modes,Values); 
    energy = diag(Values)/sum(sum(Values));

    
    
%4
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
            CurrMode = NaN(size(WF2,1),1);
            CurrMode(ind)=Modes(:,i);
            ModeShapes(:,i)=CurrMode;
        end
    end
%5    
    a = WF'*Modes;
    POD_Modes  = ModeShapes; %Each sheet is a mode (so third dim aligns with eigs)
    Time_Coeff = a; %Each row is a time, cols are modes
    varargout{1}=ind;
end

