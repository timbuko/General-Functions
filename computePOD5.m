function [ POD_Modes, Time_Coeff, energy, varargout ] = computePOD5(data, varargin)
%computePOD - Proper Orthogonal Decomposition (POD) 
% 
%   [POD_Modes, Time_Coeff, energy] = computePOD(DATA) takes an MxN matrix
%   DATA and decomposes it, outputting an MxM matrix with POD modes, a NxM
%   matrix of time coefficients, and a Mx1 matrix of the relative energy of
%   each mode. 
%     If DATA is a cell array of MxN matrices then Joint POD (JPOD) will be
%     performed on the data. The TIME_COEFF and ENERGY outputs will
%     contain a 3rd dimension containing the output for each of the sets in
%     DATA.
%
%   The DATA input can be followed by parameter/value pair to specify
%   additional properties.
% 
%   --- "w" ---
%       1 (default) | scalar | NxM matrix of scalars
%
%   Weights can be specified to wieght the POD calculation. Grid spacing
%   must be used for weight to get correct reconstruction using POD. A
%   scalar value can be entered if grid is uniform. If nonuniform a matrix
%   of same spatial dimension as the data must be used. 
%
%   --- "normalize" ---
%       logical 1 [true] (default) | logical 0 [false]
%
%   If doing JPOD you can normalize the datasets, so they have even
%   contribution to the mode calculation. This normalizes by the spatial
%   average of the temporal standard deviation of the dataset. 
%
%   --- "OrderBy" ---
%       1 (default) | positive scalar
%
%   If doing JPOD you can choose how to order the Modes. In JPOD the mode
%   number is arbitrary since they order may be different for each dataset.
%   Here the element number in the cell array corresponding to the dataset 
%   you would like to use to order the modes (high to low energy)
%
%   --- "output" ---
%       "mask" | "eigenvalues" | "absoluteEnergy"
%
%   Can output additional parameters like the mask showing non-nan, 
%   or eigenvalues found when solving the POD modes, or the absolute energy
%   of the modes (not normalized by total energy)
% 
% DESCRIPTION _____________________________________________________________
%
%   For an input dataset p(s,t), POD solves for modes Φ(s) and temporal
%   coefficients a(t) such that 
%
%           p(s,t) = sum a_n(t)Φ_n(s)
%                     n
%
%   The modes are found by solving the eigenvalue problem 
%
%           int R(s,s')Φ(s')ds' = λ_n Φ_n(s)
%
%   where R is the cross correlation function and R = <p(s,t)p(s',t)>  and 
%   λ are the energy associated with the modes, however in this code
%   the temporal mean of the temporal coeff <a^2_n(t)> is used as the energy. 
%
%   If multiple datasets are given then JPOD will be executed. In this the
%   data is averaged together and then POD is done on the joint dataset
%   giving Joint modes. Then these modes are mapped back onto the datasets
%   to get the temporal coefficients and energies. 
%   
%   There are two checks to see if POD worked correctly:
%            xtas
%
%   This function only works for 1 and 2 spatial dimension data
%   Energy computed from 'a' and energy from eigenvalue should be the same
%   (when not doing JPOD). So 'a' is used here. 
%
%
% Updated 5/5/22 Tim Bukowski to accept 2D data matrix
%ComputePOD2 updated from Matts version
%ComputePOD3 updated to allow both POD and JPOD weighted and unweighted -
%             averages data, not R 
%ComputePOD4  changed to use a^2 as energy instead of eigenvalues
%ComputePOD5 averages R instead of averaging the data from each geometry
%            fixed so that it uses mean removed data to find time coeff
%
%
% Written by Timothy Bukowski May 1, 2022
%
%% Parse Inputs
p = inputParser;
validData = @(x) isnumeric(x) || iscell(x);
default=false;
defaultOrder=1;

addRequired(p, 'data', validData)
addParameter(p,'w', @isnumeric)
addParameter(p,'normalize',default)
addParameter(p,'OrderBy',defaultOrder)
addParameter(p,'output',@isstring)

if isnumeric(data)
    data = {data};
end
parse(p,data,varargin{:});
clear varargin data

w = p.Results.w;
%% Get mask of non-nan points common in all geometries
Nparam = length(p.Results.data);
dim = ndims(p.Results.data{1});
temp = p.Results.data{1}*0;
for kk = 1:Nparam
    temp=temp+p.Results.data{kk};
end

if dim==3
    mask = ~isnan(sum(temp,3)); %ind - indices with no nans at any time
elseif dim==2
    mask = ~isnan(sum(temp,2));
end
clear temp

%% Get data in right form
for kk=1:Nparam
    if dim == 3  %If 3D matrix
        data=p.Results.data{kk};
        if p.Results.normalize;rms=mean(std(data,0,3,'omitnan'),[1 2],'omitnan');end
        if ~isa(w,'double');w=ones(size(data,1),size(data,2));end
        N = size(data,3); 
        M = sum(mask,'all');
        mask3D = repmat(mask,1,1,N);
        WF{kk} = reshape(data(mask3D),M,N);
        %At this point have matrix with each column all the spatial points for a given time 

    elseif dim == 2 %If 2D matrix
        data=p.Results.data{kk};
        if p.Results.normalize;rms=mean(std(data,0,2,'omitnan'),'omitnan');end
        if ~isa(w,'double');w=ones(size(data,1),1);end
        WF{kk} = data(mask,:);
    end
        %At this point have matrix with each column all the spatial points for a given time
        %dim of WF are M by N, where M is the number on non-nan valued spatial
        %locations

%%  Create correlation matrix
    [M,N]=size(WF{kk});
    if isscalar(w)
        wj = repmat(w,M,1);
    else
        wj=w(mask);
    end
    
    WFMean = mean(WF{kk},2); %temporal mean
    WF{kk} = WF{kk} - repmat(WFMean,1,N); %subtract temporal mean
    wf=WF{kk}.*sqrt(wj);
    clear WFMean
    if p.Results.normalize
         C(:,:,kk)=wf*wf'/(rms^2*N); %C is temporal average AA'  
                                     %normalized by the spatially averaged temporal rms
    else
        C(:,:,kk)=wf*wf'/N; %C is temporal average AA'
    end
end
%% Solve eigenvalue problem for POD modes 
[Psi_tild, Values] = eig(mean(C,3));
clear C
Modes=Psi_tild./sqrt(wj);

 %% Time Ceofficient   
 a=zeros(N,M,Nparam);
 for kk=1:Nparam
    a(:,:,kk)=(WF{kk}.*sqrt(wj))'*Psi_tild;
 end
 
 %sort modes and coefficients by energy (sorts by energy of first dataset by default)
    energy=squeeze(mean(a.^2,1))./sum(squeeze(mean(a.^2,1)));
    if size(energy,1)==1;energy=energy';end
    [~,idx]=sort(energy(:,p.Results.OrderBy));
    idx=flipud(idx);
    energy=energy(idx,:);
    Modes = Modes(:,idx);
    Time_Coeff=a(:,idx,:);

%% Reshape back to data form
    if dim==3
        POD_Modes = NaN(size(data,1),size(data,2),length(energy));
        mask3D = repmat(mask,1,1,length(energy));
        POD_Modes(mask3D) = Modes(:);
    elseif dim==2
        POD_Modes = NaN(size(data,1),length(energy));
        POD_Modes(mask,:)=Modes;
    end


%% Outputs
    POD_Modes; %Each sheet is a mode (so third dim aligns with eigs) (or each col if 2D)
    Time_Coeff; %Each row is a time, cols are modes
    energy; % vector of relative energies for each mode 
    
    if strcmpi(p.Results.output,'mask')
        varargout{1} = mask;
    elseif strcmpi(p.Results.output,'eigenvalue')||strcmpi(p.Results.output,'eigenvalues')
        varargout{1} = flip(diag(Values));
    elseif strcmpi(p.Results.output,'absoluteEnergy')
        varargout{1} = energy.*sum(squeeze(mean(a.^2,1)));
    end
        
end