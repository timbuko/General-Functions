%--------------------------------------------------------------------
%
%   AERODAQ
%
%	Brian W. Neiswander
%   University of Notre Dame
%
%   This program provides a GUI front end for data acquisition
%   and stepper motor control using a Data Translation 9830
%   USB DAQ board and PDO3540 Stepper Motor Driver.  It is designed
%	for use in the Notre Dame undergraduate aerodynamics lab.
%
%   The program allows users to specify analog-in parameters,
%   the numer and directions of steps to the stepper motor,
%   and various save options.  A REPETITION field was included
%   to loop through mulitiple acquisitions.  
%
%	Common applications include:
%   ---------------------------------------
%		-  boundary layer profiles (hotwire, stepper)
%		-  airfoil static pressure data (Scanivalve)
%		-  measuring CL and CD curves (force balance, stepper)
% 
%   Update Log:
%   ---------------------------------------
%   	January 24, 2012 by Brian Neiswander
%		- added 'Delete' button
%       - changed DO stepper control to AO
%
%  	 	January 27, 2012 by Brian Neiswander
%       - AO codes randomly crash MATLAB and require restart
%       - Changed stepper motor control back to DO
%		- Deleted 'Enable' option from stepper control
%       - Changed DO pulse forming code to be more time-efficient
%       - Changed DO output frequency from 1kHz to 600Hz.  The motor
%         seems to run smoother and MATLAB is able to produce a cleaner
%         pulse train.
%
%		February 9, 2012 by Brian Neiswander
%		- Tomko noticed that the motor works better with Enable option 
%		  included.  Added 'Enable' option back to stepper control
%
%		February 10, 2012 by Brian Neiswander
%		-  Added timeout field
%       -  Added Mean with STD Bars plot option
%       -  Added Scanivalve home when pressing Go to Zero
%       -  Deleted disabling of Set Zero and Go to Zero buttons
%       -  Changed time series xlabel to "Time, s" not "Time, ms"
%       -  Changed legend location to "Best"
%
%   	February 22, 2012 by Brian Neiswander
%       -  Changed Enable to be LOW always.  Otherwise stepper motor
%          for finite wing lab does not move.
%		-  Changed name from aerolab_utility to aero-daq
%
%   	April 10, 2014 by Kyle Heintz
%       -  Added "Pause" feature to pause data acquisition mid-test
%
%       January 20, 2015 by Brian Neiswander
%       - Updated A+/A- wire colors for boundary layer traverse lab
%
%       January 29, 2016 by Eric Matlis
%       - Changed DIO Step from DIO 1 (output 21) to DIO 4 (output 24)
%         due to a suspected bad DIO output stage, causing motor
%         not to run.  See line 1616.  Changed to pin 25 1/25/2017.
%
%   Digital Out Notes:
%   ---------------------------------------
%   	DIO 0 PIN20  - Motor controller direction
%   xxxx	DIO 1 PIN21  - Motor controller steps or Scannivalve next
%   xxxx	DIO 4 PIN24  - Motor controller steps or Scannivalve next
%   	DIO 5 PIN25  - Z Motor controller steps or Scannivalve next
%   	DIO 6 PIN26  - X Motor controller steps
%   	DIO 3 PIN23  - Scannivalve return
%   	GND PIN37
%
%   PDO3540 Notes:
%   ---------------------------------------
%   	Jumpers:  1L, 2H, 3L, 4L, 5L, 6L  = step mode & 200 steps/inch
%	              1H, 2L, 3L, 4L, 5L, 6H, 7L, 8L = 2.0A/phase, 50% idle ON
%   	It's VERY important that OSC BYPASS jumper is set to HIGH.
%   	Current setting may be lower but can not exceed the motor rating.
%   	Lower current will result in less torque.
%
%   Motor Notes:
%   ---------------------------------------
%       UPDATED 1-20-15
%   	Boundary layer traverese:
%   		Motor:  HT32-401D
%   		Calibration:  4000 steps/inch (200 steps/turn * 20 turns/inch)
%   		A+: red,orange  (controller wire color,motor wire color)
%           A-: white,black
%   		B+: black,red
%   		B-: green,yellow
%   		shorts: yellow/white & red/white, black/white & orange/white
%   	Force balance (red tunnel):
%      	 	Motor: Superior Electric M062-FD03
%      	 	Calibration: 200 steps per degree
%      	 	A+: red,red (controller wire color,motor wire color)
%      	 	A-: green,red/white
%      	 	B+: white,green
%      	 	B-: black,green/white
%      	 	unconnected: black, white
%   	Force balance (general Hessert lab):
%   		Motor: Superior Electric M062-FD03
%   		Calibration: unknown
%   		A+: red&black,green/white  (controller wire color,motor wire color)
%   		A-: green&black,green
%   		B+: blue&black,red
%   		B-: white&black,red/white
%   		unconnected: black, white
%
%
% JUMPER SETTINGS FOR MOTORS
% Force balance  - Jumper2 & Jumper4 high  = 0.4+0.8+0.2=1.4A
% Linear traverse - Jumper1 high  = 0.4+1.6  = 2.0A
%--------------------------------------------------------------------

function aerolab_utility

close all;

%get screen size
ss  = get(0,'ScreenSize');
scw  = round(ss(3)/2);      %screen center width  [px]
sch  = round(ss(4)/2);      %screen center height [px]
clear ss;

%initialize additional parameters stored in handle structure
h.fontname  = 'Verdana';
h.fontsize  = 8;
h.position  = 0;
h.colormap  = 'lines';
h.colors    = eval([h.colormap '(8);']);
h.markers   = {'x','^','sq','v','p','+','<','o','>','*'};
h.acq.timeseries.path  = [];
h.acq.timeseries.defaultpath  = pwd;
h.acq.timeseries.data  = [];
h.acq.mean  = [];
h.acq.std   = [];
h.plot1.x   = [];
h.plot1.y   = [];
h.plot2.x   = [];
h.plot2.y   = [];
h.dio_settings.fs    = 200;  %[Hz] 200=force balance, 500=linear traverse
h.dio_settings.duty  = 0.5; 

%construct the gui window
%make figure
%fw  = 800;   %figure width  [px]
% EMatlis GUI
fw  = 1200;   %figure width  [px]
fh  = 650;   %figure height [px]
h.fig  = figure(                                ...
    'Color',            [1.0 1.0 1.0],          ...
    'MenuBar',          'none' ,                ...
    'NumberTitle',      'off',                  ...
    'Resize',           'off',                  ...
    'Toolbar',          'none',                 ...
    'Name',             'AeroDAQ', ...
    'Position',         [scw-fw/2 sch-fh/2 fw fh]);

%create AI panel
h.ai.panel  = uipanel(                          ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Analog In',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.03 .69 .2 .29]);
% EMatlis GUI
%    'Position',         [.03 .69 .3 .29]);
h.ai.checkbox.data  = uicontrol(                ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'checkbox',             ...
    'String',           'Enable analog in',     ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'Value',            1,                      ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 140 200 20],        ...
    'Callback',         @data_checkbox_callback);
h.ai.text.channels  = uicontrol(                ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Channels',             ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 100 100 20]);
h.ai.edit.channels  = uicontrol(                ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '0,1,2',                    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 97 100 25],        ...
    'Callback',         @channels_callback);
h.ai.text.fs  = uicontrol(                      ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Sampling [Hz]',        ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 60 100 20]);
h.ai.edit.fs  = uicontrol(                      ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '1000',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 57 100 25],        ...
    'Callback',         @fs_callback);
h.ai.text.npts  = uicontrol(                    ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'No. Samples',          ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 20 100 20]);
h.ai.edit.npts  = uicontrol(                    ...
    h.ai.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '10000',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 17 100 25],         ...
    'Callback',         @npts_callback);
%create X motor control panel
h.doX.panel  = uipanel(                          ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Digital Out X',          ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.03 .31 .2 .36]);
h.doX.checkbox.motor  = uicontrol(               ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'checkbox',             ...
    'String',           'Enable digital out',   ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Value',            1,                      ...
    'Position',         [10 180 200 20],        ...
    'Callback',         @Xmotorcheckbox_callback);
h.doX.text.nsteps  = uicontrol(                  ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'No. Steps',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 140 100 20]);
h.doX.edit.nsteps  = uicontrol(                  ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '200',                  ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 137 100 25],       ...
    'Callback',         @Xnsteps_callback);
h.doX.text.direction  = uicontrol(               ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Direction',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 100 100 20]);
h.doX.radiobutton.group = uibuttongroup(         ...
    'Parent',           h.doX.panel,             ...
    'Title',            '',                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'BorderType',       'none',                 ...
    'Position',[.1 0 .8 .6]);
h.doX.radiobutton.fdir  = uicontrol(             ...
    h.doX.radiobutton.group,                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'radiobutton',          ...
    'String',           'Pos.',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [85 100 100 25]);
h.doX.radiobutton.bdir  = uicontrol(             ...
    h.doX.radiobutton.group,                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'radiobutton',          ...
    'String',           'Neg.',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [140 100 60 25]);
h.doX.text.position_label  = uicontrol(          ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Step Position',        ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 60 100 20]);
h.doX.text.position  = uicontrol(                ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'text',                 ...
    'String',           '0',                    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 60 100 20]);
h.doX.pushbutton.return  = uicontrol(            ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Go to Zero',           ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Enable',           'on',                   ...
    'Position',         [120 20 100 20],        ...
    'Callback',         @Xreturn_callback);
h.doX.pushbutton.zero  = uicontrol(              ...
    h.doX.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Set Zero',             ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Enable',           'on',                  ...
    'Position',         [10 20 100 20],         ...
    'Callback',         @Xzero_callback);

% EMATLIS GUI
%create Z motor control panel
h.doZ.panel  = uipanel(                          ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Digital Out Z',          ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.23 .31 .2 .36]);
h.doZ.checkbox.motor  = uicontrol(               ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'checkbox',             ...
    'String',           'Enable digital out',   ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Value',            1,                      ...
    'Position',         [10 180 200 20],        ...
    'Callback',         @Zmotorcheckbox_callback);
h.doZ.text.nsteps  = uicontrol(                  ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'No. Steps',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 140 100 20]);
h.doZ.edit.nsteps  = uicontrol(                  ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '200',                  ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 137 100 25],       ...
    'Callback',         @Znsteps_callback);
h.doZ.text.direction  = uicontrol(               ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Direction',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 100 100 20]);
h.doZ.radiobutton.group = uibuttongroup(         ...
    'Parent',           h.doZ.panel,             ...
    'Title',            '',                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'BorderType',       'none',                 ...
    'Position',[.1 0 .8 .6]);
h.doZ.radiobutton.fdir  = uicontrol(             ...
    h.doZ.radiobutton.group,                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'radiobutton',          ...
    'String',           'Pos.',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [85 100 100 25]);
h.doZ.radiobutton.bdir  = uicontrol(             ...
    h.doZ.radiobutton.group,                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'radiobutton',          ...
    'String',           'Neg.',                 ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [140 100 60 25]);
h.doZ.text.position_label  = uicontrol(          ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Step Position',        ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 60 100 20]);
h.doZ.text.position  = uicontrol(                ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'text',                 ...
    'String',           '0',                    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 60 100 20]);
h.doZ.pushbutton.return  = uicontrol(            ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Go to Zero',           ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Enable',           'on',                   ...
    'Position',         [120 20 100 20],        ...
    'Callback',         @Zreturn_callback);
h.doZ.pushbutton.zero  = uicontrol(              ...
    h.doZ.panel,                                 ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Set Zero',             ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Enable',           'on',                  ...
    'Position',         [10 20 100 20],         ...
    'Callback',         @Zzero_callback);



%create execute panel
h.execute.panel  = uipanel(                     ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Execute',              ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.03 .05 .2 .24]);
h.execute.text.repetitions  = uicontrol(        ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Repetitions',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 100 100 20]);
h.execute.edit.repetitions  = uicontrol(        ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '1',                    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 97 100 25],        ...
    'Callback',         @repetitions_callback);
h.execute.text.timeout  = uicontrol(        ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Timeout [s]',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 60 100 20]);
h.execute.edit.timeout  = uicontrol(        ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'edit',                 ...
    'String',           '0',                    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [110 57 100 25],        ...
    'Callback',         @repetitions_callback);
h.execute.pushbutton.run  = uicontrol(          ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Run',                  ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'Position',         [10 10 210 25],         ...
    'UserData',         0,                      ...
    'Callback',         @start_callback);


%create status listbox
h.status.listbox  = uicontrol(                  ...
    h.fig,                                      ...
    'BackgroundColor',  [1 1 1],                ...
    'Style',            'listbox',              ...
    'Max',              1000,                   ...
    'Min',              1,                      ...
    'String',           {},                     ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','left',               ...
    'ListboxTop',       1000,                   ...
    'Position',         [538 480 440 144]);
h.status.text  = uicontrol(                     ...
    h.execute.panel,                            ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'text',                 ...
    'String',           'Program Status',       ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [512 585 440 20]);

%create axes
h.axes.ts    = axes('Position',[.47 .43 .3 .25]);
h.axes.mean  = axes('Position',[.47 0.08 .3 .25]);
h  = update_plot1(h);
h  = update_plot2(h);

%plot 1 panel
h.plot1.panel  = uipanel(                       ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Data',...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.8 .425 .15 .27]);
h.plot1.popupmenu  = uicontrol(                 ...
    h.plot1.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'popupmenu',            ...
    'String',           {'Time-series','Running Average','FFT'},       ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 120 160 20],        ...
    'Callback',         @plot1popup_callback);
h.plot1.pushbutton.clf  = uicontrol(            ...
    h.plot1.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Delete All',      ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 75 100 20],         ...
    'Enable',           'off',                  ...
    'Callback',         @plot1_removealldata_callback);
h.plot1.pushbutton.save  = uicontrol(           ...
    h.plot1.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Save',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 45 100 20],         ...
    'Enable',           'off',                  ...
    'Callback',         @plot1_save_callback);
h.plot1.checkbox.autosave  = uicontrol(         ...
    h.plot1.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'checkbox',             ...
    'String',           'Autosave time-series', ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 5 150 20],          ...
    'Enable',           'off',                  ...
    'Callback',         @plot1_autosave_callback);


%plot 2 panel
h.plot2.panel  = uipanel(                       ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Parent',           h.fig,                  ...
    'Title',            'Data History',    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'bold',                 ...
    'Position',         [.8 .075 .15 .27]);
h.plot2.popupmenu  = uicontrol(                 ...
    h.plot2.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'popupmenu',            ...
    'String',           {'Mean','Standard Deviation', 'Mean with STD Bars'},       ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Value',            1,                      ...
    'Position',         [10 125 160 20],          ...
    'Callback',         @plot2popup_callback);
h.plot2.pushbutton.removedata  = uicontrol(            ...
    h.plot2.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Delete',           ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 80 100 20],          ...
    'Enable',           'off',                  ...
    'Callback',         @plot2_remove_data);
h.plot2.pushbutton.clf  = uicontrol(            ...
    h.plot2.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Delete All',      ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 50 100 20],          ...
    'Enable',           'off',                  ...
    'Callback',         @plot2_removealldata_callback);
h.plot2.pushbutton.save  = uicontrol(                  ...
    h.plot2.panel,                              ...
    'BackgroundColor',  [1.0 1.0 1.0],          ...
    'Style',            'pushbutton',           ...
    'String',           'Save',            ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'HorizontalAlignment','center',             ...
    'Position',         [10 20 100 20],          ...
    'Enable',           'off',                  ...
    'Callback',         @plot2_save_callback);

%store handles in userdata
set(gcf,'UserData',h);

%update status
sdisp(h,'GUI created successfully.');


%--------------------------------------------------------------------
function start_callback(hObject,eventdata)

%get handles
h  = get(gcf,'UserData');

%update button text and userdata
if ~get(h.execute.pushbutton.run,'UserData')
    set(h.execute.pushbutton.run,'UserData',1);
    set(h.execute.pushbutton.run,'String','Pause/Stop');
    %set(h.execute.pushbutton.run,'Enable','off');
    set(h.execute.pushbutton.run,'BackgroundColor',[.96 .7 .7]);
else
    set(h.execute.pushbutton.run,'UserData',0);
    set(h.execute.pushbutton.run,'String','Pausing');
    set(h.execute.pushbutton.run,'Enable','off');
    set(h.execute.pushbutton.run,'BackgroundColor',[.9 .9 .6]);
    %set(h.execute.pushbutton.run,'BackgroundColor',[1.0 1.0 1.0]);
    return;
end

%get values from gui elements
channels   = get(h.ai.edit.channels,'String');
channels   = eval(['[' channels ']']);
channels   = unique(channels);
channels   = sortrows(channels')';
nchan      = length(channels);
fs         = str2double(get(h.ai.edit.fs,'String'));
npts       = str2double(get(h.ai.edit.npts,'String'));
Xnsteps     = str2double(get(h.doX.edit.nsteps,'String'));
Znsteps     = str2double(get(h.doZ.edit.nsteps,'String'));
Xmdir       = get(h.doX.radiobutton.fdir,'Value');
Zmdir       = get(h.doZ.radiobutton.fdir,'Value');
N          = str2double(get(h.execute.edit.repetitions,'String'));
timeout    = str2double(get(h.execute.edit.timeout,'String'));
flag_ai    = get(h.ai.checkbox.data,'Value');
flag_ts    = get(h.plot1.checkbox.autosave,'Value');
flag_doX    = get(h.doX.checkbox.motor,'Value');
flag_doZ    = get(h.doZ.checkbox.motor,'Value');
flag_stop  = 0;
path_ts    = h.acq.timeseries.path;
flag_yestoall  = 0;
if get(h.doX.radiobutton.fdir,'Value')
    Xdirection  = 1;
else
    Xdirection  = 0;
end
if get(h.doZ.radiobutton.fdir,'Value')
    Zdirection  = 1;
else
    Zdirection  = 0;
end

%begin execution
if get(h.execute.pushbutton.run,'UserData')
    sdisp(h,'Starting process.');
    for ai  = 1:N
        %check for stop
        drawnow;
        if ~get(h.execute.pushbutton.run,'UserData')
            cont=run_paused;
            if cont==0
                set(h.execute.pushbutton.run,'String','Run');
                set(h.execute.pushbutton.run,'BackgroundColor',[1.0 1.0 1.0]);
                flag_stop  = 1;
                break
            else
                set(h.execute.pushbutton.run,'UserData',1);
                set(h.execute.pushbutton.run,'String','Stop');
                set(h.execute.pushbutton.run,'BackgroundColor',[.96 .7 .7]);
                set(h.execute.pushbutton.run,'Enable','on');
            end
        end
        
        %take data
        if flag_ai
            %check for channel size versus mean data
            [r,c]  = size(h.acq.mean);
            if ~isequal(nchan,c) && r && c
                sdisp(h,sprintf('Data error, nchan = %i, h.acq.mean size = %ix%i.',nchan,r,c));
                errordlg('Number of channels is not equal to that found in plot data.  Adjust the number of channels or clear Plot 2 data to continue.', 'Error', 'modal');
                break;
            end
            
            %acquire data
            sdisp(h,sprintf('Acquiring data %i of %i.',ai,N));
            %h.acq.timeseries.data    = rand(npts,nchan);
            h.acq.timeseries.data  = acquire(channels,fs,npts);
            
            %update mean and std dev arrays
            [r,c]  = size(h.acq.mean);
            if r && c
                %add to arrays
                h.acq.mean(end+1,:)  = mean(h.acq.timeseries.data,1);
                h.acq.std(end+1,:)  = std(h.acq.timeseries.data,1);
            else
                %create arrays
                h.acq.mean(1,:)  = mean(h.acq.timeseries.data,1);
                h.acq.std(1,:)   = std(h.acq.timeseries.data,1);
            end
            
            %status update
            for bi  = 1:nchan
                %sdisp(h,sprintf('Ch%i mean = %2.2f mV, std = %2.2f mV.',channels(bi),h.acq.mean(end,bi),h.acq.std(end,bi)));
                sdisp(h,sprintf('Ch%i mean = %2.4f V, std = %2.4f V.',channels(bi),h.acq.mean(end,bi),h.acq.std(end,bi)));
            end
            
            %save time series data
            if flag_ts
                %fn  = sprintf('timeseries%04i.mat',ai);
                fn  = sprintf('%s%04i.mat',h.prefix,ai);
                
                %check for existing files
                olddir  = pwd;
                cd(h.acq.timeseries.path);
                bull  = exist(fn,'file');
                cd(olddir);
                if bull && ~flag_yestoall
                    b  = questdlg(['The file ' fn ' already exist'], 'Do you want to overwrite', ...
                        'Yes to all','Yes','Stop','Stop');
                    if isequal(b,'Yes to all')
                        flag_yestoall  = 1;
                    elseif isequal(b,'Stop')
                        flag_stop  = 1;
                        break;
                    end
                end
                %write data to file
                if ~bull || isequal(b,'Yes') || flag_yestoall
                    timeseries  = h.acq.timeseries.data;
                    step_position  = h.position;
                    save([h.acq.timeseries.path filesep fn],'timeseries','step_position','fs','channels','npts');
                    clear timeseries step_position;
                    sdisp(h,['Saved times-series data to ' fn '.']);
                else
                    sdisp(h,['Skipped saving time-series file ' fn '.']);
                end
            end 
            
            %update plots
            h  = update_plot1(h);
            h  = update_plot2(h);
        end
        
        %check for stop
        drawnow;
        if ~get(h.execute.pushbutton.run,'UserData')
            cont=run_paused;
            if cont==0
                set(h.execute.pushbutton.run,'String','Run');
                set(h.execute.pushbutton.run,'BackgroundColor',[1.0 1.0 1.0]);
                flag_stop  = 1;
                break
            else
                set(h.execute.pushbutton.run,'UserData',1);
                set(h.execute.pushbutton.run,'String','Stop');
                set(h.execute.pushbutton.run,'BackgroundColor',[.96 .7 .7]);
                set(h.execute.pushbutton.run,'Enable','on');
            end
        end
        
        %move X stepper motor
        if flag_doX
            %skip the last step if ai is turned on.
            if (isequal(ai,N) && flag_ai)
               	sdisp(h,'Skipping last motor movement.');
               	sdisp(h,'Skipping last timeout.');
            else
                %status update
                sdisp(h,sprintf('Moving X %i steps in the %i direction.',Xnsteps,Xdirection));

                %move nsteps
                do_moveX(Xnsteps,Xdirection);
               % move_stepper(nsteps,direction);

                %change position
                h.position  = h.position + Xnsteps*(2*Xmdir-1);
                set(gcf,'UserData',h);

                %enable/disable motor buttons as needed
                if isequal(h.position,0)
                    %set(h.do.pushbutton.return,'Enable','off');
                    %set(h.do.pushbutton.zero,'Enable','off');
                else
                    %set(h.do.pushbutton.return,'Enable','on');
                    %set(h.do.pushbutton.zero,'Enable','on');
                end

                %set position indicator
                set(h.doX.text.position,'String',sprintf('%i',h.position));

                %status update
                sdisp(h,['Current X position at ' num2str(h.position) '.']);

				%do timeout
				sdisp(h,sprintf('Timeout for %2.2f seconds.',timeout));
				pause(timeout);
            end
        end
        %move Z stepper motor
        if flag_doZ
            %skip the last step if ai is turned on.
            if (isequal(ai,N) && flag_ai)
               	sdisp(h,'Skipping last motor movement.');
               	sdisp(h,'Skipping last timeout.');
            else
                %status update
                sdisp(h,sprintf('Moving Z %i steps in the %i direction.',Znsteps,Zdirection));

                %move nsteps
                do_moveZ(Znsteps,Zdirection);
               % move_stepper(nsteps,direction);

                %change position
                h.position  = h.position + Znsteps*(2*Zmdir-1);
                set(gcf,'UserData',h);

                %enable/disable motor buttons as needed
                if isequal(h.position,0)
                    %set(h.do.pushbutton.return,'Enable','off');
                    %set(h.do.pushbutton.zero,'Enable','off');
                else
                    %set(h.do.pushbutton.return,'Enable','on');
                    %set(h.do.pushbutton.zero,'Enable','on');
                end

                %set position indicator
                set(h.doZ.text.position,'String',sprintf('%i',h.position));

                %status update
                sdisp(h,['Current Z position at ' num2str(h.position) '.']);

				%do timeout
				sdisp(h,sprintf('Timeout for %2.2f seconds.',timeout));
				pause(timeout);
            end
        end
    end % for ai=1:N
    
    %status update
    if flag_stop
        sdisp(h,'Process stopped.');
    else
        sdisp(h,'Process complete.');
    end
    
    set(h.execute.pushbutton.run,'String','Run');
    set(h.execute.pushbutton.run,'BackgroundColor',[1.0 1.0 1.0]);
end

%return scannivalve
if flag_doZ
    sdisp(h,'Sending return pulse to Scannivalve.');   
    Zdo_gohome;
end

%update plot buttons
set(h.plot1.pushbutton.clf,'Enable','on');
set(h.plot1.pushbutton.save,'Enable','on');
set(h.plot2.pushbutton.clf,'Enable','on');
set(h.plot2.pushbutton.save,'Enable','on');
set(h.plot2.pushbutton.removedata,'Enable','on');

%update start button
% set(h.execute.pushbutton.run,'String','Run');
set(h.execute.pushbutton.run,'Enable','on');
%set(h.execute.pushbutton.run,'BackgroundColor',[1.0 1.0 1.0]);
set(h.execute.pushbutton.run,'UserData',0);

%update autosave checkbox
set(h.plot1.checkbox.autosave,'Value',0);

%write finished message
sdisp(h,'Done.');

%update handles
set(gcf,'UserData',h);

function cont=run_paused()
cont=0;
while true
    res=questdlg('Data acquisition paused','Run Paused','Resume','Stop','Resume');
    if strcmp(res,'Resume')
        cont=1;
        break;
    elseif strcmp(res,'Stop')
        cont=0;
        break;
    end
end


%--------------------------------------------------------------------
function data_checkbox_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%set the save checkboxes and pushbuttons appropriately
if get(h.ai.checkbox.data,'Value')
    set(h.ai.edit.channels,'Enable','on');
    set(h.ai.edit.fs,'Enable','on');
    set(h.ai.edit.npts,'Enable','on');
    sdisp(h,'Analog in is enabled.');
else
    set(h.ai.edit.channels,'Enable','off');
    set(h.ai.edit.fs,'Enable','off');
    set(h.ai.edit.npts,'Enable','off');
    sdisp(h,'Analog in is disabled.');
end


%--------------------------------------------------------------------
function Xmotorcheckbox_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%set the save checkboxes and pushbuttons appropriately
if get(h.doX.checkbox.motor,'Value')
    set(h.doX.edit.nsteps,'Enable','on');
    set(h.doX.radiobutton.fdir,'Enable','on');
    set(h.doX.radiobutton.bdir,'Enable','on');
    if h.position
        %set(h.do.pushbutton.return,'Enable','on');
        %set(h.do.pushbutton.zero,'Enable','on');
    end
    sdisp(h,'Digital out X is enabled.');
else
    set(h.doX.edit.nsteps,'Enable','off');
    set(h.doX.radiobutton.fdir,'Enable','off');
    set(h.doX.radiobutton.bdir,'Enable','off');
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    sdisp(h,'Digital out X is disabled.');
end

function Zmotorcheckbox_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%set the save checkboxes and pushbuttons appropriately
if get(h.doZ.checkbox.motor,'Value')
    set(h.doZ.edit.nsteps,'Enable','on');
    set(h.doZ.radiobutton.fdir,'Enable','on');
    set(h.doZ.radiobutton.bdir,'Enable','on');
    if h.position
        %set(h.do.pushbutton.return,'Enable','on');
        %set(h.do.pushbutton.zero,'Enable','on');
    end
    sdisp(h,'Digital out Z is enabled.');
else
    set(h.doZ.edit.nsteps,'Enable','off');
    set(h.doZ.radiobutton.fdir,'Enable','off');
    set(h.doZ.radiobutton.bdir,'Enable','off');
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    sdisp(h,'Digital out Z is disabled.');
end


%--------------------------------------------------------------------
function sdisp(h,str)

%get existing status box entries
status  = get(h.status.listbox,'String');

%add new entry
status{end+1}  = ['[' num2str(datestr(now,13)) ']  ' str];

%update status to listbox
set(h.status.listbox,'String',status);

%set focus to new entry
set(h.status.listbox,'Value',length(status));

%flush buffer
drawnow;


%--------------------------------------------------------------------
function fs_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%get sampling frequency
fs  = str2double(get(h.ai.edit.fs,'String'));

%error check input
if fs<1 || sum(imag(fs))
    errordlg(['Invalid value used.  Sampling frequency must be a posiitve, real value.'], 'Error', 'modal');
    set(h.ai.edit.fs,'String','1000');
    sdisp(h,'Sampling frequency value reset to default.');
    return
end

%status update
npts  = str2double(get(h.ai.edit.npts,'String'));
sdisp(h,sprintf('Sampling time = %3.3f s.',npts/fs));


%--------------------------------------------------------------------
function npts_callback(~,eventdata)

%get userdata
h  = get(gcf,'UserData');

%get number of points
npts  = str2double(get(h.ai.edit.npts,'String'));

%error check input
if npts<1 || (npts-round(npts)) || sum(imag(npts))
    errordlg(['Invalid value used.  Number of points must be a posiitve, real, integer value.'], 'Error', 'modal');
    set(h.ai.edit.npts,'String','1000');
    sdisp(h,'No. pts value reset to default.');
    return
end

%status update
fs  = str2double(get(h.ai.edit.fs,'String'));
sdisp(h,sprintf('Sampling time = %3.3f s.',npts/fs));


%--------------------------------------------------------------------
function Xzero_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user to make sure
choice  = questdlg('Are you sure you want to set the X zero position?','Warning','Yes','No','No');

%check user input
if isequal(choice,'Yes');
    %set X position to zero
    h.Xposition  = 0;
    set(gcf,'UserData',h);
    
    %set position indicator
    set(h.doX.text.position,'String',sprintf('%i',h.Xposition));
    
    %disable motor buttons
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    
    %status update
    sdisp(h,'Position X reset to 0.');
end

%--------------------------------------------------------------------
function Zzero_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user to make sure
choice  = questdlg('Are you sure you want to set the Z zero position?','Warning','Yes','No','No');

%check user input
if isequal(choice,'Yes');
    %set Z position to zero
    h.Zposition  = 0;
    set(gcf,'UserData',h);
    
    %set position indicator
    set(h.doZ.text.position,'String',sprintf('%i',h.Xposition));
    
    %disable motor buttons
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    
    %status update
    sdisp(h,'Position Z reset to 0.');
end

%--------------------------------------------------------------------
function Xreturn_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user to make sure
choice  = questdlg('Are you sure you want to return the X stepper motor to zero position?  This will also send the Scanivalve home.','Warning','Yes','No','No');

if isequal(choice,'Yes');
    %get direction
    if h.Xposition > 0
        Xdirection  = 0;
    else
        Xdirection  = 1;
    end
    
    %update status
    sdisp(h,sprintf('Moving %i steps in the X %i direction.',abs(h.Xposition),Xdirection));
    
    %move motor to zero point
    do_moveX(abs(h.Xposition),Xdirection);
    %move_stepper(abs(h.position),direction);
    
    %set position to zero
    h.Xposition  = 0;
    set(gcf,'UserData',h);
    
    %set position indicator
    set(h.doX.text.position,'String',sprintf('%i',h.Xposition));
    
    %disable motor buttons
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    
    %return scannivalve
    sdisp(h,'Sending return pulse to Scannivalve.');   
    Zdo_gohome;

    %status update
    sdisp(h,'Position returned to 0.');
    
    sdisp(h,'Done.');
end

%--------------------------------------------------------------------
function Zreturn_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user to make sure
choice  = questdlg('Are you sure you want to return the Z stepper motor to zero position?','Warning','Yes','No','No');

if isequal(choice,'Yes');
    %get direction
    if h.Zposition > 0
        Zdirection  = 0;
    else
        Zdirection  = 1;
    end
    
    %update status
    sdisp(h,sprintf('Moving %i steps in the %i direction.',abs(h.Zposition),Zdirection));
    
    %move motor to zero point
    do_moveZ(abs(h.Zposition),Zdirection);
    %move_stepper(abs(h.position),direction);
    
    %set position to zero
    h.Zposition  = 0;
    set(gcf,'UserData',h);
    
    %set position indicator
    set(h.doZ.text.position,'String',sprintf('%i',h.Zposition));
    
    %disable motor buttons
    %set(h.do.pushbutton.return,'Enable','off');
    %set(h.do.pushbutton.zero,'Enable','off');
    
    %status update
    sdisp(h,'Z Position returned to 0.');
    
    sdisp(h,'Done.');
end


%--------------------------------------------------------------------
function channels_callback(hObject,eventdata)

%min/max channels permitted
minchan   = 0;
maxchan   = 7;

%get userdata
h  = get(gcf,'UserData');

%check for unique, valid, real, nteger values
channels  = get(h.ai.edit.channels,'String');
channels  = eval(['[' channels ']']);
channels  = unique(channels);
if ~isequal(sum(channels>=minchan),length(channels)) || ~isequal(sum(channels<=maxchan),length(channels)) || sum(channels-round(channels)) || sum(imag(channels))
    errordlg(['Invalid channel used.  Channels must be real, integer values between ' num2str(minchan) ' and' num2str(maxchan) '.'], 'Error', 'modal');
    set(h.ai.edit.channels,'String','0,1,2,3');
    sdisp(h,'Channel values reset to default.');
end

%update plot colors array
h.colors    = eval([h.colormap '(' num2str(length(channels)) ');']);

%save updated handles structure
set(gcf,'UserData',h);

%status update
if isequal(length(channels),1)
    sdisp(h,'1 channel detected.');
else
    sdisp(h,[num2str(length(channels)) ' channels detected.']);
end
sdisp(h,'Plot colors updated.');


%--------------------------------------------------------------------
function data  = acquire(channels,fs,npts)

% This portion is adapted from code by Jacob Cress
% that was later updated by Adam Smith, Notre Dame

%constants
boardnum  = 0;
nchan     = length(channels);
nsec      = npts/fs;

%initialize data array
data0  = zeros(npts,nchan);

%create single-ended analog input device
ai0            = analoginput('dtol',boardnum);
ai0.InputType  = 'SingleEnded';

%add channels to device
addchannel(ai0, channels);

%configure analog input subsystem
set(ai0, 'SampleRate', fs);
set(ai0, 'BufferingMode', 'auto');
set(ai0, 'SamplesPerTrigger',npts);

%set software trigger
set(ai0, 'TriggerType', 'Immediate');   % Board will begin acquiring as soon as it is ready

%acquire data
start(ai0);     %begin acquiring
pause(nsec+1);  %wait 1 extra sec after acquiring data
stop(ai0);      %stop acquiring

%take data from subsystem
data0  = getdata(ai0,npts);
data   = data0;

%clean buffer and close objects
flushdata(ai0)
delete(ai0);
clear ai0;


%--------------------------------------------------------------------
function plot1_autosave_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

if get(h.plot1.checkbox.autosave,'Value')
    %prompt user for folder to store data
    h.acq.timeseries.path  = uigetdir(h.acq.timeseries.defaultpath,'Folder for time-series files');

    %check that a selection was made
    if ~h.acq.timeseries.path
        h.acq.timeseries.path  = [];
        set(h.plot1.checkbox.autosave,'Value',0);
    else
        %prompt user for prefix
        h.prefix  = inputdlg('File prefix:');
        
        %check input
        if isempty(h.prefix)
            h.prefix  = 'timeseries';
        else
            h.prefix  = h.prefix{1};
        end
        
        %status update
        sdisp(h,'Time-series autosave enabled.');
        sdisp(h,sprintf('Prefix set to %s.',h.prefix));
        ii  = find(h.acq.timeseries.path==filesep,1,'last');
        sdisp(h,['Autosave path: ' h.acq.timeseries.path(ii+1:end) '.']);
    end
else
    h.acq.timeseries.path  = [];
    sdisp(h,'Time-series autosave disabled.');
end

%update handle data
set(gcf,'UserData',h);


%--------------------------------------------------------------------
function h  = update_plot1(h)

%set axes focus
axes(h.axes.ts);

%check if there is data
if ~isempty(h.acq.timeseries.data)
    %switch depending on popup box
    switch(get(h.plot1.popupmenu,'Value'))
        case 1  %time-series
            N          = size(h.acq.timeseries.data,1);
            k          = 0:N-1;
            t          = k/str2double(get(h.ai.edit.fs,'String'));
            xplotdata  = t;
            yplotdata  = h.acq.timeseries.data;
            xlab       = 'Time, s';
            ylab       = 'Voltage, V';
            titl       = 'Time-Series';
        case 2  %running average
            xplotdata  = 1:length(h.acq.timeseries.data);
            yplotdata  = cumsum(h.acq.timeseries.data)./repmat((1:length(h.acq.timeseries.data))',[1,size(h.acq.timeseries.data,2)]);
            xlab       = 'Number of Samples';
            ylab       = 'Voltage, V';
            titl       = 'Running Average';
        case 3  %fft
            N          = size(h.acq.timeseries.data,1);
            k          = 0:N-1;
            T          = N/str2double(get(h.ai.edit.fs,'String'));
            freq       = k/T;
            xplotdata  = freq;
            yplotdata  = abs(fft(h.acq.timeseries.data-repmat(mean(h.acq.timeseries.data,1),[size(h.acq.timeseries.data,1),1]))/N);
            cutoff     = ceil(N/2);
            xplotdata  = xplotdata(1:cutoff)';
            yplotdata  = yplotdata(1:cutoff,:);
            xlab       = 'Frequency, Hz';
            ylab       = '|FFT|, V';
            titl       = 'FFT';
    end
    
    %get channels
    channels   = get(h.ai.edit.channels,'String');
    channels   = eval(['[' channels ']']);
    channels   = unique(channels);
    channels   = sortrows(channels')';
    
    %make plot
    cla;
    for ai  = 1:size(h.acq.timeseries.data,2)
        plot(xplotdata,yplotdata(:,ai),             ...
        'Color',        h.colors(ai,:),         ...
        'LineWidth',    2,                      ...
        'Marker',       h.markers{ai}, ...
        'markersize',	8);
		set(gca,'linewidth',0.5);
        hold on;
        leg{ai}  = sprintf('Ch%i',channels(ai));
    end
    
    %update plot data
    h.plot1.x  =  xplotdata;
    h.plot1.y  =  yplotdata;
    set(gcf,'UserData',h);
else
	cla
    xlab  = '';
    ylab  = '';
    titl  = '';
    leg   = [];
	delete(legend);
end

%plot aesthetics
set(h.axes.ts,                                  ...
    'YAxisLocation',    'left',                ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'GridLineStyle',   ':',                     ...
    'LineWidth',        1,                      ...
    'YColor',           [0 0 0],             ...
    'XColor',           [0 0 0]);
box on;
grid on;
title([titl ' [updated ' datestr(clock,13) ']'],     ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
xlabel(xlab,                               ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
ylabel(ylab,                          ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
axis tight;
if ~isempty(leg)
    legend(leg,                                     ...
        'FontName',         h.fontname,             ...
        'FontSize',         h.fontsize,             ...
        'Location',         'Best');%'SouthEast');
end
drawnow;


%--------------------------------------------------------------------
function h  = update_plot2(h)

%set axes focus
axes(h.axes.mean);

%check if there is data
if ~isempty(h.acq.mean)
    %switch depending on popup box
    switch(get(h.plot2.popupmenu,'Value'))
        case 1  %mean
            xplotdata  = 1:size(h.acq.mean,1);
            yplotdata  = h.acq.mean;
			errdata    = [];
            xlab       = 'Index';
            ylab       = 'Voltage, V';
            titl       = 'Mean';
        case 2  %standard deviation
            xplotdata  = 1:size(h.acq.std,1);
            yplotdata  = h.acq.std;
			errdata    = [];
            xlab       = 'Index';
            ylab       = 'Voltage, V';
            titl       = 'Standard Deviation';
		case 3
			xplotdata  = 1:size(h.acq.std,1);
            yplotdata  = h.acq.mean;
			errdata    = h.acq.std;
            xlab       = 'Index';
            ylab       = 'Voltage, V';
            titl       = 'Mean with Standard Deviation Error Bars';			
    end
    
    %get channels
    channels   = get(h.ai.edit.channels,'String');
    channels   = eval(['[' channels ']']);
    channels   = unique(channels);
    channels   = sortrows(channels')';
    
    %make plot
    cla;
    for ai  = 1:size(h.acq.timeseries.data,2)
		if isempty(errdata)
	        plot(xplotdata,yplotdata(:,ai),             ...
	        'Color',        h.colors(ai,:),         ...
	        'LineWidth',    2,                      ...
	        'Marker',       h.markers{ai}, ...
	        'markersize', 8);
		else
			errorbar(xplotdata,yplotdata(:,ai),errdata(:,ai),       ...
	        'Color',        h.colors(ai,:),         ...
	        'LineWidth',    2,                      ...
	        'Marker',       h.markers{ai}, ...
	        'markersize', 8);
	    end
		set(gca,'linewidth',0.5);
        hold on;
        leg{ai}  = sprintf('Ch%i',channels(ai));
    end
        
    %update plot data
    h.plot2.x  =  xplotdata;
    h.plot2.y  =  yplotdata;
    set(gcf,'UserData',h);
else
	cla;
    xlab  = '';
    ylab  = '';
    titl  = '';
    leg   = [];
	delete(legend);
end

%plot aesthetics
set(h.axes.mean,                                ...
    'YAxisLocation',    'left',                ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal',               ...
    'GridLineStyle',   ':',                     ...
    'LineWidth',        1,                      ...
    'YColor',           [0 0 0],             ...
    'XColor',           [0 0 0]);
box on;
grid on;
title([titl ' [updated ' datestr(clock,13) ']'],    ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
xlabel(xlab,                               ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
ylabel(ylab,                          ...
    'FontName',         h.fontname,             ...
    'FontSize',         h.fontsize,             ...
    'FontWeight',       'normal');
axis tight;
if ~isempty(leg)
    legend(leg,                                     ...
        'FontName',         h.fontname,             ...
        'FontSize',         h.fontsize,             ...
        'Location',         'Best');%'SouthEast');
end
drawnow;


%--------------------------------------------------------------------
function plot1_removealldata_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%promt user for clear
choice1  = questdlg('Are you sure you want to clear the stored time-series data?','Warning','Yes','No','No');

if isequal(choice1,'Yes') 
    choice2  = questdlg('Are you REALLY sure?  The data will be lost FOREVER.','Warning','Yes','No','No');

    %clear the data
    if isequal(choice2,'Yes')
        h.acq.timeseries.data  = [];
        sdisp(h,'Cleared current time-series data.');
        h.plot1.x  = [];
        h.plot1.y  = [];
        axes(h.axes.ts)        
        cla;
        
        %update plot buttons
        set(h.plot1.pushbutton.clf,'Enable','off');
        set(h.plot1.pushbutton.save,'Enable','off');
        
        %update handles
        set(gcf,'UserData',h);
    end
end


%--------------------------------------------------------------------
function plot2_removealldata_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%promt user for clear
choice1  = questdlg('Are you sure you want to clear all stored mean and standard deviation data?','Warning','Yes','No','No');

if isequal(choice1,'Yes') 
    choice2  = questdlg('Are you REALLY sure?  The data will be lost FOREVER.','Warning','Yes','No','No');

    %clear the data
    if isequal(choice2,'Yes')
        h.acq.mean  = [];
        h.acq.std   = [];
        sdisp(h,'Cleared all mean and standard deviation data.');
        h.plot2.x  = [];
        h.plot2.y  = [];
        axes(h.axes.mean);
        cla;
        
        %update plot buttons
        set(h.plot2.pushbutton.clf,'Enable','off');
        set(h.plot2.pushbutton.save,'Enable','off');
        set(h.plot2.pushbutton.removedata,'Enable','off');

        %update handles
        set(gcf,'UserData',h);        
    end
end


%--------------------------------------------------------------------
function plot2_remove_data(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%make cell array of data for list dialog
for ai  = 1:size(h.acq.mean,1)
	listcell{ai}  = sprintf('index=%03i, mean=%02.3f, std=%02.3f',ai,h.acq.mean(ai),h.acq.std(ai));
end

%get screensize for list dialog
ss  = get(0,'ScreenSize');
listx  = round(ss(3)*.25);
listy  = round(ss(4)*.5);

%make list dialog box
sdisp(h,'Prompting user to select data for removal.');
selection  = listdlg('liststring',listcell,'selectionmode','multiple','name','Delete', ...
	'PromptString','Select data to remove:','okstring','Delete','listsize',[listx,listy]);
if ~isempty(selection)
	sdisp(h,sprintf('%i data points selected for removal.',length(selection)));
	%prompt user again to make sure
    choice2  = questdlg('Are you REALLY sure?  The data will be lost FOREVER.','Warning','Yes','No','No');
    if isequal(choice2,'Yes')
		if isequal(length(selection),length(h.acq.mean))
			%clear all data
			h.acq.mean  = [];
	 		h.acq.std   = []; 
			h.plot2.x   = [];
			h.plot2.y   = [];	
			sdisp(h,sprintf('Deleted all %i data points.',length(selection)));

			%update plot buttons
	        set(h.plot2.pushbutton.clf,'Enable','off');
	        set(h.plot2.pushbutton.save,'Enable','off');
	        set(h.plot2.pushbutton.removedata,'Enable','off');
		else
	    	%clear the selected data
	        h.acq.mean(selection)  = [];
	        h.acq.std(selection)   = [];
	        h.plot2.y(selection)   = [];
			h.plot2.x              = 1:length(h.plot2.y);
	        sdisp(h,sprintf('Deleted %i data points.',length(selection)));			
		end
		
        %update handles
        set(gcf,'UserData',h);
		%update plot 2 data
		update_plot2(h);
	else
		sdisp(h,'Data removal cancelled.');
    end
else
	sdisp(h,'Data removal cancelled.');
end


%--------------------------------------------------------------------
function plot1_save_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user for file
[fname,fdir]  = uiputfile( ...
    {'*.mat','MAT-files (*.mat)'}, ...
    'Select a file location');

%check that a file and directory were selected
if ~sum(fname) || ~sum(fdir)
    return;
end

%get some data from gui
channels   = get(h.ai.edit.channels,'String');
channels   = eval(['[' channels ']']);
channels   = unique(channels);
channels   = sortrows(channels')';
fs         = str2double(get(h.ai.edit.fs,'String'));
npts       = str2double(get(h.ai.edit.npts,'String'));

%save data
x_data  = h.plot1.x;
y_data  = h.plot1.y;
save([fdir fname],'x_data','y_data','channels','fs','npts');


%--------------------------------------------------------------------
function plot2_save_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%prompt user for file
[fname,fdir]  = uiputfile( ...
    {'*.mat','MAT-files (*.mat)'}, ...
    'Select a file location');

%check that a file and directory were selected
if ~sum(fname) || ~sum(fdir)
    return;
end

%get some data from gui
channels   = get(h.ai.edit.channels,'String');
channels   = eval(['[' channels ']']);
channels   = unique(channels);
channels   = sortrows(channels')';
fs         = str2double(get(h.ai.edit.fs,'String'));
npts       = str2double(get(h.ai.edit.npts,'String'));

%save data
mean_data  = h.acq.mean;
std_data   = h.acq.std;
save([fdir fname],'mean_data','std_data','channels','fs','npts');


%--------------------------------------------------------------------
function plot1popup_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%update plot2
h  = update_plot1(h);


%--------------------------------------------------------------------
function plot2popup_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%update plot2
h  = update_plot2(h);


%--------------------------------------------------------------------
function repetitions_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%get number of repetitions
repetitions  = str2double(get(h.execute.edit.repetitions,'String'));

%error check the input
if repetitions<1 || (repetitions-round(repetitions)) || sum(imag(repetitions))
    errordlg(['Invalid value used.  Repetitions must be a posiitve, real, integer value.'], 'Error', 'modal');
    set(h.execute.edit.repetitions,'String','1');
    sdisp(h,'Repetitions value reset to default.');
    return
end

%enable/disable autosave checkbox
if repetitions >1
    set(h.plot1.checkbox.autosave,'Enable','on');
    sdisp(h,'Time-series autosave available.');
else
    set(h.plot1.checkbox.autosave,'Enable','off');
    sdisp(h,'Time-series autosave unavailable.');
end


%--------------------------------------------------------------------
function Xnsteps_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%get number of steps
Xnsteps  = str2double(get(h.doX.edit.nsteps,'String'));

%error check input
if Xnsteps<1 || (Xnsteps-round(Xnsteps)) || sum(imag(Xnsteps))
    errordlg(['Invalid value used.  Number of steps must be a posiitve, real, integer value.'], 'Error', 'modal');
    set(h.doX.edit.nsteps,'String','100');
    sdisp(h,'No. steps value reset to default.');
    return
end

%--------------------------------------------------------------------
function Znsteps_callback(hObject,eventdata)

%get userdata
h  = get(gcf,'UserData');

%get number of steps
nsteps  = str2double(get(h.doZ.edit.nsteps,'String'));

%error check input
if Znsteps<1 || (Znsteps-round(Znsteps)) || sum(imag(Znsteps))
    errordlg(['Invalid value used.  Number of steps must be a posiitve, real, integer value.'], 'Error', 'modal');
    set(h.doZ.edit.nsteps,'String','100');
    sdisp(h,'No. steps value reset to default.');
    return
end

%--------------------------------------------------------------------
% %old function using DIO ports
function do_moveX(Xnsteps,Xdirection)

boardnum  = 0;

%get userdata
h  = get(gcf,'UserData');

%sampling frequency
fs  = h.dio_settings.fs;

%duty cycle
duty  = h.dio_settings.duty;

%acquire digital subsystem
DIO = digitalio('dtol',boardnum);
 
%start off by creating outputs
do_direction  = addline(DIO,0,1,'Out');
do_step       = addline(DIO,6,1,'Out'); % Formerly (DIO,1,1,'Out') Bad ch
do_enable     = addline(DIO,2,1,'Out');

%set direction to value from gui
putvalue(do_direction, Xdirection);

%set enable to low
putvalue(do_enable,0);

%set step to low
putvalue(do_step, 0);

%generate pulse train
timeout  = 1/fs*(1-duty);
for ai  = 1:Xnsteps
    tic
    putvalue(do_step, 0);
    while toc<timeout;end
    putvalue(do_step, 1);
    while toc<timeout;end
end

%set step to low
putvalue(do_step, 0);

%set direction to low
putvalue(do_direction,0);

%set enable to high
putvalue(do_enable,0);

%remove digital channel
delete(DIO);
delete(do_direction);
delete(do_step);
clear DIO;

%--------------------------------------------------------------------
% %old function using DIO ports
function do_moveZ(Znsteps,Zdirection)

boardnum  = 0;

%get userdata
h  = get(gcf,'UserData');

%sampling frequency
fs  = h.dio_settings.fs;

%duty cycle
duty  = h.dio_settings.duty;

%acquire digital subsystem
DIO = digitalio('dtol',boardnum);
 
%start off by creating outputs  !CHANGE THESE FOR THE Z DIRECTION!
do_direction  = addline(DIO,0,1,'Out');
do_step       = addline(DIO,5,1,'Out'); % Formerly (DIO,1,1,'Out') Bad ch
do_enable     = addline(DIO,2,1,'Out');

%set direction to value from gui
putvalue(do_direction, Zdirection);

%set enable to low
putvalue(do_enable,0);

%set step to low
putvalue(do_step, 0);

%generate pulse train
timeout  = 1/fs*(1-duty);
for ai  = 1:Znsteps
    tic
    putvalue(do_step, 0);
    while toc<timeout;end
    putvalue(do_step, 1);
    while toc<timeout;end
end

%set step to low
putvalue(do_step, 0);

%set direction to low
putvalue(do_direction,0);

%set enable to high
putvalue(do_enable,0);

%remove digital channel
delete(DIO);
delete(do_direction);
delete(do_step);
clear DIO;

%--------------------------------------------------------------------
function Zdo_gohome  %return the scannivalve

boardnum  = 0;

%get userdata
h  = get(gcf,'UserData');

%sampling frequency
fs  = h.dio_settings.fs;

%duty cycle
duty  = h.dio_settings.duty;

%acquire digital subsystem
DIO = digitalio('dtol',boardnum);

%create digital out channel
do_scannivalve     = addline(DIO,3,1,'Out');

%output a single pulse 
putvalue(do_scannivalve, 0);
pause(1/fs*duty)
putvalue(do_scannivalve, 1);
pause(1/fs*duty)
putvalue(do_scannivalve, 0);

%remove digital channel
delete(DIO);
delete(do_scannivalve);
clear DIO;


%  This code generates pulse trains to move the stepper motor using the
%  AO channels.  The code produces a warning about the AO buffer size 
%  that has not been resolved.  The code randomly crashes MATLAB and
%  requires a restart.  For this reason, the motor control is accomplished
%  using DO.
% %--------------------------------------------------------------------
% function move_stepper(Nsteps,direction,boardnum)
% 
% %check input arguments
% if nargin<3
%     boardnum  = 0;
% end
% 
% %turn off warning due to persistent buffer message
% warning off;
% 
% %parameters
% Fs       = 250000;    %output sampling frequency
% Npts     = 500;      %output buffer size
% pduty    = 50;        %duty cycle
% timeout  = 5;         %sampling timeout
% 
% %create analog output object
% ao = analogoutput('dtol',boardnum);
% addchannel(ao, [0,1]);
% set(ao,'OutOfDataMode','Hold');
% set(ao,'SampleRate',Fs);
% set(ao,'RepeatOutput',Nsteps-1);
% set(ao,'BufferingMode','Auto');
% set(ao,'BufferingConfig',[Npts 2]);
% set(ao,'TriggerType','Immediate');
% 
% %calculate acquisition duration
% fsamp  = get(ao,'SampleRate');  %detected output sampling frequency (could be different than Fs)
% freal  = fsamp/Npts;            %pulse frequency
% Treal  = Nsteps/freal;          %pulse duration in seconds
% 
% %create step and direction vectors of a single pulse
% t      = linspace(0,1,Npts);
% data1  = 5*linspace(direction,direction,Npts);
% data2  = 5/2*(1-square(2*pi*t,pduty));
% data1  = data1';   
% data2  = data2';
% data   = [data1 data2];
% 
% %load data to ao buffer
% disp('putting data');
% putdata(ao,data);
% disp('pausing 2*Treal');
% pause(2*Treal);
% disp('starting ao');
% start(ao);
% disp('pausing 2*Treal');
% pause(2*Treal);
% disp('pausing timeout');
% pause(timeout);
% disp('stopping ao');
% stop(ao);
% 
% %cleanup
% delete(ao);
% clear ao
% 
% %turn warning
% warning on;
% 
% %extra pause
% pause(1);
