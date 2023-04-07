function [a,varargout] = zernike_coeffs(phi, M)
% By: Christopher Wilcox and Freddie Santiago
% Feb 18 2010
% Naval Research Laboratory
%Edited by Timothy Bukowski April 2023 to order modes by j = (n(n+2)+m)/2
%and accept any number of modes. Also make it output zernike modes shapes.
% 
% Description: Represent a wavefront as a sum of Zernike polynomials using
%              a matrix inversion.
% 
% This function attempts to solve the a_i's in equation,
% 
%                     M
%                     __
%                    \
%  phi(rho,theta) =  /__  a_i * Z_i(rho,theta)
%                    i=1
% 
% where the Z_i(rho,theta)'s are the Zernike polynomials from the zernfun.m
% file, phi is the wavefront to be represented as a sum of Zernike 
% polynomials, the a_i's are the Zernike coefficients, and M is the number
% of Zernike polynomials to use.
%
% Input:    phi - Phase to be represented as a sum of Zernike polynomials
%                 that must be an nXn array (square)
%           (optional) M - Number of Zernike polynomials to use (Default = 12)
% Output:   a - Zernike coefficients (a_i's) as a vector
% 
% Note: zernfun.m is required for use with this file. It is available here: 
%       http://www.mathworks.com/matlabcentral/fileexchange/7687 
if nargin == 1
    M = 12;
end
if exist('zernfun.m','file') == 0
    error('zernfun.m does not exist! Please download from mathworks.com and place in the same folder as this file.');
else
    x = -1:1/(128-1/2):1;
    [X,Y] = meshgrid(x,x);
    [theta,r] = cart2pol(X,Y);
    idx = r<=1;
    z = zeros(size(X));
    n = repelem(0:M, 1:M+1);
    n = n(1:M);
    m = (0:M-1).*2 - n.*(n+2);
    y = zernfun(n,m,r(idx),theta(idx));
    Zernike = cell(M);
    for k = 1:M
        z(idx) = y(:,k);
        Zernike{k} = z;
    end
    phi_size = size(phi);
    if phi_size(1) == phi_size(2)
        phi = phi.*imresize(double(idx),phi_size(1)/256);
        phi = reshape(phi,phi_size(1)^2,1);
        Z = nan(phi_size(1)^2,M);
        for i=1:M
            Z(:,i) = reshape(imresize(Zernike{i},phi_size(1)/256),phi_size(1)^2,1);
        end
        a = pinv(Z)*phi;
    else
        error('Input array must be square.');
    end
    
    varargout = {Z,n,m};
end