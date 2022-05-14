function [ POD_Modes, Time_Coeff, energy,varargout ] = computePOD3(Nparam, varargin)

% computeJPOD - Computes the joint POD for however many different data
% matrices are inputted into the function. Joint POD sums the correlation
% matrices for all data sets and then projects the POD modes onto the matrix
% indicated "data_ref." Has option to calculate nonuniform POD if w is
% provided. Modes are sorted according to energies of first dataset
% 
% Syntax:  [POD_Modes, Time_Coeff, energy ] = computeJPOD(Nparam, data_ref, w)
% 
% Inputs: 
%    Nparam     - Number of data matrices inputted. 
%    data_ref    - Data matrix to which POD modes are projected onto. 
%    w          - matrix of wieghting (optional)
%
% Optional Inputs:
% +------------+-----------------------------------------------------+
% |    Name    |                        Value                        |
% +------------+-----------------------------------------------------+
% | datax      | Data of different parameter in which joint POD is
%               calculated on
% Outputs: 
%    POD_Modes  - Joint POD modes
%    Time_Coeff - Time coefficients corresponding to each POD mode 
%               - has third dimension corresponding to data sets
%    energy     - Normalized eigenvalues of each POD mode

% Updated 5/5/22 Tim Bukowski to accept 2D data matrix
%ComputePOD4  changed to use a^2 as energy instead of eigenvalues
%% Parse Inputs
p = inputParser;
default=false;
addRequired( p, 'Nparam'  , @isnumeric)
addRequired(p, 'data1', @isnumeric)
for ii=2:Nparam
addOptional(p, ['data',num2str(ii)]   , @isnumeric);
end
addParameter(p,'w', @isnumeric)
addParameter(p,'normalize',default)


parse(p, Nparam,varargin{:});

Nparam          = p.Results.Nparam;
w               = p.Results.w;

if ndims(p.Results.data1)==3
    dat=zeros(size(p.Results.data1,1),size(p.Results.data1,2),size(p.Results.data1,3),Nparam);
    for ii=1:Nparam
        dat(:,:,:,ii) = p.Results.(['data',num2str(ii)]);    
    end
    if p.Results.normalize
        data=mean(dat./mean(std(dat,0,3),[1 2],'omitnan'),4); %combine datasets by taking average
    else                                %divide by spatial average of RMS to normalize if desired
        data=mean(dat,4);
    end
    if ~isa(w,'double');w=ones(size(data,1),size(data,2));end
elseif ndims(p.Results.data1)==2
    dat=zeros(size(p.Results.data1,1),size(p.Results.data1,2),Nparam);
    for ii=1:Nparam
        dat(:,:,ii) = p.Results.(['data',num2str(ii)]);    
    end
    if p.Results.normalize
        data=mean(dat./mean(std(dat,0,2),'omitnan'),3); %combine datasets by taking average
    else                                %divide by RMS to normalize if desired
        data=mean(dat,3);
    end
    if ~isa(w,'double');w=ones(size(data,1),1);end
end

%% Get data in right formm
if ndims(data)==3 %If 3D matrix
    TT = size(data,3); %TT time indicies    
    ind = find(~isnan(sum(data,3))); %ind - indices with no nans at any time
    WF = zeros(length(ind),TT);
    for i = 1:TT
        WF3 = data(:,:,i); 
        WF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
    end
    w=reshape(w,length(WF3(:)),1);
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
[id1,id2]=size(w);
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

C=wf*wf'/N; %C is temporal average AA'\     
[Vectors, Values] = eig(C);
clear C
Psi_tild=Vectors;
Modes=Psi_tild./sqrt(wj);

 %% Time Ceofficient   
 DATA_REF=zeros(M,N);
 a=zeros(N,M,Nparam);
 for kk=1:Nparam
    if ndims(data)==3 %If 3D matrix
        for i = 1:TT
            WF3 = dat(:,:,i,kk); 
            DATA_REF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
        end
    elseif ndims(data)==2 %If 2D matrix
        DATA_REF = dat(ind,:,kk);
    end
    a(:,:,kk)=DATA_REF'*Psi_tild;
 end
 
 %sort modes and coefficients by energy (sorts by energy of first dataset)
    energy=squeeze(mean(a.^2,1))./sum(squeeze(mean(a.^2,1)));
    if size(energy,1)==1;energy=energy';end
    [~,idx]=sort(energy(:,1));
    idx=flipud(idx);
    energy=energy(idx,:);
    Modes = Modes(:,idx);
    a=a(:,idx,:);

%% Reshape back to data form
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


    POD_Modes  = ModeShapes; %Each sheet is a mode (so third dim aligns with eigs) (or each col if 2d)
    Time_Coeff = a; %Each row is a time, cols are modes
    varargout{1}=ind;
end

%% --------- BEGIN SUBFUNCTIONS ---------- %% 
function TF = validScalarPosNum(x)
   if ~isscalar(x)
       error('Input is not scalar');
   elseif ~isnumeric(x)
       error('Input is not numeric');
   elseif (x <= 0)
       error('Input must be > 0');
   else
       TF = true;
   end
end

