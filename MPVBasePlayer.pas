unit MPVBasePlayer;

// MPV base player classes
// Author: Edward G. (nbuyer@gmail.com)

interface

uses
  SysUtils, Classes, SyncObjs, Variants,
  MPVConst, MPVClient, MPVNode, MPVTrack;

const
  DEF_MPV_EVENT_SECONDS = 0.5;

type
  TMPVBasePlayer = class;
  TMPVErrorCode = Integer;
  TMPVException = class(Exception);

  TMPVPlayerState = (mpsUnk, mpsPlay, mpsStep, mpsPause, mpsStop, mpsEnd, mpsErr);

  TMPVEventThread = class(TThread)
  private
    m_cPlayer: TMPVBasePlayer;
  protected
    procedure Execute; override;
  public
    constructor Create(cPlayer: TMPVBasePlayer);
  end;

  TMPVDestroyThread = class(TThread)
  private
    m_hMPV: PMPVHandle;
  protected
    procedure Execute; override;
  public
    constructor Create(hMPV: PMPVHandle);
  end;

  // pData is the buffer of data
  TMPVFileOpen = procedure (cSender: TObject; const sPath: string) of object;
  TMPVPropertyChangedEvent = procedure (cSender: TObject; nID: MPVUInt64;
    nFmt: mpv_format; pData: Pointer) of object;
  TMPVProgressEvent = procedure (cSender: TObject; fCurSec, fTotalSec: Double) of object;
  TMPVErrorMessage = procedure (cSender: TObject; const sPrefix: string;
    nLevel: Int32; const sMsg: string) of object;

  TMPVBasePlayer = class
  private
    m_cLock: TCriticalSection;
    m_cEventThrd: TMPVEventThread; // Thread to process events
    m_fEventWait: Double; // Wait event seconds
    m_eOnFileOpen: TMPVFileOpen;
    m_eOnProgress: TMPVProgressEvent;
    m_eOnPropChged: TMPVPropertyChangedEvent;
    m_eOnErrMsg: TMPVErrorMessage;
  private
    procedure SetATrack(const Value: string);
    procedure SetSTrack(const Value: string);
    procedure SetVTrack(const Value: string);
    procedure SetCurSec(const Value: Double);
    procedure SetSpeed(const Value: Double);
    procedure SetVol(const Value: Double);
    function GetAudioDev: string;
    procedure SetAudioDev(const Value: string);
    function GetAudioDevList: string;

    function GetOnProgress: TMPVProgressEvent;
    procedure SetOnProgress(const Value: TMPVProgressEvent);
    function GetOnProgChg: TMPVPropertyChangedEvent;
    procedure SetOnProgChg(const Value: TMPVPropertyChangedEvent);
    function GetOnErrMsg: TMPVErrorMessage;
    function GetOnFileOpen: TMPVFileOpen;
    procedure SetOnErrMsg(const Value: TMPVErrorMessage);
    procedure SetOnFileOpen(const Value: TMPVFileOpen);
  protected
    m_hMPV: PMPVHandle; // MPV Handle

    m_fLenInSec, m_fCurSec: Double; // Total / current seconds
    m_fSpeed: Double; // Speed
    m_fVol: Double; // Volume
    m_nX, m_nY: Int64; // Video width/height
    m_sAudioDev: string; // name: "auto"
    m_sAudioDevList: string; // JSON array

    m_sFileName: string; // Current file name
    m_eState: TMPVPlayerState; // Current player state

    m_cTrackList: TMPVTrackList; // All tracks' list
    m_sCurVTrk, m_sCurATrk, m_sCurSTrk: string;  // Current track IDs

  protected
    procedure MPVGetMem(var P: Pointer; nSize: Integer); inline;
    procedure MPVFreeMem(P: Pointer); inline;
    function HandleError(nCode: Integer; const sFunc: string;
      bRaise: Boolean=False): TMPVErrorCode;

    procedure FreePlayer; virtual;
    procedure EventLoop(pbCancel: PBoolean); virtual;

    function DoEventPropertyChange(nID: MPVUInt64;
      pEP: P_mpv_event_property): TMPVErrorCode; virtual;
    function DoEventFileLoaded: TMPVErrorCode; virtual;
    function DoEventLogMsg(pLM: P_mpv_event_log_message): TMPVErrorCode; virtual;
    function DoEventClientMsg(pCM: P_mpv_event_client_message): TMPVErrorCode; virtual;
    function DoEventVideoReconfig: TMPVErrorCode; virtual;
    function DoEventSeek: TMPVErrorCode; virtual;
    function DoEventRestart: TMPVErrorCode; virtual;
    function DoEventStartFile(pSF: P_mpv_event_start_file): TMPVErrorCode; virtual;
    function DoEventEndFile(pEF: P_mpv_event_end_file): TMPVErrorCode; virtual;
    function DoEventShutdown: TMPVErrorCode; virtual;
    function DoEventGetPropertyReply(nErr: MPVInt; nID: MPVUInt64;
      pEP: P_mpv_event_property): TMPVErrorCode; virtual;
    function DoEventSetPropertyReply(nErr: MPVInt;
      nID: MPVUInt64): TMPVErrorCode; virtual;
    function DoEventCommandReply(nErr: MPVInt; nID: MPVUInt64;
      pEC: P_mpv_event_command): TMPVErrorCode; virtual;
    procedure DoSetVideoSize; virtual;

    function ObserveProperty(const sName: string; nID: UInt64;
      nFmt: MPVEnum = MPV_FORMAT_NODE): TMPVErrorCode;
    function SetTrack(eType: TMPVTrackType; const sID, sPropName: string): TMPVErrorCode;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Lock; inline;
    procedure Unlock; inline;
    procedure NotifyFree; virtual; // Only notify to free, no wait

    function InitPlayer(const sWinHandle, sConfigDir: string;
      fEventWait: Double = DEF_MPV_EVENT_SECONDS): TMPVErrorCode; virtual;
    procedure ProcessCmdLine(bBeforeInit: Boolean); virtual;
    procedure Log(const sMsg: string; bError: Boolean); virtual;

    function CommandStr(const sCmd: string): TMPVErrorCode;
    function CommandList(cCmds: TStrings; nID: MPVUInt64 = 0): TMPVErrorCode;
    function Command(yCmds: array of string; nID: MPVUInt64 = 0): TMPVErrorCode;

    function GetPropertyBool(const sName: string; var Value: Boolean): TMPVErrorCode;
    function SetPropertyBool(const sName: string; Value: Boolean; nID: MPVUInt64 = 0): TMPVErrorCode;
    function GetPropertyInt64(const sName: string; var Value: Int64): TMPVErrorCode;
    function SetPropertyInt64(const sName: string; Value: Int64; nID: MPVUInt64 = 0): TMPVErrorCode;
    function GetPropertyDouble(const sName: string; var Value: Double): TMPVErrorCode;
    function SetPropertyDouble(const sName: string; Value: Double; nID: MPVUInt64 = 0): TMPVErrorCode;
    function GetPropertyString(const sName: string; var Value: string): TMPVErrorCode;
    function SetPropertyString(const sName, sValue: string; nID: MPVUInt64 = 0): TMPVErrorCode;
    function GetPropertyNode(const sName: string; cNode: TMPVNode): TMPVErrorCode;

    function ObservePropertyBool(const sName: string; nID: UInt64): TMPVErrorCode;
    function ObservePropertyInt64(const sName: string; nID: UInt64): TMPVErrorCode;
    function ObservePropertyDouble(const sName: string; nID: UInt64): TMPVErrorCode;
    function ObservePropertyString(const sName: string; nID: UInt64): TMPVErrorCode;

    function OpenFile(const sFullName: string): TMPVErrorCode;
    function GetState: TMPVPlayerState; inline;
    function Pause: TMPVErrorCode;
    function Resume: TMPVErrorCode;
    function Stop: TMPVErrorCode;
    function Seek(fPos: Double; bRelative: Boolean): TMPVErrorCode;

    function CopyTrackInfoList(eType: TMPVTrackType; cList: TMPVTrackList): Integer;
    // sID = [id] or [title]
    function SetVideoTrack(const sID: string): TMPVErrorCode;
    // sID = [id] or [title]
    function SetAudioTrack(const sID: string): TMPVErrorCode;
    // sID = [id] or [title]
    function SetSubTitle(const sID: string): TMPVErrorCode;

    function GetVolume: Double;
    function SetVolume(fVol: Double): TMPVErrorCode;
    function SetMute(bMute: Boolean): TMPVErrorCode;
  public
    property FileName: string read m_sFileName;
    property CurrentVideoTrack: string read m_sCurVTrk write SetVTrack;
    property CurrentAudioTrack: string read m_sCurATrk write SetATrack;
    property CurrentSubtitle: string read m_sCurSTrk write SetSTrack;
    property PlaybackSpeed: Double read m_fSpeed write SetSpeed;
    property TotalSeconds: Double read m_fLenInSec;
    property CurrentSeconds: Double read m_fCurSec write SetCurSec;
    property VideoWidth: Int64 read m_nX;
    property VideoHeight: Int64 read m_nY;
    property Volume: Double read m_fVol write SetVol;
    property AudioDevice: string read GetAudioDev write SetAudioDev;
    property AudioDeviceList: string read GetAudioDevList;

    // These events are from another thread
    property OnFileOpen: TMPVFileOpen read GetOnFileOpen write SetOnFileOpen;
    property OnErrorMessage: TMPVErrorMessage read GetOnErrMsg write SetOnErrMsg;
    property OnProgress: TMPVProgressEvent read GetOnProgress write SetOnProgress;
    property OnPropertyChanged: TMPVPropertyChangedEvent read GetOnProgChg write SetOnProgChg;
  end;


implementation

{ TMPVEventThread }

constructor TMPVEventThread.Create(cPlayer: TMPVBasePlayer);
begin
  m_cPlayer := cPlayer;
  inherited Create(False);
end;

procedure TMPVEventThread.Execute;
begin
  while not Terminated do
  begin
    m_cPlayer.EventLoop(@Terminated);
  end;
end;

{ TMPVDestroyThread }

constructor TMPVDestroyThread.Create(hMPV: PMPVHandle);
begin
  m_hMPV := hMPV;
  inherited Create(False);
  FreeOnTerminate := True;
end;

procedure TMPVDestroyThread.Execute;
begin
  if m_hMPV<>nil then mpv_terminate_destroy(m_hMPV);
end;

{ TMPVBasePlayer }

function TMPVBasePlayer.Command(yCmds: array of string; nID: MPVUInt64): TMPVErrorCode;
var
  cStr: TStringList;
  i: Integer;
begin
  cStr := TStringList.Create;
  try
    for i := Low(yCmds) to High(yCmds) do
      cStr.Add(yCmds[i]);
    Result := CommandList(cStr, nID);
  finally
    cStr.Free;
  end;
end;

function TMPVBasePlayer.CommandList(cCmds: TStrings; nID: MPVUInt64): TMPVErrorCode;
var
  args, ppc: PPMPVChar;
  P: Pointer;
  s1: AnsiString;
  i, n: Integer;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  if (cCmds=nil) or (cCmds.Count<=0) then
  begin
    Result := MPV_ERROR_INVALID_PARAMETER;
    Exit;
  end;

  Result := MPV_ERROR_SUCCESS;

  // Construct args
  i := (cCmds.Count+1)*sizeof(PMPVChar);
  args := nil;
  MPVGetMem(Pointer(args), i);
  FillChar(args^, i, 0);
  ppc := args;
  for i := 0 to cCmds.Count-1 do
  begin
    s1 := UTF8Encode(cCmds[i]);
    n := Length(s1)+1; // #0 ended
    if n>1 then
    begin
      // Alloc memory to hold one line
      P := nil;
      MPVGetMem(P, n*sizeof(s1[1]));
      if P<>nil then
      begin
        Move(PAnsiChar(s1)^, P^, n*sizeof(s1[1]));
        ppc^ := P;
        Inc(ppc);
      end else
      begin
        Result := MPV_ERROR_NOMEM;
        Break;
      end;
    end;
  end;

  if Result=MPV_ERROR_SUCCESS then
  begin
    if nID>0 then
      Result := HandleError(mpv_command_async(m_hMPV, nID, args), 'mpv_command_async')
    else
      Result := HandleError(mpv_command(m_hMPV, args), 'mpv_command');
  end;

  // free memory
  ppc := args;
  for i := 0 to cCmds.Count-1 do
  begin
    if ppc<>nil then
      MPVFreeMem(ppc^);
    Inc(ppc);
  end;
  MPVFreeMem(args);
end;

function TMPVBasePlayer.CommandStr(const sCmd: string): TMPVErrorCode;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  Result := HandleError(mpv_command_string(m_hMPV, PMPVChar(UTF8Encode(sCmd))),
    'mpv_command_string');
end;

function TMPVBasePlayer.CopyTrackInfoList(eType: TMPVTrackType;
  cList: TMPVTrackList): Integer;
begin
  m_cLock.Enter;
  cList.Assign(m_cTrackList, eType);
  m_cLock.Leave;
  Result := cList.Count;
end;

constructor TMPVBasePlayer.Create;
begin
  m_cLock := TCriticalSection.Create;
  m_cTrackList := TMPVTrackList.Create();
  m_eState := mpsUnk;
  inherited Create;
end;

destructor TMPVBasePlayer.Destroy;
begin
  FreePlayer;
  FreeAndNil(m_cTrackList);
  FreeAndNil(m_cLock);
  inherited;
end;

function GetEventStr(nID: MPVEnum): string;
begin
  case nID of
  MPV_EVENT_NONE: Result := 'None';
  MPV_EVENT_SHUTDOWN: Result := 'Shutdown';
  MPV_EVENT_LOG_MESSAGE_: Result := 'LogMsg';
  MPV_EVENT_GET_PROPERTY_REPLY: Result := 'GetPropReply';
  MPV_EVENT_SET_PROPERTY_REPLY: Result := 'SetPropReply';
  MPV_EVENT_COMMAND_REPLY: Result := 'CmdReply';
  MPV_EVENT_START_FILE_: Result := 'StartFile';
  MPV_EVENT_END_FILE_: Result := 'EndFile';
  MPV_EVENT_FILE_LOADED: Result := 'FileLoaded';
  MPV_EVENT_IDLE: Result := 'Idle';
  MPV_EVENT_TICK: Result := 'Tick';
  MPV_EVENT_CLIENT_MESSAGE_: Result := 'ClientMsg';
  MPV_EVENT_VIDEO_RECONFIG: Result := 'VideoRecfg';
  MPV_EVENT_AUDIO_RECONFIG: Result := 'AudioRecfg';
  MPV_EVENT_SEEK: Result := 'Seek';
  MPV_EVENT_PLAYBACK_RESTART: Result := 'PlayRestart';
  MPV_EVENT_PROPERTY_CHANGE: Result := 'PropChg';
  MPV_EVENT_QUEUE_OVERFLOW: Result := 'QueOverflow';
  MPV_EVENT_HOOK_: Result := 'Hook';
  else Result := IntToStr(nID);
  end;
end;

procedure TMPVBasePlayer.EventLoop(pbCancel: PBoolean);
var
  pe: P_mpv_event;
begin
  if m_hMPV=nil then Exit;

  while not pbCancel^ do
  begin
    pe := mpv_wait_event(m_hMPV, m_fEventWait);  // seconds
    if pe<>nil then
    begin
      case pe^.event_id of
      MPV_EVENT_NONE: Continue;
      MPV_EVENT_PROPERTY_CHANGE, MPV_EVENT_SEEK, MPV_EVENT_PLAYBACK_RESTART: ; // Too many
      else
        begin
          Log(Format('event=%s; err=%d; ud=%d', [GetEventStr(pe^.event_id),
            pe^.error, pe^.reply_userdata]), False);
        end;
      end;

      case pe^.event_id of
      //MPV_EVENT_NONE: ; // nothing
      MPV_EVENT_VIDEO_RECONFIG:
        begin
          // video changed, resize window!
          HandleError(DoEventVideoReconfig, 'DoEventVideoReconfig');
        end;
      MPV_EVENT_SEEK:
        begin
          // Update progress!
          HandleError(DoEventSeek, 'DoEventSeek');
        end;
      MPV_EVENT_PLAYBACK_RESTART:
        begin
          // Start of playback or after seeking
          HandleError(DoEventRestart, 'DoEventRestart');
        end;
      MPV_EVENT_PROPERTY_CHANGE:
        begin
          HandleError(DoEventPropertyChange(pe^.reply_userdata,
            P_mpv_event_property(pe^.data)), 'DoEventPropertyChange');
        end;
      MPV_EVENT_FILE_LOADED:
        begin
          m_eState := mpsPlay;
          // start playback!
          HandleError(DoEventFileLoaded, 'DoEventFileLoaded');
        end;
      MPV_EVENT_START_FILE_:
        begin
          // before load file
          HandleError(DoEventStartFile(P_mpv_event_start_file(pe^.data)), 'DoEventStartFile');
        end;
      MPV_EVENT_END_FILE_:
        begin
          m_eState := mpsStop;
          // after file unloaded
          HandleError(DoEventEndFile(P_mpv_event_end_file(pe^.data)), 'DoEventEndFile');
        end;
      MPV_EVENT_SHUTDOWN:
        begin
          m_eState := mpsEnd;
          HandleError(DoEventShutdown, 'DoEventShutdown');
        end;
      MPV_EVENT_LOG_MESSAGE_:
        begin
          HandleError(DoEventLogMsg(P_mpv_event_log_message(pe^.data)), 'DoEventLogMsg');
        end;
      MPV_EVENT_CLIENT_MESSAGE_:
        begin
          HandleError(DoEventClientMsg(P_mpv_event_client_message(pe^.data)),
            'DoEventClientMsg');
        end;
      MPV_EVENT_GET_PROPERTY_REPLY:
        begin
          HandleError(DoEventGetPropertyReply(pe^.error, pe^.reply_userdata,
            P_mpv_event_property(pe^.data)), 'DoEventGetPropertyReply');
        end;
      MPV_EVENT_SET_PROPERTY_REPLY:
        begin
          HandleError(DoEventSetPropertyReply(pe^.error, pe^.reply_userdata),
            'DoEventSetPropertyReply');
        end;
      MPV_EVENT_COMMAND_REPLY:
        begin
          HandleError(DoEventCommandReply(pe^.error, pe^.reply_userdata,
            P_mpv_event_command(pe^.data)), 'DoEventCommandReply');
        end;
//      MPV_EVENT_AUDIO_RECONFIG: ;
//      MPV_EVENT_QUEUE_OVERFLOW: ;
//      MPV_EVENT_HOOK_: ;
      end;
    end;
  end;
end;

function TMPVBasePlayer.DoEventCommandReply(nErr: MPVInt;  nID: MPVUInt64;
  pEC: P_mpv_event_command): TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventEndFile(pEF: P_mpv_event_end_file): TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventFileLoaded: TMPVErrorCode;
var
  eOpen: TMPVFileOpen;
begin
  m_fSpeed := 1.0;
  m_fLenInSec := -1;
  GetPropertyDouble(STR_DURATION, m_fLenInSec);
  m_sFileName := '';
  GetPropertyString(STR_PATH, m_sFileName);
  // TODO: "://" => get 'media-title'
  GetPropertyInt64(STR_WIDTH, m_nX);
  GetPropertyInt64(STR_HEIGHT, m_nY);
  DoSetVideoSize;

  m_cLock.Enter;
  eOpen := m_eOnFileOpen;
  m_cLock.Leave;
  if Assigned(eOpen) then
  try
    eOpen(Self, m_sFileName);
  except
  end;


  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventGetPropertyReply(nErr: MPVInt; nID: MPVUInt64;
  pEP: P_mpv_event_property): TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventLogMsg(pLM: P_mpv_event_log_message): TMPVErrorCode;
var
  sPF, sLvl, sMsg: string;
  eOnErr: TMPVErrorMessage;
begin
  sPF := pLM^.prefix;
  sLvl := string(UTF8ToString(pLM^.level));
  sMsg := string(UTF8ToString(pLM^.text));
  Log(Format('MPV: prefix=%s, loglevel=%d, level=%s, msg=%s', [sPF,
    pLM^.log_level, sLvl, sMsg]), False);
  if (sLvl='error') then
  begin
    m_cLock.Enter;
    eOnErr := m_eOnErrMsg;
    m_cLock.Leave;
    if Assigned(eOnErr) then
    try
      eOnErr(Self, sPF, pLM^.log_level, sMsg);
    except
    end;
  end;

  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventClientMsg(pCM: P_mpv_event_client_message): TMPVErrorCode;
var
  i: Integer;
  ppc: PPMPVChar;
begin
  if pCM^.num_args>0 then
  begin
    ppc := pCM^.args;
    for i := 0 to pCM^.num_args-1 do
    begin
      Log(Format('MPV clientmsg[%d]=%s', [i, UTF8ToString(ppc^)]), False);
      Inc(ppc);
    end;
  end;
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventPropertyChange(nID: MPVUInt64;
  pEP: P_mpv_event_property): TMPVErrorCode;
var
  s: string;
  cNode: TMPVNode;
  p: Pointer;
  eOnPropChg: TMPVPropertyChangedEvent;
  eOnProg: TMPVProgressEvent;
begin
  Result := MPV_ERROR_SUCCESS;

  case nID of
  ID_PLAY_TIME:
    begin
      case pEP^.format of
      MPV_FORMAT_DOUBLE:
        begin
          m_cLock.Enter;
          m_fCurSec := PDouble(pEP^.data)^;
          m_cLock.Leave;
        end;
      MPV_FORMAT_NONE:
        begin
          m_cLock.Enter;
          m_fCurSec := 0;
          m_cLock.Leave;
        end;
      end;

      m_cLock.Enter;
      eOnProg := m_eOnProgress;
      m_cLock.Leave;
      if Assigned(eOnProg) then
      try
        eOnProg(Self, m_fCurSec, m_fLenInSec);
      except
      end;
    end;
  ID_PAUSE:
    begin
      m_cLock.Enter;
      if PMPVFlag(pEP^.data)^=0 then
        m_eState := mpsPlay
      else
        m_eState := mpsPause;
      m_cLock.Leave;
    end;
  ID_VOLUME:
    begin
      m_cLock.Enter;
      case pEP^.format of
      MPV_FORMAT_DOUBLE:
        m_fVol := PDouble(pEP^.data)^;
      MPV_FORMAT_NONE:
        m_fVol := 0;
      end;
      m_cLock.Leave;
    end;
  ID_DURATION:
    begin
      m_cLock.Enter;
      case pEP^.format of
      MPV_FORMAT_DOUBLE:
        m_fLenInSec := PDouble(pEP^.data)^;
      MPV_FORMAT_NONE:
        m_fLenInSec := 0;
      end;
      m_cLock.Leave;
   end;
  ID_SID:
    begin
      s := VarToStr(GetMPVPropertyValue(pEP^.format, pEP^.data));
      m_cLock.Enter;
      m_sCurSTrk := s;
      m_cLock.Leave;
    end;
  ID_AID:
    begin
      s := VarToStr(GetMPVPropertyValue(pEP^.format, pEP^.data));
      m_cLock.Enter;
      m_sCurATrk := s;
      m_cLock.Leave;
    end;
  ID_VID:
    begin
      s := VarToStr(GetMPVPropertyValue(pEP^.format, pEP^.data));
      m_cLock.Enter;
      m_sCurVTrk := s;
      m_cLock.Leave;
    end;
  ID_SPEED:
    begin
      m_cLock.Enter;
      case pEP^.format of
      MPV_FORMAT_DOUBLE:
        m_fSpeed := PDouble(pEP^.data)^;
      MPV_FORMAT_NONE:
        m_fSpeed := 0;
      end;
      m_cLock.Leave;
    end;
  ID_TRACK_LIST:
    begin
      if pEP^.format=MPV_FORMAT_NODE then
      begin
        cNode := TMPVNode.Create;
        cNode.LoadFromMPVNode(pEP^.data, False);
        //cNode.SaveToFile('.\trklist.txt');
        m_cLock.Enter;
        try
          m_cTrackList.LoadFromNode(cNode);
        except
        end;
        m_cLock.Leave;
        cNode.Free;
      end;
    end;
  ID_AUDIO_DEV:
    begin
      m_cLock.Enter;
      m_sAudioDev := VarToStr(GetMPVPropertyValue(pEP^.format, pEP^.data));
      m_cLock.Leave;
    end;
  ID_AUDIO_DEV_LIST:
    begin
      m_cLock.Enter;
      m_sAudioDevList := VarToStr(GetMPVPropertyValue(pEP^.format, pEP^.data));
      m_cLock.Leave;
      //'[{"name":"auto","description":"Autoselect device"},
      //{"name":"wasapi/{g-u-i-d-e9a4855ad585}",
      // "description":"Speakers (Realtek High Definition Audio(SST))"}]'
    end;
  end;

  m_cLock.Enter;
  eOnPropChg := m_eOnPropChged;
  m_cLock.Leave;
  if Assigned(eOnPropChg) then
  begin
    p := pEP^.data;
    if pEP^.format=MPV_FORMAT_STRING then
    begin
      s := string(UTF8ToString(PPMPVChar(pEP^.data)^));
      p := PAnsiChar(AnsiString(s));
    end;

    try
      eOnPropChg(Self, nID, pEP^.format, p);
    except
    end;
  end;
end;

function TMPVBasePlayer.DoEventRestart: TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventSeek: TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventSetPropertyReply(nErr: MPVInt;
  nID: MPVUInt64): TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventShutdown: TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventStartFile(pSF: P_mpv_event_start_file): TMPVErrorCode;
begin
  Result := MPV_ERROR_SUCCESS;
end;

function TMPVBasePlayer.DoEventVideoReconfig: TMPVErrorCode;
begin
  // might be error at the beginning
  if GetPropertyInt64(STR_DWIDTH, m_nX)=MPV_ERROR_SUCCESS then
  begin
    if GetPropertyInt64(STR_DHEIGHT, m_nY)=MPV_ERROR_SUCCESS then
      DoSetVideoSize;
  end;
  Result := MPV_ERROR_SUCCESS;
end;

procedure TMPVBasePlayer.DoSetVideoSize;
begin
  // NULL
end;

procedure TMPVBasePlayer.FreePlayer;
begin
  if m_cEventThrd<>nil then
  begin
    m_cEventThrd.Terminate;
    m_cEventThrd.WaitFor; // may block after mpv_destroy()
    FreeAndNil(m_cEventThrd);
  end;
  if m_hMPV<>nil then
  begin
    mpv_destroy(m_hMPV);
    //TMPVDestroyThread.Create(m_hMPV);
    m_hMPV := nil;
  end;
end;

function TMPVBasePlayer.GetAudioDev: string;
begin
  m_cLock.Enter;
  Result := m_sAudioDev;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetAudioDevList: string;
begin
  m_cLock.Enter;
  Result := m_sAudioDevList;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetOnErrMsg: TMPVErrorMessage;
begin
  m_cLock.Enter;
  Result := m_eOnErrMsg;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetOnFileOpen: TMPVFileOpen;
begin
  m_cLock.Enter;
  Result := m_eOnFileOpen;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetOnProgChg: TMPVPropertyChangedEvent;
begin
  m_cLock.Enter;
  Result := m_eOnPropChged;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetOnProgress: TMPVProgressEvent;
begin
  m_cLock.Enter;
  Result := m_eOnProgress;
  m_cLock.Leave;
end;

function TMPVBasePlayer.GetPropertyBool(const sName: string;
  var Value: Boolean): TMPVErrorCode;
var
  sNm: UTF8String;
  n: MPVInt;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  n := 0;
  Result := HandleError(mpv_get_property(m_hMPV, PMPVChar(sNm),
    MPV_FORMAT_FLAG, @n), 'mpv_get_property(bool):'+sName);
  Value := n<>0;
end;

function TMPVBasePlayer.GetPropertyDouble(const sName: string;
  var Value: Double): TMPVErrorCode;
var
  sNm: UTF8String;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  Result := HandleError(mpv_get_property(m_hMPV, PMPVChar(sNm),
    MPV_FORMAT_DOUBLE, @Value), 'mpv_get_property(dbl):'+sName);
end;

function TMPVBasePlayer.GetPropertyInt64(const sName: string;
  var Value: Int64): TMPVErrorCode;
var
  sNm: UTF8String;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  Result := HandleError(mpv_get_property(m_hMPV, PMPVChar(sNm),
    MPV_FORMAT_INT64, @Value), 'mpv_get_property(i64):'+sName);
end;

function TMPVBasePlayer.GetPropertyNode(const sName: string;
  cNode: TMPVNode): TMPVErrorCode;
var
  sNm: UTF8String;
  P: P_mpv_node;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  P := nil;  // TODO: test
  Result := HandleError(mpv_get_property(m_hMPV, PMPVChar(sNm),
    MPV_FORMAT_NODE, @P), 'mpv_get_property(node):'+sName);
  if P<>nil then
  begin
    // Get value and free
    cNode.LoadFromMPVNode(P, True);
  end;
end;

function TMPVBasePlayer.GetPropertyString(const sName: string;
  var Value: string): TMPVErrorCode;
var
  sNm: UTF8String;
  P: PMPVChar;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  P := nil;  // TODO: test
  Result := HandleError(mpv_get_property(m_hMPV, PMPVChar(sNm),
    MPV_FORMAT_STRING, @P), 'mpv_get_property(str):'+sName);
  if P<>nil then
  begin
    // Get value and free
    Value := string(UTF8ToString(P));
    mpv_free(P);
  end;
end;

function TMPVBasePlayer.GetState: TMPVPlayerState;
begin
  Result := m_eState;
end;

function TMPVBasePlayer.GetVolume: Double;
var
  dbl: Double;
begin
  dbl := 0;
  if GetPropertyDouble(STR_VOLUME, dbl)=MPV_ERROR_SUCCESS then
    Result := dbl
  else
    Result := -1;
end;

function TMPVBasePlayer.Seek(fPos: Double; bRelative: Boolean): TMPVErrorCode;
var
  sAbs: string;
begin
  if bRelative then sAbs := 'relative' else sAbs := 'absolute';
  Result := Command([CMD_SEEK, FloatToStr(fPos), sAbs]);
end;

function TMPVBasePlayer.InitPlayer(const sWinHandle, sConfigDir: string;
  fEventWait: Double): TMPVErrorCode;
begin
  FreePlayer();

  // Basic procedure copied from MPV.NET
  m_hMPV  := mpv_create();
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_NOMEM;
    Exit;
  end;

  mpv_request_log_messages(m_hMPV, 'terminal-default');

{$IFDEF CONSOLE}
  SetPropertyString('terminal', 'yes');
  SetPropertyString('input-terminal', 'yes');
  SetPropertyString('msg-level', 'osd/libass=fatal');
{$ENDIF}
  SetPropertyInt64('osd-duration', 2000);
//  SetPropertyString('watch-later-options', 'mute');
//  SetPropertyString('screenshot-directory', g_sMPVCfgDir);
  SetPropertyString('osd-playing-msg', '${filename}');
  SetPropertyString(STR_WID, sWinHandle);
  SetPropertyString('osc', 'yes'); // On Screen Control
  SetPropertyString('force-window', 'yes');
  SetPropertyString('config-dir', sConfigDir);
  SetPropertyString('config', 'yes');
  SetPropertyBool('keep-open', True);
  SetPropertyBool('keep-open-pause', False);
  SetPropertyBool('input-default-bindings', True);
  SetPropertyBool('input-builtin-bindings', False);
  SetPropertyString('reset-on-next-file', 'speed,video-aspect-override,af,sub-visibility,audio-delay,pause');

  ProcessCmdLine(True);
  Result := HandleError(mpv_initialize(m_hMPV), 'mpv_initialize');
  if Result<>MPV_ERROR_SUCCESS then Exit;

  m_fEventWait := fEventWait;
  m_cEventThrd := TMPVEventThread.Create(Self);

  ObservePropertyBool(STR_PAUSE, ID_PAUSE);
  ObservePropertyInt64(STR_SID, ID_SID);
  ObservePropertyInt64(STR_AID, ID_AID);
  ObservePropertyInt64(STR_VID, ID_VID);
  ObservePropertyDouble(STR_DURATION, ID_DURATION);
  ObservePropertyDouble(STR_PLAY_TIME, ID_PLAY_TIME);
  ObservePropertyDouble(STR_SPEED, ID_SPEED);
  ObservePropertyDouble(STR_VOLUME, ID_VOLUME);
  ObserveProperty(STR_TRACK_LIST, ID_TRACK_LIST); // Node
  ObservePropertyString(STR_AUDIO_DEV, ID_AUDIO_DEV);
  ObservePropertyString(STR_AUDIO_DEV_LIST, ID_AUDIO_DEV_LIST);

//  ObservePropertyBool(STR_WIN_MAX, ID_WIN_MAX);
//  ObservePropertyBool(STR_WIN_MIN, ID_WIN_MIN);
//  ObservePropertyBool(STR_FULL_SCREEN, ID_FULL_SCREEN);
//  ObservePropertyString(STR_FS_SCREEN_NAME, ID_FS_SCREEN_NAME);
//  ObservePropertyBool(STR_ONTOP, ID_ONTOP);
//  ObservePropertyInt64(STR_ONTOP_LEVEL, ID_ONTOP_LEVEL);
//  ObservePropertyDouble(STR_WIN_SCALE, ID_WIN_SCALE);
  ProcessCmdLine(False);
end;

procedure TMPVBasePlayer.Lock;
begin
  m_cLock.Enter;
end;

procedure TMPVBasePlayer.Log(const sMsg: string; bError: Boolean);
begin
  // NULL
end;

procedure TMPVBasePlayer.MPVFreeMem(P: Pointer);
begin
  FreeMem(P);
end;

procedure TMPVBasePlayer.MPVGetMem(var P: Pointer; nSize: Integer);
begin
  GetMem(P, nSize);
end;

procedure TMPVBasePlayer.NotifyFree;
begin
  if m_cEventThrd<>nil then m_cEventThrd.Terminate;
  m_cLock.Enter;
  m_eOnFileOpen := nil;
  m_eOnProgress := nil;
  m_eOnPropChged := nil;
  m_eOnErrMsg := nil;
  m_cLock.Leave;
end;

function TMPVBasePlayer.ObserveProperty(const sName: string;
  nID: UInt64; nFmt: MPVEnum): TMPVErrorCode;
var
  sNm: UTF8String;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  Result := HandleError(mpv_observe_property(m_hMPV, nID, PMPVChar(sNm), nFmt),
    'mpv_observe_property');
end;

function TMPVBasePlayer.ObservePropertyBool(const sName: string;
  nID: UInt64): TMPVErrorCode;
begin
  Result := ObserveProperty(sName, nID, MPV_FORMAT_FLAG);
end;

function TMPVBasePlayer.ObservePropertyDouble(const sName: string;
  nID: UInt64): TMPVErrorCode;
begin
  Result := ObserveProperty(sName, nID, MPV_FORMAT_DOUBLE);
end;

function TMPVBasePlayer.ObservePropertyInt64(const sName: string;
  nID: UInt64): TMPVErrorCode;
begin
  Result := ObserveProperty(sName, nID, MPV_FORMAT_INT64);
end;

function TMPVBasePlayer.ObservePropertyString(const sName: string;
  nID: UInt64): TMPVErrorCode;
begin
  Result := ObserveProperty(sName, nID, MPV_FORMAT_STRING);
end;

function TMPVBasePlayer.OpenFile(const sFullName: string): TMPVErrorCode;
begin
  Result := Command([CMD_LOAD_FILE, sFullName]);
  SetPropertyBool(STR_PAUSE, False);
end;

function TMPVBasePlayer.Pause: TMPVErrorCode;
begin
  Result := SetPropertyBool(STR_PAUSE, True);
end;

procedure TMPVBasePlayer.ProcessCmdLine(bBeforeInit: Boolean);
begin
  // NULL
end;

function TMPVBasePlayer.Resume: TMPVErrorCode;
begin
  Result := SetPropertyBool(STR_PAUSE, False);
end;

function TMPVBasePlayer.HandleError(nCode: Integer; const sFunc: string;
  bRaise: Boolean): TMPVErrorCode;
var
  sErr: string;
begin
  Result := nCode;
  if nCode = MPV_ERROR_SUCCESS then Exit;

  sErr := Format('%s=%d', [sFunc, nCode]);
  Log(sErr, True);
  if bRaise then
  begin
    raise TMPVException.Create(sErr);
  end;
end;

procedure TMPVBasePlayer.SetATrack(const Value: string);
begin
  SetAudioTrack(Value);
end;

procedure TMPVBasePlayer.SetAudioDev(const Value: string);
begin
  SetPropertyString(STR_AUDIO_DEV, Value);
end;

function TMPVBasePlayer.SetAudioTrack(const sID: string): TMPVErrorCode;
begin
  Result := SetTrack(trkAudio, sID, STR_AID);
end;

procedure TMPVBasePlayer.SetCurSec(const Value: Double);
begin
  Seek(Value, False);
end;

function TMPVBasePlayer.SetMute(bMute: Boolean): TMPVErrorCode;
begin
  Result := SetPropertyBool(STR_MUTE, bMute);
end;

procedure TMPVBasePlayer.SetOnErrMsg(const Value: TMPVErrorMessage);
begin
  m_cLock.Enter;
  m_eOnErrMsg := Value;
  m_cLock.Leave;
end;

procedure TMPVBasePlayer.SetOnFileOpen(const Value: TMPVFileOpen);
begin
  m_cLock.Enter;
  m_eOnFileOpen := Value;
  m_cLock.Leave;
end;

procedure TMPVBasePlayer.SetOnProgChg(const Value: TMPVPropertyChangedEvent);
begin
  m_cLock.Enter;
  m_eOnPropChged := Value;
  m_cLock.Leave;
end;

procedure TMPVBasePlayer.SetOnProgress(const Value: TMPVProgressEvent);
begin
  m_cLock.Enter;
  m_eOnProgress := Value;
  m_cLock.Leave;
end;

function TMPVBasePlayer.SetPropertyBool(const sName: string;
  Value: Boolean; nID: MPVUInt64): TMPVErrorCode;
var
  sNm: UTF8String;
  n: MPVInt;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  if Value then n := 1 else n := 0;

  if nID>0 then
    Result := HandleError(mpv_set_property_async(m_hMPV, nID, PMPVChar(sNm),
      MPV_FORMAT_FLAG, @n), 'mpv_set_property_async(bool)')
  else
    Result := HandleError(mpv_set_property(m_hMPV, PMPVChar(sNm),
      MPV_FORMAT_FLAG, @n), 'mpv_set_property(bool)');
end;

function TMPVBasePlayer.SetPropertyDouble(const sName: string;
  Value: Double; nID: MPVUInt64): TMPVErrorCode;
var
  sNm: UTF8String;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);

  if nID>0 then
    Result := HandleError(mpv_set_property_async(m_hMPV, nID, PMPVChar(sNm),
      MPV_FORMAT_DOUBLE, @Value), 'mpv_set_property_async(dbl)')
  else
    Result := HandleError(mpv_set_property(m_hMPV, PMPVChar(sNm),
      MPV_FORMAT_DOUBLE, @Value), 'mpv_set_property(dbl)');
end;

function TMPVBasePlayer.SetPropertyInt64(const sName: string;
  Value: Int64; nID: MPVUInt64): TMPVErrorCode;
var
  sNm: UTF8String;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);

  if nID>0 then
    Result := HandleError(mpv_set_property_async(m_hMPV, nID, PMPVChar(sNm),
      MPV_FORMAT_INT64, @Value), 'mpv_set_property_async(i64)')
  else
    Result := HandleError(mpv_set_property(m_hMPV, PMPVChar(sNm),
      MPV_FORMAT_INT64, @Value), 'mpv_set_property(i64)');
end;

function TMPVBasePlayer.SetPropertyString(const sName,
  sValue: string; nID: MPVUInt64): TMPVErrorCode;
var
  sNm, sVal: UTF8String;
  p: Pointer;
begin
  if m_hMPV=nil then
  begin
    Result := MPV_ERROR_UNINITIALIZED;
    Exit;
  end;
  sNm := UTF8Encode(sName);
  sVal := UTF8Encode(sValue);
  p := Pointer(sVal); // address of PAnsiChar

  if nID>0 then
    Result := HandleError(mpv_set_property_async(m_hMPV, nID, PMPVChar(sNm),
      MPV_FORMAT_STRING, @p), 'mpv_set_property_async(str)')
 else
    Result := HandleError(mpv_set_property(m_hMPV, PMPVChar(sNm),
      MPV_FORMAT_STRING, @p), 'mpv_set_property(str)');
end;

procedure TMPVBasePlayer.SetSpeed(const Value: Double);
begin
  if (Value>0) and (Value<=100) then
  begin
    SetPropertyDouble(STR_SPEED, Value);
  end;
end;

procedure TMPVBasePlayer.SetSTrack(const Value: string);
begin
  SetSubTitle(Value);
end;

function TMPVBasePlayer.SetSubTitle(const sID: string): TMPVErrorCode;
begin
  Result := SetTrack(trkSub, sID, STR_SID);
end;

function TMPVBasePlayer.SetTrack(eType: TMPVTrackType;
  const sID, sPropName: string): TMPVErrorCode;
var
  m: Integer;
  i: Integer;
  n: Int64;
  cTrk: TMPVTrackInfo;
begin
  n := -1;
  m := StrToIntDef(sID, -2);
  // find title/id
  m_cLock.Enter;
  for i := 0 to m_cTrackList.Count-1 do
  begin
    cTrk := m_cTrackList[i];
    if cTrk.TrackType=eType then
    begin
      if (cTrk.Title=sID) or (cTrk.TrackID=m) then
      begin
        n := cTrk.TrackID;
        Break;
      end;
    end;
  end;
  m_cLock.Leave;
  if n>=0 then
  begin
    Result := SetPropertyInt64(sPropName, n);
  end else
    Result := MPV_ERROR_INVALID_PARAMETER;
end;

function TMPVBasePlayer.SetVideoTrack(const sID: string): TMPVErrorCode;
begin
  Result := SetTrack(trkVideo, sID, STR_VID);
end;

procedure TMPVBasePlayer.SetVol(const Value: Double);
begin
  if (Value>0) and (Value<=1000) then
  begin
    SetPropertyDouble(STR_VOLUME, Value);
  end;
end;

function TMPVBasePlayer.SetVolume(fVol: Double): TMPVErrorCode;
begin
  Result := SetPropertyDouble(STR_VOLUME, fVol);
end;

procedure TMPVBasePlayer.SetVTrack(const Value: string);
begin
  SetVideoTrack(Value);
end;

function TMPVBasePlayer.Stop: TMPVErrorCode;
begin
  Result := CommandStr(CMD_STOP);
end;

procedure TMPVBasePlayer.Unlock;
begin
  m_cLock.Leave;
end;

end.