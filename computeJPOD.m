function [ POD_Modes, Time_Coeff, energy ] = computeJPOD(Nparam, data1, varargin)

% computeJPOD - Computes the joint POD for however many different data
% matrices are inputted into the function. Joint POD sums the correlation
% matrices for all data sets and then projects the POD modes onto the matrix
% indicated "data_ref." 
% 
% Syntax:  [POD_Modes, Time_Coeff, energy ] = computeJPOD(Nparam, data_ref, data1, varargin)
% 
% Inputs: 
%    Nparam     - Number of data matrices inputted. 
%    data_ref    - Data matrix to which POD modes are projected onto. 
%    fsamp - (famp_in) The sampling frequency used to obtain y.
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
%    energy     - Normalized eigenvalues of each POD mode

%% Parse Inputs
p = inputParser;
addRequired( p, 'Nparam'  , @isnumeric)
addRequired( p, 'data1'  , @isnumeric)
if Nparam>1
    for ii=2:Nparam
    addOptional(p, ['data',num2str(ii)]   , @isnumeric);
    end
end

parse(p, Nparam, data1, varargin{:});

Nparam          = p.Results.Nparam;
data1          = p.Results.data1;
data=zeros(size(data1,1),size(data1,2),size(data1,3),Nparam);
data(:,:,:,1)=data1;
if Nparam>1
    for ii=2:Nparam
        data(:,:,:,ii) = p.Results.(['data',num2str(ii)]);    
    end
end


%% Begin Code

    WF2 = data1;

    TT = length(WF2);
    indtest = ones(size(WF2,1),size(WF2,2));
    for i = 1:TT
        indtest = indtest.*(isnan(WF2(:,:,i))==0);
    end
    ind = find(indtest);

    for kk=1:Nparam
        WF = zeros(length(ind),TT);
        for i = 1:TT
            WF3 = data(:,:,i,kk);
            WF(:,i)=reshape(WF3(ind),length(ind),1);
        end

        WFMean = mean(WF,2);
        WF = WF - repmat(WFMean,1,TT);
        C = zeros(length(ind));
        for i = 1:TT
            C=C+WF(:,i)*WF(:,i)'; %99.1% of runtime
            disp([num2str(i/TT.*100),'% Complete'])
        end
        C=C/TT;
        Rmat(:,:,kk)=C;
        clear WF WF3 WMean C
    end
    
    RR=zeros(size(Rmat,1),size(Rmat,2));
    for ii=1:Nparam
        RR=RR+Rmat(:,:,ii);
    end
    C=RR./Nparam;

    [Modes, Values] = eig(C);
    [Modes, Values] = sortem(Modes,Values);
    energy = diag(Values)/sum(sum(Values));

    ModeShapes = NaN(size(WF2,1),size(WF2,2),length(ind));

    for i = 1:length(ind)
        CurrMode = NaN(size(WF2,1),size(WF2,2));
        CurrMode(ind)=Modes(:,i);
        ModeShapes(:,:,i)=CurrMode;
    end
    
        am = length(ind);
        a = zeros(TT,am,Nparam);
    for mm=1:Nparam
    for jj=1:TT
        DR=squeeze(data(:,:,jj,mm));
        DATA_REF(:,jj)=reshape(DR(ind),length(ind),1);
    end

    for i = 1:TT
        for j = 1:am
        a(i,j,mm)=sum(DATA_REF(:,i).*Modes(:,j));
        end
    end
    end
    
    POD_Modes  = ModeShapes;
    Time_Coeff = a;
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

