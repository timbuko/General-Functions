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

%% Get data in right form
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

    
%% Calculation
[M,N]=size(WF);
    WFMean = mean(WF,2); %temporal mean
    WF = WF - repmat(WFMean,1,N); %subtract temporal mean
    C=WF*WF'/TT; %C is temporal average AA'\     
    [Modes, Values] = eig(C);
    [Modes, Values] = sortem(Modes,Values); 
    energy = diag(Values)/sum(sum(Values));
    
%% Put data back in original form
    if ndims(data)==3
    ModeShapes = NaN(size(data,1),size(data,2),length(energy));
        for i = 1:length(energy)%convert Modes back from col vector to grid (each sheet is a mode)
            CurrMode = NaN(size(data,1),size(data,2));
            CurrMode(ind)=Modes(:,i);%Modes cols are different modes, rows are locations
            ModeShapes(:,:,i)=CurrMode;%Modeshape puts modes back grid location
        end
    elseif ndims(data)==2
            ModeShapes = NaN(size(data,1),length(energy));
        for i = 1:length(energy)
            ModeShapes(ind,i)=Modes(:,i);
        end
    end
%% Calculate time coefficient
    a = WF'*Modes;
    
    POD_Modes  = ModeShapes; %Each sheet is a mode (so third dim aligns with eigs)
    Time_Coeff = a; %Each row is a time, cols are modes
    varargout{1}=ind;
end

