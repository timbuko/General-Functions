function hout=streamline(varargin)
%%%%%%%%%%%%%%%%%
% edited from Matlab Streamline code. Enter Presure plot and
% velocities, then this will will color the velocities by pressure. 
%Enter the Cp array as the 8th input (after options)
%
%Based off of 
%https://www.mathworks.com/matlabcentral/answers/21382-plot-different-color
%%%%%%%%%%%%%%%%%
%STREAMLINE  Streamlines from 2D or 3D vector data.
%   STREAMLINE(X,Y,Z,U,V,W,STARTX,STARTY,STARTZ) creates streamlines
%   from 3D vector data U,V,W. The arrays X,Y,Z define the coordinates for
%   U,V,W and must be monotonic and 3D plaid (as if produced by MESHGRID). 
%   STARTX, STARTY, and STARTZ define the starting positions of the stream
%   lines.
%   
%   STREAMLINE(U,V,W,STARTX,STARTY,STARTZ) assumes 
%         [X Y Z] = meshgrid(1:N, 1:M, 1:P) where [M,N,P]=SIZE(U). 
%   
%   STREAMLINE(XYZ) assumes XYZ is a precomputed cell array of vertex
%       arrays (as if produced by STREAM3).
%   
%   STREAMLINE(X,Y,U,V,STARTX,STARTY) creates streamlines from 2D
%   vector data U,V. The arrays X,Y define the coordinates for U,V and
%   must be monotonic and 2D plaid (as if produced by MESHGRID). STARTX
%   and STARTY define the starting positions of the streamlines. A vector
%   of line handles is returned.
%   
%   STREAMLINE(U,V,STARTX,STARTY) assumes 
%         [X Y] = meshgrid(1:N, 1:M) where [M,N]=SIZE(U). 
%   
%   STREAMLINE(XY) assumes XY is a precomputed cell array of vertex
%       arrays (as if produced by STREAM2).
%   
%   STREAMLINE(AX,...) plots into AX instead of GCA.
%
%   STREAMLINE(...,OPTIONS) specifies the options used in creating
%   the streamlines. OPTIONS is specified as a one or two element vector
%   containing the step size and maximum number of vertices in a stream
%   line.  If OPTIONS is not specified the default step size is 0.1 (one
%   tenth of a cell) and the default maximum number of vertices is
%   10000. OPTIONS can either be [stepsize] or [stepsize maxverts].
%   
%   H = STREAMLINE(...) returns a vector of line handles.
%
%   Example:
%      load wind
%      [sx sy sz] = meshgrid(80, 20:10:50, 0:5:15);
%      h=streamline(x,y,z,u,v,w,sx,sy,sz);
%      set(h,'Color','red');
%      view(3);
%
%   See also STREAM3, STREAM2, CONEPLOT, ISOSURFACE, SMOOTH3, SUBVOLUME,
%            REDUCEVOLUME.

%   Copyright 1984-2018 The MathWorks, Inc.

[cax,args,nargs] = axescheck(varargin{:});
[verts, x, y, z, u, v, w, sx, sy, sz, options,Cp] = parseargs(nargs,args);


if isempty(cax)
    cax = gca;
end

if isempty(verts)
  if isempty(w)       % 2D
    if isempty(x)
      verts = stream2(u,v,sx,sy,options);
    else
      verts = stream2(x,y,u,v,sx,sy,options);
    end
  else                % 3D
    error('This function only works for 2D fields')
  end
end

h = [];
for k = 1:length(verts)
  vv = verts{k};
  if ~isempty(vv)
      %%%%my addition
      %find Cp value at location closest to (vv(:,1),vv(:,2)) (or interpolate Cp)
      %c=interpolated Cp
      c=interp2(x,y,Cp,vv(:,1),vv(:,2));
      h = [h ;...
          patch([vv(:,1);nan], [vv(:,2);nan],[c;nan],[c;nan],'edgecolor','interp')];
      %%%%
%       h = [h ; line('xdata', vv(:,1), 'ydata', vv(:,2), ...
%               'color', [0 0 1], 'parent', cax)];
   
  end
end

% Register handles with MATLAB code generator
if ~isempty(h)
    if ~isdeployed
        makemcode('RegisterHandle',h,'IgnoreHandle',h(1),'FunctionName','streamline');
    end   
end
    % Disable data tips
    for i = 1:numel(h)
        set(hggetbehavior(h(i), 'DataCursor'), 'Enable', false);
        setinteractionhint(h(i), 'DataCursor', false);
        set(hggetbehavior(h(i), 'Brush'), 'Enable', false);
        setinteractionhint(h(i), 'Brush', false);
    end

    
if nargout>0
  hout=h;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [verts, x, y, z, u, v, w, sx, sy, sz, options, Cp] = parseargs(nin, vargin)

[verts, x, y, z, u, v, w, sx, sy, sz, options, Cp] = deal([]);

if nin==1  % streamline(xyz) or  streamline(xy) 
  verts = vargin{1};
  if ~iscell(verts)
    error(message('MATLAB:streamline:NonCellVertices'))
  end
elseif nin==4 || nin==5           % streamline(u,v,sx,sy)
  [u, v, sx, sy] = deal(vargin{1:4});
  if nin==5, options = vargin{5}; end
  %%%%%%%%%%%%%% my addition %%%%%%%%%%%%55
elseif nin==6 || nin==7 ||nin==8       % streamline(u,v,w,sx,sy,sz) or streamline(x,y,u,v,sx,sy)
  u = vargin{1};
  v = vargin{2};
  if ndims(u)==3
    [w, sx, sy, sz] = deal(vargin{3:6});
  else
    x = u;
    y = v;
    [u, v, sx, sy] = deal(vargin{3:6});
  end
  if nin==7||nin==8
      options = vargin{7}; 
      if nin==8;Cp=vargin{8};end
  end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
elseif nin==9 || nin==10     % streamline(x,y,z,u,v,w,sx,sy,sz)
  [x, y, z, u, v, w, sx, sy, sz] = deal(vargin{1:9});
  if nin==10, options = vargin{10}; end
else
  error(message('MATLAB:streamline:WrongNumberOfInputs')); 
end

sx = sx(:); 
sy = sy(:); 
sz = sz(:); 

