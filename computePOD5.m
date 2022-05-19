function [ POD_Modes, Time_Coeff, energy,varargout ] = computePOD5(Nparam, varargin)

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
%ComputePOD2 updated from Matts version
%ComputePOD3 updated to allow both POD and JPOD weighted and unweighted -
%             averages data, not R
%ComputePOD4  changed to use a^2 as energy instead of eigenvalues
%ComputePOD5 averages R instead of averaging the data from each geometry
%% Parse Inputs
p = inputParser;
default=false;
defaultOrder=1;
addRequired( p, 'Nparam'  , @isnumeric)
addRequired(p, 'data1', @isnumeric)
for ii=2:Nparam
addOptional(p, ['data',num2str(ii)]   , @isnumeric);
end
addParameter(p,'w', @isnumeric)
addParameter(p,'normalize',default)
addParameter(p,'OrderBy',defaultOrder)


parse(p, Nparam,varargin{:});

Nparam          = p.Results.Nparam;
w               = p.Results.w;

%% Get mask of non-nan points common in all geometries
temp=p.Results.data1;
for kk = 2:Nparam
    temp=temp+p.Results.(['data',num2str(kk)]);
end
if ndims(p.Results.data1)==3
   ind = find(~isnan(sum(temp,3))); %ind - indices with no nans at any time
elseif ndims(p.Results.data1)==2
    ind = find(~isnan(sum(temp,2)));
end

%% Get data in right form
for kk=1:Nparam
    if ndims(p.Results.data1)==3 %If 3D matrix
        data=p.Results.(['data',num2str(kk)]);
        if p.Results.normalize;rms=mean(std(data,0,3,'omitnan'),[1 2],'omitnan');end
        if ~isa(w,'double');w=ones(size(data,1),size(data,2));end
        TT = size(data,3); %TT time indicies  
        WF = zeros(length(ind),TT);
        for i = 1:TT
            WF3 = data(:,:,i); 
            WF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
        end
        w=reshape(w,length(WF3(:)),1);
        %At this point have matrix with each column all the spatial points for a given time 

    elseif ndims(p.Results.data1)==2 %If 2D matrix
        data=p.Results.(['data',num2str(kk)]);
        if p.Results.normalize;rms=mean(std(data,0,2,'omitnan'),'omitnan');end
        if ~isa(w,'double');w=ones(size(data,1),1);end
        TT = size(data,2);
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
    if p.Results.normalize
         C(:,:,kk)=wf*wf'/(rms^2*N); %C is temporal average AA'  
                                     %normalized by the spatially averaged temporal rms
    else
        C(:,:,kk)=wf*wf'/N; %C is temporal average AA'
    end
end
[Vectors, Values] = eig(mean(C,3));
clear C
Psi_tild=Vectors;
Modes=Psi_tild./sqrt(wj);

 %% Time Ceofficient   
 DATA_REF=zeros(M,N);
 a=zeros(N,M,Nparam);
 for kk=1:Nparam
    if ndims(data)==3 %If 3D matrix
        for i = 1:TT
            WF3 = p.Results.(['data',num2str(kk)])(:,:,i); 
            DATA_REF(:,i)=WF3(ind); %reshape non-nan values for a frame into a column
        end
    elseif ndims(data)==2 %If 2D matrix
        DATA_REF = p.Results.(['data',num2str(kk)])(ind,:);
    end
    a(:,:,kk)=DATA_REF'*Psi_tild;
 end
 
 %sort modes and coefficients by energy (sorts by energy of first dataset)
    energy=squeeze(mean(a.^2,1))./sum(squeeze(mean(a.^2,1)));
    if size(energy,1)==1;energy=energy';end
    [~,idx]=sort(energy(:,p.Results.OrderBy));
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

