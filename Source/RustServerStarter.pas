unit RustServerStarter;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, IniFiles,
  Vcl.ComCtrls, Winsock, ShellApi, JSON, IdHTTP, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg, WinHttp, ComObj, IdBaseComponent, IdComponent, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, URLMon;

type
  TMainForm = class(TForm)
    ButtonStartServer: TButton;
    LuancherOptions: TPanel;
    LEIP: TLabeledEdit;
    LEPort: TLabeledEdit;
    LETickrate: TLabeledEdit;
    LEHostname: TLabeledEdit;
    LEIdentity: TLabeledEdit;
    LEMaxPlayers: TLabeledEdit;
    LEWolrdsize: TLabeledEdit;
    LESaveinterval: TLabeledEdit;
    LErconIP: TLabeledEdit;
    LErconPort: TLabeledEdit;
    LElogFile: TLabeledEdit;
    LErconPassword: TLabeledEdit;
    LEMapseed: TLabeledEdit;
    ListBox1: TListBox;
    ButtonLoadConfig: TButton;
    Mlog: TMemo;
    MainMenu1: TMainMenu;
    Console1: TMenuItem;
    Luancher1: TMenuItem;
    Help1: TMenuItem;
    ButtonSaveConfig: TButton;
    CBSecure: TCheckBox;
    CBautoupdate: TCheckBox;
    CBoxLevel: TComboBox;
    LLevel: TLabel;
    MemoDescription: TMemo;
    LServerDescription: TLabel;
    Panel1: TPanel;
    LHelpVer: TLabel;
    LConfig: TLabel;
    ClearLog1: TMenuItem;
    StatusBar1: TStatusBar;
    ButtonDeleteConfig: TButton;
    LHelp2: TLabel;
    LHelp3: TLabel;
    Image1: TImage;
    Image2: TImage;
    LHelp4: TLabel;
    LHelp5: TLabel;
    LHelp6: TLabel;
    LHelp7: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure Console1Click(Sender: TObject);
    procedure Luancher1Click(Sender: TObject);
    procedure ButtonStartServerClick(Sender: TObject);
    procedure LoadString();
    procedure LEIPChange(Sender: TObject);
    procedure LEPortChange(Sender: TObject);
    procedure Help1Click(Sender: TObject);
    procedure ButtonSaveConfigClick(Sender: TObject);
    procedure ButtonLoadConfigClick(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure LoadConfigs();
    procedure LoadINI();
    procedure CreateINI();
    procedure ClearLog1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FindRust();
    procedure startRustServer();
    procedure ButtonDeleteConfigClick(Sender: TObject);
    procedure Image2Click(Sender: TObject);
    procedure Image1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    ip,port,host,identity, tickrate, ronIP, rconPassword, logfile, startexe,
    maxplayers, wolrdsize, saveinterval, rconPort, mapSeed, secure, autoupdate,
    level, description, BasePath, inifile, secureValue, descriptionRemoveBreak,
    loadconfig, batchmode,rustEXE, commands, currentVersion, newVersion :String;
    Serverhandle :hwnd;
  end;

var
  MainForm: TMainForm;
  Ini:TIniFile;

implementation

{$R *.dfm}

function GetAppVersionStr: string;
var
  Exe: string;
  Size, Handle: DWORD;
  Buffer: TBytes;
  FixedPtr: PVSFixedFileInfo;
begin
  Exe := ParamStr(0);
  Size := GetFileVersionInfoSize(PChar(Exe), Handle);
  if Size = 0 then
    RaiseLastOSError;
  SetLength(Buffer, Size);
  if not GetFileVersionInfo(PChar(Exe), Handle, Size, Buffer) then
    RaiseLastOSError;
  if not VerQueryValue(Buffer, '\', Pointer(FixedPtr), Size) then
    RaiseLastOSError;
  Result := Format('%d.%d.%d.%d',
    [LongRec(FixedPtr.dwFileVersionMS).Hi,  //major
     LongRec(FixedPtr.dwFileVersionMS).Lo,  //minor
     LongRec(FixedPtr.dwFileVersionLS).Hi,  //release
     LongRec(FixedPtr.dwFileVersionLS).Lo]) //build
end;

function GetIPAddress: Integer;
var
  Buffer: array[0..255] of AnsiChar;
  RemoteHost: PHostEnt;
begin
  Winsock.GetHostName(@Buffer, 255);
  RemoteHost := Winsock.GetHostByName(Buffer);
  if RemoteHost = nil then
    Result := winsock.htonl($07000001) { 127.0.0.1 }
  else
    Result := longint(pointer(RemoteHost^.h_addr_list^)^);
    Result := Winsock.ntohl(Result);
end;// function GetIPAddress: Integer;

function GetIPAddressAsString: String;
var
  tempAddress: Integer;
  Buffer: array[0..3] of Byte absolute tempAddress;
begin
  tempAddress := GetIPAddress;
  Result := Format('%d.%d.%d.%d', [Buffer[3], Buffer[2], Buffer[1], Buffer[0]]);
end;// function GetIPAddressAsString: String;

function GetGlobalIP():String;
  var  LJsonObj   : TJSONObject;
  str:string;
  http : TIdHttp;
  begin
    str:='';
    http:=TIdHTTP.Create(nil);
    try
        str:=http.Get('http://ipinfo.io/json');
        LJsonObj:= TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(str),0)           as TJSONObject;
        str := LJsonObj.Get('ip').JsonValue.Value;
        LJsonObj.Free;
        http.Free;
    Except
    end;
    result:=str;
end;

function DownloadFile(SourceFile, DestFile: string): Boolean;
begin
  try
    Result := UrlDownloadToFile(nil, PChar(SourceFile), PChar(DestFile), 0, nil) = 0;
  except
    Result := False;
  end;
end;


//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////


procedure TMainForm.startRustServer();
 var
  wideChars   : array[0..511] of WideChar;
  filename :PWideChar;
  parameters :PWideChar;
begin
  filename := 'RustDedicated.exe ';
  parameters := StringToWideChar(commands,wideChars, 512);
  ShellExecute(Serverhandle,'RunAs',PChar(BasePath+filename), PChar(parameters),'',SW_SHOWNORMAL);
end;

procedure TMainForm.LoadINI();
begin
  MemoDescription.Clear;
  ini := TIniFile.Create(inifile);
  try
    LEIdentity.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.identity', LEIdentity.Text);
    LEIP.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.ip', LEIP.Text);
    LEPort.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.port', LEPort.Text);
    LEHostname.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.hostname', LEHostname.Text);
    LEMaxPlayers.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.maxplayers', LEMaxPlayers.Text);
    LEMapseed.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.seed', LEMapseed.Text);
    LETickrate.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.tickrate', LETickrate.Text);
    LEWolrdsize.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.wolrdsize', LEWolrdsize.Text);
    LESaveinterval.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.saveinterval', LESaveinterval.Text);
    CBoxLevel.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.level', CBoxLevel.Text);
    LElogFile.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.logfile', LElogFile.Text);
    MemoDescription.Lines.Add(Ini.ReadString(listbox1.items[listbox1.itemindex], '+server.description', descriptionRemoveBreak));
    LErconIP.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+rcon.ip', LErconIP.Text);
    LErconPort.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+rcon.port', LErconPort.Text);
    LErconPassword.Text:= Ini.ReadString(listbox1.items[listbox1.itemindex], '+rcon.password', LErconPassword.Text);
  finally
    ini.Free;
  end;
end;

procedure TMainForm.CreateINI();
begin
  LoadString();                         //Full string command
  ini := TIniFile.Create(inifile);
  try                                   //write to config
    ini.WriteString(LEIdentity.Text, '+server.identity', LEIdentity.Text);
    ini.WriteString(LEIdentity.Text, '+server.ip', LEIP.Text);
    ini.WriteString(LEIdentity.Text, '+server.port', LEPort.Text);
    ini.WriteString(LEIdentity.Text, '+server.hostname', LEHostname.Text);
    ini.WriteString(LEIdentity.Text, '+server.maxplayers', LEMaxPlayers.Text);
    ini.WriteString(LEIdentity.Text, '+server.seed', LEMapseed.Text);
    ini.WriteString(LEIdentity.Text, '+server.tickrate', LETickrate.Text);
    ini.WriteString(LEIdentity.Text, '+server.wolrdsize', LEWolrdsize.Text);
    ini.WriteString(LEIdentity.Text, '+server.saveinterval', LESaveinterval.Text);
    ini.WriteString(LEIdentity.Text, '+server.level', CBoxLevel.Text);
    ini.WriteString(LEIdentity.Text, '+rcon.ip', LErconIP.Text);
    ini.WriteString(LEIdentity.Text, '+rcon.port', LErconPort.Text);
    ini.WriteString(LEIdentity.Text, '+rcon.password', LErconPassword.Text);
    ini.WriteString(LEIdentity.Text, '+server.logfile', LElogFile.Text);
    ini.WriteString(LEIdentity.Text, '+server.description', descriptionRemoveBreak);
    ini.WriteString(LEIdentity.Text, '+server.secure', secureValue);
    ini.WriteString(LEIdentity.Text, 'autoupdate', autoupdate);
  finally
    ini.Free;
  end;
end;


procedure TMainForm.FindRust();
var
  fileName, fullFilePath : string;
begin
   fileName := 'RustDedicated.exe';
   fullFilePath := FileSearch(fileName, BasePath);
   if fullFilePath = '' then
    begin
      Mlog.Lines.Add(fileName+' not found');
      ButtonStartServer.Enabled := False;
    end
   else
    begin
      Mlog.Lines.Add(fullFilePath+' found OK');
      rustEXE:=fullFilePath;
      ButtonStartServer.Enabled := True;
    end;
end;

procedure TMainForm.LoadConfigs();
begin
  ini := TIniFile.Create(inifile);
  try
    ini.ReadSections(ListBox1.Items);
  finally
    ini.Free;
  end;
end;

procedure TMainForm.LEIPChange(Sender: TObject);
begin
  LErconIP.Text:=LEIP.Text;
end;

procedure TMainForm.LEPortChange(Sender: TObject);
begin
  LErconPort.Text:=LEPort.Text;
end;

procedure TMainForm.ListBox1Click(Sender: TObject);
begin
  loadconfig:=listbox1.items[listbox1.itemindex];
  Mlog.Lines.Add('Loading config: '+loadconfig);
end;

procedure TMainForm.LoadString();
begin
  if CBSecure.Checked = true then
    secureValue:= 'true'
  else
    secureValue:= 'false';

  if CBautoupdate.Checked = true then
    autoupdate:= '-autoupdate '
  else
    autoupdate:= '';

  descriptionRemoveBreak := StringReplace(StringReplace(MemoDescription.Text, #10, '', [rfReplaceAll]), #13, '', [rfReplaceAll]);
  startexe      :='RustDedicated.exe ';
  batchmode     := '-batchmode ';
  ronIP         := '+rcon.ip '+LErconIP.Text+' ';
  rconPort      := '+rcon.port '+LErconPort.Text+' ';
  rconPassword  := '+rcon.password "'+LErconPassword.Text+'" ';
  ip            := '+server.ip '+LEIP.Text+' ';
  port          := '+server.port '+LEPort.Text+' ';
  host          := '+server.hostname "'+LEHostname.Text+'" ';
  identity      := '+server.identity "'+LEIdentity.Text+'" ';
  saveinterval  := '+server.saveinterval '+LESaveinterval.Text+' ';
  tickrate      := '+server.tickrate '+LETickrate.Text+' ';
  wolrdsize     := '+server.wolrdsize '+LEWolrdsize.Text+' ';
  mapSeed       := '+server.seed "'+LEMapseed.Text+'" ';
  maxplayers    := '+server.maxplayers '+LEMaxPlayers.Text+' ';
  logfile       := '+server.logfile "'+LElogFile.Text+'" ';
  secure        := '+server.secure '+secureValue+' ';
  level         := '+server.level "'+CBoxLevel.Text+'" ';
  description   := '+server.description "'+descriptionRemoveBreak+'" ';

end;

procedure TMainForm.ButtonStartServerClick(Sender: TObject);
begin
  LoadString();
  commands := batchmode+ip+port+host+ronIP+rconPort+rconPassword+host+
  identity+maxplayers+wolrdsize+mapSeed+level+tickrate+saveinterval+
  secure+description+logfile+autoupdate;
  Mlog.Lines.Add(commands);
  Mlog.Lines.Add('Starting server...');
  startRustServer();
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  wVersionRequested : WORD;
  wsaData : TWSAData;
begin
  {Start up WinSock}
  wVersionRequested := MAKEWORD(1, 1);
  WSAStartup(wVersionRequested, wsaData);
  currentVersion :=GetAppVersionStr;
  MainForm.Caption    := 'Rust Server Starter';
  Mlog.Lines.Add('Thanks for using Rust Server Starter!');
  Mlog.Lines.Add('Current version '+currentVersion);
  LEIP.Text           := GetIPAddressAsString;
  LEPort.Text         :='28015';
  LEHostname.Text     :='Rust server';
  LEIdentity.Text     :='Rust_server';
  LETickrate.Text     :='30';
  LEMaxPlayers.Text   :='50';
  LEMapseed.Text      :='1234567';
  LEWolrdsize.Text    :='2000';
  LESaveinterval.Text :='300';
  LErconIP.Text       :=GetIPAddressAsString;
  LErconPort.Text     :='28015';
  LErconPassword.Text :='';
  LElogFile.Text      :='output.txt';
  LHelp3.Caption      := MainForm.Caption;
  BasePath:= ExtractFilePath(ParamStr(0));
  Mlog.Lines.Add('Path: '+BasePath);
  inifile := ChangeFileExt( Application.ExeName, '.INI');
  LoadConfigs();
  Mlog.Lines.Add('Looking up Local IP: '+GetIPAddressAsString);
  Mlog.Lines.Add('Looking up Global IP: '+GetGlobalIP);
  StatusBar1.Panels[0].Text:= 'Local IP: '+GetIPAddressAsString();
  StatusBar1.Panels[1].Text:= 'Global IP: '+GetGlobalIP();
  FindRust();
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  {Shut down WinSock}
  WSACleanup;
end;

procedure TMainForm.Help1Click(Sender: TObject);
begin
  Mlog.Visible := False;
  LuancherOptions.Visible := False;
  Panel1.Visible := True;
  LHelpVer.Caption :='Version '+GetAppVersionStr;
end;

procedure TMainForm.Image1Click(Sender: TObject);
var
  URL: string;
begin
  URL := 'https://github.com/Limmek/RustServerStarter';
  URL := StringReplace(URL, '"', '%22', [rfReplaceAll]);
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);

end;

procedure TMainForm.Image2Click(Sender: TObject);
var
  URL: string;
begin
  URL := 'https://www.paypal.me/limmek';
  URL := StringReplace(URL, '"', '%22', [rfReplaceAll]);
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.Luancher1Click(Sender: TObject);
begin
  Mlog.Visible := False;
  LuancherOptions.Visible := True;
  Panel1.Visible := False;
end;

procedure TMainForm.ClearLog1Click(Sender: TObject);
begin
 Mlog.Lines.Clear;
end;

procedure TMainForm.Console1Click(Sender: TObject);
begin
  Mlog.Visible := True;
  LuancherOptions.Visible := False;
  Panel1.Visible := False;
end;

procedure TMainForm.ButtonDeleteConfigClick(Sender: TObject);
begin
  ini := TIniFile.Create(inifile);
  try
    ini.EraseSection(listbox1.items[listbox1.itemindex]);
  finally
    ini.Free;
  end;
  LoadConfigs();
  Mlog.Lines.Add('Removed config: '+listbox1.items[listbox1.itemindex]);
end;

procedure TMainForm.ButtonLoadConfigClick(Sender: TObject);
begin
  LoadINI();
  Mlog.Lines.Add('Loaded config: '+listbox1.items[listbox1.itemindex]);
end;

procedure TMainForm.ButtonSaveConfigClick(Sender: TObject);
begin
  CreateINI();
  LoadConfigs();
  Mlog.Lines.Add('Saved config: '+listbox1.items[listbox1.itemindex]);
end;

end.
