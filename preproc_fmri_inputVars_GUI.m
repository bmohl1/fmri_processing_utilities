function varargout = preproc_fmri_inputVars_GUI(varargin)
% PREPROC_FMRI_INPUTVARS_GUI MATLAB code for preproc_fmri_inputVars_GUI.fig
%      PREPROC_FMRI_INPUTVARS_GUI, by itself, creates a new PREPROC_FMRI_INPUTVARS_GUI or raises the existing
%      singleton*.
%
%      H = PREPROC_FMRI_INPUTVARS_GUI returns the handle to a new PREPROC_FMRI_INPUTVARS_GUI or the handle to
%      the existing singleton*.
%
%      PREPROC_FMRI_INPUTVARS_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PREPROC_FMRI_INPUTVARS_GUI.M with the given input arguments.
%
%      PREPROC_FMRI_INPUTVARS_GUI('Property','Value',...) creates a new PREPROC_FMRI_INPUTVARS_GUI or raises
%      the existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before preproc_fmri_inputVars_GUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to preproc_fmri_inputVars_GUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help preproc_fmri_inputVars_GUI

% Last Modified by GUIDE v2.5 31-Oct-2019 13:07:08

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @preproc_fmri_inputVars_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @preproc_fmri_inputVars_GUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before preproc_fmri_inputVars_GUI is made visible.
function preproc_fmri_inputVars_GUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to preproc_fmri_inputVars_GUI (see VARARGIN)

% Choose default command line output for preproc_fmri_inputVars_GUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes preproc_fmri_inputVars_GUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);
uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = preproc_fmri_inputVars_GUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
specialTempflag = get(handles.checkbox_specialTemp,'Value');
stcflag = get(handles.checkbox_stc,'Value');
discardflag = get(handles.checkbox_discard,'Value');
artflag = get(handles.checkbox_art,'Value');
unwarpflag = get(handles.checkbox_unwarp,'Value');
preprocflag = get(handles.checkbox_ignore,'Value');
segmentationflag = get(handles.checkbox_segmentation,'Value');
cancelflag = get(handles.pushbutton_cancel, 'userdata');
aCompCorrflag = get(handles.checkbox_aCompCorr_opt,'Value');
pipelineflag = get(handles.checkbox_alt_pipeline,'Value');

%special_templates runArt stc discard_dummies prefix ignore_preproc
varargout{1} = specialTempflag;
varargout{2} = artflag;
varargout{3} = stcflag;
varargout{4} = discardflag;
varargout{5} = unwarpflag;
varargout{6} = preprocflag;
varargout{7} = segmentationflag;
varargout{8} = cancelflag;
varargout{9} = aCompCorrflag;
varargout{10} = pipelineflag;

delete(handles.figure1);


% --- Executes on button press in Okay.
function Okay_Callback(hObject, eventdata, handles)
% hObject    handle to Okay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isequal(get(handles.figure1, 'waitstatus'), 'waiting')
    % The GUI is still in UIWAIT, use UIRESUME
    uiresume(handles.figure1);
else
    % The GUI is no longer waiting, just close it
    delete(handles.figure1);
end

% --- Executes on button press in checkbox_stc.
function checkbox_stc_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_stc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_stc
handles.stc = get(hObject,'Value');
guidata(hObject, handles);

% --- Executes on button press in checkbox_discard.
function checkbox_discard_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_discard (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_discard
handles.discard= get(hObject,'Value');
guidata(hObject, handles);

% --- Executes on button press in checkbox_art.
function checkbox_art_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_art (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_art
handles.art = get(hObject,'Value');
guidata(hObject, handles);

% --- Executes on button press in checkbox_unwarp.
function checkbox_unwarp_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_unwarp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_unwarp
handles.unwarp = get(hObject,'Value');
guidata(hObject, handles);

% --- Executes on button press in checkbox_ignore.
function checkbox_ignore_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_ignore (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_ignore
handles.ignore = get(hObject,'Value');
guidata(hObject, handles);


% --- Executes on button press in checkbox_specialTemp.
function checkbox_specialTemp_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_specialTemp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_specialTemp
handles.specialTemp = get(hObject,'Value');
guidata(hObject, handles);


% --- Executes on button press in checkbox_segmentation.
function checkbox_segmentation_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_segmentation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_segmentation
handles.segmentation = get(hObject,'Value');
guidata(hObject, handles);


% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
        set(handles.pushbutton_cancel,'userdata',1);
if isequal(get(handles.figure1, 'waitstatus'), 'waiting')
    % The GUI is still in UIWAIT, use UIRESUME
    uiresume(handles.figure1);
else
    % The GUI is no longer waiting, just close it
        set(handles.pushbutton_cancel,'Value',1);
        delete(handles.figure1);
end


% --- Executes when figure1 is resized.
function figure1_SizeChangedFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in checkbox_aCompCorr_opt.
function checkbox_aCompCorr_opt_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_aCompCorr_opt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_aCompCorr_opt
handles.aCompCorr_opt = get(hObject,'Value');
guidata(hObject, handles);



% --- Executes on button press in checkbox_alt_pipeline.
function checkbox_alt_pipeline_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_alt_pipeline (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_alt_pipeline
handles.alt_pipeline = get(hObject,'Value');
guidata(hObject, handles);