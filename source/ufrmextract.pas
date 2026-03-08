unit ufrmextract;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, IniFiles, FileUtil, uzpaqbridge, Types, Menus, ComCtrls, uglobals, LCLIntf;

type

  { TExtractMode }
  TExtractMode = (emExtract, emTest);

  { TfrmExtract }

  TfrmExtract = class(TForm)
    btnBrowse: TButton;
    btnAbort: TButton;
    btnCancel: TBitBtn;
    btnOK: TBitBtn;
    cmbDestPath: TComboBox;
    lblDestPath: TLabel;
    lblInfo: TLabel;
    memLog: TMemo;
    pnlBottom: TPanel;
    pnlTop: TPanel;
    pnlExtraFields: TPanel;
    lblTo: TLabel;
    edtTo: TEdit;
    lblFind: TLabel;
    edtFind: TEdit;
    lblReplace: TLabel;
    edtReplace: TEdit;
    pgrProgress: TProgressBar;
    lbleta: TLabel;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    PopupMenuLog: TPopupMenu;
    mnuSaveLog: TMenuItem;
    mnuClearLog: TMenuItem;
    SaveDialog1: TSaveDialog;
    procedure btnAbortClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure cmbDestPathKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure mnuSaveLogClick(Sender: TObject);
    procedure mnuClearLogClick(Sender: TObject);
  private
    FIniFile: TIniFile;
    FIniFileName: string;

    FArchivePath: string;
    FFileName: string;
    FVersion: Integer;
    FPasswordAES: string;
    FPasswordFranzen: string;

    FMode: TExtractMode;

    FSavedOnComplete: TZpaqCompleteEvent;
    FSavedOnLog: TZpaqLogEvent;
    FSavedOnProgress: TZpaqProgressEvent;
    FSavedIsDataMode: Boolean;

    FLogPollTimer: TTimer;

    procedure LoadRecentPaths;
    procedure SaveRecentPath(const APath: string);
    procedure AddToRecentList(const APath: string);
    function BuildCommandLine: string;
    function NormalizePath(const APath: string): string;
    procedure ExecuteCommand;
    procedure OnBridgeComplete(Sender: TObject; ExitCode: Integer);
    function  FormatETA(ASeconds: Integer): string;
    procedure OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
    procedure OnLogPollTimer(Sender: TObject);
    procedure RestoreMainBridge;
    procedure UpdateUIForMode;
    procedure UpdateEditWidths;
    procedure SetRunningState(ARunning: Boolean);
  public
    procedure SetExtractionParams(
      const AArchivePath: string;
      const AFileName: string;
      AVersion: Integer;
      const APasswordAES: string;
      const APasswordFranzen: string);

    procedure SetExtractionParamsAll(
      const AArchivePath: string;
      const APasswordAES: string;
      const APasswordFranzen: string);

    procedure SetTestParams(
      const AArchivePath: string;
      const APasswordAES: string;
      const APasswordFranzen: string);

    procedure SetDLLPath(const ADLLPath: string);
    function GetDestPath: string;

    property Mode: TExtractMode read FMode write FMode;
  end;

var
  frmExtract: TfrmExtract;

implementation

{$R *.lfm}

uses LCLType;

{ ============================================================================ }

function TfrmExtract.NormalizePath(const APath: string): string;
begin
  Result := StringReplace(APath, '\', '/', [rfReplaceAll]);
end;

procedure TfrmExtract.RestoreMainBridge;
begin
  if Assigned(ZpaqBridgeMain) then
  begin
    ZpaqBridgeMain.OnComplete := FSavedOnComplete;
    ZpaqBridgeMain.OnLog      := FSavedOnLog;
    ZpaqBridgeMain.OnProgress := FSavedOnProgress;
    ZpaqBridgeMain.IsDataMode := FSavedIsDataMode;
  end;
end;

{ Centralizza l'aggiornamento dell'UI in base allo stato running/idle.
  running=True  → Abort visibile+abilitato, OK/Cancel/input disabilitati
  running=False → Abort nascosto,            OK/Cancel/input ripristinati }
procedure TfrmExtract.SetRunningState(ARunning: Boolean);
begin
  btnOK.Enabled     := not ARunning;
  btnCancel.Enabled := not ARunning;
  btnAbort.Visible  := ARunning;
  btnAbort.Enabled  := ARunning;
  pgrProgress.Visible := ARunning;
  pgrProgress.Position := 0;
  lbleta.Visible  := ARunning;
  lbleta.Caption  := '00:00:00';
  cmbDestPath.Enabled    := not ARunning;
  btnBrowse.Enabled      := not ARunning;
  pnlExtraFields.Enabled := not ARunning;
end;

procedure TfrmExtract.UpdateUIForMode;
var
  LastBottom: Integer;
begin
  if FMode = emTest then
  begin
    Caption              := 'Test archive';
    lblDestPath.Caption  := 'Temp test folder:';
    btnOK.Caption        := 'Test';
    SelectDirectoryDialog1.Title := 'Select temp test folder';
    pnlExtraFields.Visible := False;
  end
  else
  begin
    lblDestPath.Caption  := 'Destination folder:';
    btnOK.Caption        := 'Extract';
    SelectDirectoryDialog1.Title := 'Select destination folder';
    pnlExtraFields.Visible := True;
  end;

  { Altezza parametrica: bottom dell'ultimo componente visibile + margine }
  if pnlExtraFields.Visible then
    LastBottom := pnlExtraFields.Top + pnlExtraFields.Height
  else
  begin
    { Ultimo componente visibile = cmbDestPath (o btnBrowse, stesso Top+Height) }
    LastBottom := cmbDestPath.Top + cmbDestPath.Height;
  end;
  pnlTop.Height := LastBottom + 20;   { margine inferiore 20px (scaled units) }

  UpdateEditWidths;
end;

procedure TfrmExtract.UpdateEditWidths;
var
  W: Integer;
begin
  W := ClientWidth - 10;
  if W < 50 then W := 50;
  edtTo.Width      := W - edtTo.Left;
  edtFind.Width    := W - edtFind.Left;
  edtReplace.Width := W - edtReplace.Left;
  pgrprogress.width:= btnabort.left-pgrprogress.left-4;
end;

procedure TfrmExtract.FormCreate(Sender: TObject);
begin
  FIniFileName := GetCatpaqIniPath;
  FIniFile     := TIniFile.Create(FIniFileName);

  FSavedOnComplete := nil;
  FSavedOnLog      := nil;
  FSavedOnProgress := nil;
  FSavedIsDataMode := False;

  FLogPollTimer          := TTimer.Create(Self);
  FLogPollTimer.Interval := 150;
  FLogPollTimer.Enabled  := False;
  FLogPollTimer.OnTimer  := @OnLogPollTimer;

  btnOK.ModalResult := mrNone;
  btnAbort.Visible  := False;
  btnAbort.Enabled  := False;
  pgrProgress.Visible := False;
  lbleta.Visible  := False;
  lbleta.Caption  := '00:00:00';

  FMode := emExtract;

  KeyPreview := True;

  LoadRecentPaths;
  UpdateUIForMode;
end;

procedure TfrmExtract.FormDestroy(Sender: TObject);
begin
  FLogPollTimer.Enabled := False;
  RestoreMainBridge;
  FIniFile.Free;
end;

{ Intercetta la chiusura quando un'operazione è in corso:
  chiede conferma, poi chiama AbortCommand prima di chiudere }
procedure TfrmExtract.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Assigned(ZpaqBridgeMain) and ZpaqBridgeMain.Busy then
  begin
    if MessageDlg('Operation in progress. Abort and close?',
                  mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      CloseAction := caNone;
      Exit;
    end;
    ZpaqBridgeMain.AbortCommand;
    Sleep(200);
    Application.ProcessMessages;
  end;
end;

procedure TfrmExtract.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Close;  { FormClose gestisce il caso busy }
  end;
end;

procedure TfrmExtract.cmbDestPathKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    btnOKClick(Self);
  end;
end;

procedure TfrmExtract.FormResize(Sender: TObject);
begin
  UpdateEditWidths;
end;

{ --- Log popup --- }

procedure TfrmExtract.mnuSaveLogClick(Sender: TObject);
begin
  SaveDialog1.DefaultExt := 'txt';
  SaveDialog1.Filter := 'Text files (*.txt)|*.txt|All files (*.*)|*.*';
  SaveDialog1.FileName := 'log_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.txt';
  if SaveDialog1.Execute then
    memLog.Lines.SaveToFile(SaveDialog1.FileName);
end;

procedure TfrmExtract.mnuClearLogClick(Sender: TObject);
begin
  memLog.Lines.Clear;
end;


{ --- Abort --- }

procedure TfrmExtract.btnAbortClick(Sender: TObject);
begin
  if not (Assigned(ZpaqBridgeMain) and ZpaqBridgeMain.Busy) then Exit;
  if MessageDlg('Abort current operation?',
                mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  ZpaqBridgeMain.AbortCommand;
  btnAbort.Enabled := False;  { Disabilita subito per evitare doppio click }
  memLog.Lines.Add('');
  memLog.Lines.Add('>>> Abort requested by user...');
end;

{ --- Params --- }

procedure TfrmExtract.SetExtractionParams(
  const AArchivePath: string;
  const AFileName: string;
  AVersion: Integer;
  const APasswordAES: string;
  const APasswordFranzen: string);
begin
  FMode            := emExtract;
  FArchivePath     := AArchivePath;
  FFileName        := AFileName;
  FVersion         := AVersion;
  FPasswordAES     := APasswordAES;
  FPasswordFranzen := APasswordFranzen;

  if FFileName <> '' then
    Caption := 'Extract: ' + ExtractFileName(ExcludeTrailingPathDelimiter(FFileName))
  else
    Caption := 'Extract from archive';

  if FFileName <> '' then
    lblInfo.Caption := 'File: ' + FFileName +
                       '   Version: ' + IntToStr(FVersion)
  else
    lblInfo.Caption := 'Archive: ' + ExtractFileName(FArchivePath) +
                       '   (extract everything)';

  UpdateUIForMode;
end;

procedure TfrmExtract.SetExtractionParamsAll(
  const AArchivePath: string;
  const APasswordAES: string;
  const APasswordFranzen: string);
begin
  SetExtractionParams(AArchivePath, '', -1, APasswordAES, APasswordFranzen);
  Caption := 'Extract everything from archive';
end;

procedure TfrmExtract.SetTestParams(
  const AArchivePath: string;
  const APasswordAES: string;
  const APasswordFranzen: string);
begin
  FMode            := emTest;
  FArchivePath     := AArchivePath;
  FFileName        := '';
  FVersion         := -1;
  FPasswordAES     := APasswordAES;
  FPasswordFranzen := APasswordFranzen;

  Caption          := 'Test archive: ' + ExtractFileName(AArchivePath);
  lblInfo.Caption  := 'Archive: ' + ExtractFileName(AArchivePath);

  UpdateUIForMode;
end;

procedure TfrmExtract.SetDLLPath(const ADLLPath: string);
begin
  // Non serve
end;

function TfrmExtract.GetDestPath: string;
begin
  Result := Trim(cmbDestPath.Text);
end;

procedure TfrmExtract.LoadRecentPaths;
var
  i: Integer;
  P: string;
begin
  cmbDestPath.Items.Clear;
  for i := 1 to 10 do
  begin
    P := FIniFile.ReadString('RecentExtractPaths', 'Path' + IntToStr(i), '');
    if P <> '' then
      cmbDestPath.Items.Add(P);
  end;
  if cmbDestPath.Items.Count > 0 then
    cmbDestPath.ItemIndex := 0;
end;

procedure TfrmExtract.SaveRecentPath(const APath: string);
var
  i: Integer;
begin
  if APath = '' then Exit;
  AddToRecentList(APath);
  for i := 0 to cmbDestPath.Items.Count - 1 do
    if i < 10 then
      FIniFile.WriteString('RecentExtractPaths', 'Path' + IntToStr(i + 1),
                           cmbDestPath.Items[i]);
  FIniFile.UpdateFile;
end;

procedure TfrmExtract.AddToRecentList(const APath: string);
var
  idx: Integer;
begin
  idx := cmbDestPath.Items.IndexOf(APath);
  if idx >= 0 then
    cmbDestPath.Items.Delete(idx);
  cmbDestPath.Items.Insert(0, APath);
  cmbDestPath.ItemIndex := 0;
  while cmbDestPath.Items.Count > 10 do
    cmbDestPath.Items.Delete(cmbDestPath.Items.Count - 1);
end;

function TfrmExtract.BuildCommandLine: string;
var
  DestPath: string;
  ToVal, FindVal, ReplaceVal: string;
begin
  DestPath := NormalizePath(Trim(cmbDestPath.Text));

  if FMode = emTest then
  begin
    Result := 't "' + NormalizePath(FArchivePath) + '"';
    if DestPath <> '' then
      Result := Result + ' -to "' + DestPath + '"';
    if FPasswordAES <> '' then
      Result := Result + ' -key "' + FPasswordAES + '"';
    if FPasswordFranzen <> '' then
      Result := Result + ' -franzen "' + FPasswordFranzen + '"';
    Result := Result + ' -catpaqmode';
  end
  else
  begin
    Result := 'x "' + NormalizePath(FArchivePath) + '"';
    if FFileName <> '' then
      Result := Result + ' "' + NormalizePath(FFileName) + '"';
    Result := Result + ' -to "' + DestPath + '"';
    if (FVersion > 0) and (FFileName <> '') then
      Result := Result + ' -until ' + IntToStr(FVersion);
    if FPasswordAES <> '' then
      Result := Result + ' -key "' + FPasswordAES + '"';
    if FPasswordFranzen <> '' then
      Result := Result + ' -franzen "' + FPasswordFranzen + '"';

    ToVal      := Trim(edtTo.Text);
    FindVal    := Trim(edtFind.Text);
    ReplaceVal := Trim(edtReplace.Text);
    if ToVal <> '' then
      Result := Result + ' -to "' + ToVal + '"';
    if FindVal <> '' then
      Result := Result + ' -find "' + FindVal + '"';
    if ReplaceVal <> '' then
      Result := Result + ' -replace "' + ReplaceVal + '"';
    Result := Result + ' -catpaqmode';
  end;
end;

procedure TfrmExtract.ExecuteCommand;
var
  DestPath, CommandLine: string;
begin
  DestPath := Trim(cmbDestPath.Text);

  if (FMode = emExtract) and (DestPath = '') then
  begin
    ShowMessage('Please enter or select a destination folder.');
    cmbDestPath.SetFocus;
    Exit;
  end;

  if DestPath <> '' then
  begin
    if (FMode = emExtract) and DirectoryExists(DestPath) then
    begin
      if MessageDlg('The destination folder already exists.' + LineEnding +
                    'Overwrite existing files?',
                    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Exit;
    end;
    if not ForceDirectories(DestPath) then
    begin
      ShowMessage('Cannot create folder:' + LineEnding + DestPath);
      Exit;
    end;
  end;

  if not Assigned(ZpaqBridgeMain) then
  begin
    ShowMessage('Internal error: main bridge not available.');
    Exit;
  end;

  if ZpaqBridgeMain.Busy then
  begin
    ShowMessage('Bridge is busy, please wait.');
    Exit;
  end;

  if not ZpaqBridgeMain.LoadDLL then
  begin
    ShowMessage('zpaqfranz DLL not found.');
    Exit;
  end;

  if DestPath <> '' then
    SaveRecentPath(DestPath);

  CommandLine := BuildCommandLine;

  if (FMode = emExtract) and (DestPath <> '') and DirectoryExists(DestPath) then
    CommandLine := CommandLine + ' -force';

  if FMode = emTest then
  begin
    memLog.Lines.Add('');
    memLog.Lines.Add('=== Starting Test ===');
    memLog.Lines.Add('Archive: ' + FArchivePath);
    if DestPath <> '' then
      memLog.Lines.Add('Temp folder: ' + DestPath);
  end
  else
  begin
    memLog.Lines.Add('');
    memLog.Lines.Add('=== Starting Extraction ===');
    memLog.Lines.Add('Archive    : ' + FArchivePath);
    if FFileName <> '' then
      memLog.Lines.Add('File/Folder: ' + FFileName)
    else
      memLog.Lines.Add('File/Folder: (everything)');
    if (FVersion > 0) and (FFileName <> '') then
      memLog.Lines.Add('Version    : ' + IntToStr(FVersion))
    else
      memLog.Lines.Add('Version    : latest');
    memLog.Lines.Add('Destination: ' + DestPath);
  end;

  memLog.Lines.Add('');
  memLog.Lines.Add('Command: zpaqfranz ' + CommandLine);
  memLog.Lines.Add('');

  FSavedOnComplete := ZpaqBridgeMain.OnComplete;
  FSavedOnLog      := ZpaqBridgeMain.OnLog;
  FSavedOnProgress := ZpaqBridgeMain.OnProgress;
  FSavedIsDataMode := ZpaqBridgeMain.IsDataMode;

  ZpaqBridgeMain.OnLog      := nil;
  ZpaqBridgeMain.OnComplete := @OnBridgeComplete;
  ZpaqBridgeMain.OnProgress := @OnBridgeProgress;
  ZpaqBridgeMain.IsDataMode := False;

  SetRunningState(True);
  FLogPollTimer.Enabled := True;

  if not ZpaqBridgeMain.RunCommandAsync(CommandLine) then
  begin
    FLogPollTimer.Enabled := False;
    SetRunningState(False);
    RestoreMainBridge;
    if FMode = emTest then
      memLog.Lines.Add('ERROR: Failed to execute test')
    else
      memLog.Lines.Add('ERROR: Failed to execute extraction');
    ShowMessage('Failed to execute zpaqfranz.');
  end;
end;

procedure TfrmExtract.OnLogPollTimer(Sender: TObject);
var
  LogBuf: TStringList;
  I: Integer;
  Line: string;
  PP: Integer;
begin
  if not Assigned(ZpaqBridgeMain) then Exit;
  LogBuf := ZpaqBridgeMain.FlushLogBuffer;
  try
    if LogBuf.Count = 0 then Exit;
    memLog.Lines.BeginUpdate;
    try
      for I := 0 to LogBuf.Count - 1 do
      begin
        Line := LogBuf[I];
        { Filtra eventuali righe di progresso \r-based residue che non
          sono state intercettate dal bridge (testo libero senza @SPK@).
          Criterio: riga trimmed che inizia con un numero e contiene '%'
          nelle prime 8 posizioni — identico al vecchio TryParsePercent. }
        PP := Pos('%', TrimLeft(Line));
        if (PP >= 2) and (PP <= 8) then Continue;
        memLog.Lines.Add(Line);
      end;
    finally
      memLog.Lines.EndUpdate;
    end;
  finally
    LogBuf.Free;
  end;
end;

function TfrmExtract.FormatETA(ASeconds: Integer): string;
var
  H, M, S: Integer;

  function Pad2(N: Integer): string;
  begin
    if N > 99 then N := 99;
    if N < 0  then N := 0;
    Result := IntToStr(N);
    if Length(Result) < 2 then Result := '0' + Result;
  end;

begin
  if ASeconds < 0 then ASeconds := 0;
  H := ASeconds div 3600;
  M := (ASeconds mod 3600) div 60;
  S := ASeconds mod 60;
  Result := Pad2(H) + ':' + Pad2(M) + ':' + Pad2(S);
end;

procedure TfrmExtract.OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
begin
  { Riceve il progresso dal bridge via QueueAsyncCall (TriggerProgress).
    Funziona per @SPK@EXT@ (extract/test) in tempo reale,
    grazie al \n+fflush() aggiunto in print_progress() C++. }
  if not pgrProgress.Visible then Exit;
  pgrProgress.Max      := 100;
  pgrProgress.Position := Percent;
  if lbleta.Visible then
    lbleta.Caption := FormatETA(ZpaqBridgeMain.ProgETA);
end;

procedure TfrmExtract.OnBridgeComplete(Sender: TObject; ExitCode: Integer);
var
  LogBuf: TStringList;
  Msg: string;
  OpName: string;
  WasAborted: Boolean;
  FFlushIdx: Integer;
  FFlushLine: string;
  FFlushPP: Integer;
begin
  FLogPollTimer.Enabled := False;

  { Flush del buffer residuo }
  if Assigned(ZpaqBridgeMain) then
  begin
    LogBuf := ZpaqBridgeMain.FlushLogBuffer;
    try
      if LogBuf.Count > 0 then
      begin
        memLog.Lines.BeginUpdate;
        try
          for FFlushIdx := 0 to LogBuf.Count - 1 do
          begin
            { Salta righe di progresso testo-libero residue (\r-based) }
            FFlushLine := TrimLeft(LogBuf[FFlushIdx]);
            FFlushPP   := Pos('%', FFlushLine);
            if (FFlushPP >= 2) and (FFlushPP <= 8) then Continue;
            memLog.Lines.Add(LogBuf[FFlushIdx]);
          end;
        finally
          memLog.Lines.EndUpdate;
        end;
      end;
    finally
      LogBuf.Free;
    end;
  end;

  if FMode = emTest then
    OpName := 'Test'
  else
    OpName := 'Extraction';

  { Se btnAbort è già stato disabilitato (dall'utente) ed ExitCode <> 0
    significa che siamo stati noi ad abortire }
  WasAborted := (not btnAbort.Enabled) and btnAbort.Visible and (ExitCode <> 0);

  memLog.Lines.Add('');
  if WasAborted then
    memLog.Lines.Add('--- ' + OpName + ' ABORTED by user ---')
  else
    memLog.Lines.Add('--- ' + OpName + ' complete --- Exit code: ' + IntToStr(ExitCode));

  RestoreMainBridge;
  SetRunningState(False);

  if WasAborted then
  begin
    { Nessun MessageDlg: l'utente ha già confermato l'abort }
  end
  else if ExitCode = 0 then
  begin
    if FMode = emTest then
    begin
      Msg := OpName + ' completed successfully.';
      memLog.Lines.Add(Msg);
      ShowMessage(Msg);
    end
    else
    begin
      Msg := OpName + ' completed successfully.' + LineEnding +
             'Destination: ' + Trim(cmbDestPath.Text);
      memLog.Lines.Add(Msg);
      { Chiede se aprire la cartella di destinazione. Default: No (mbNo). }
      if MessageDlg('Extraction completed successfully.' + LineEnding +
                    'Destination: ' + Trim(cmbDestPath.Text) + LineEnding + LineEnding +
                    'Open destination folder?',
                    mtConfirmation, [mbYes, mbNo], 0, mbNo) = mrYes then
        OpenDocument(Trim(cmbDestPath.Text));
    end;
  end
  else
  begin
    Msg := OpName + ' failed (exit code ' + IntToStr(ExitCode) + ').' + LineEnding +
           'Check the log for details.';
    memLog.Lines.Add('ERROR: ' + Msg);
    ShowMessage(Msg);
  end;
end;

procedure TfrmExtract.btnBrowseClick(Sender: TObject);
begin
  if (cmbDestPath.Text <> '') and DirectoryExists(cmbDestPath.Text) then
    SelectDirectoryDialog1.FileName := cmbDestPath.Text;
  if SelectDirectoryDialog1.Execute then
    cmbDestPath.Text := SelectDirectoryDialog1.FileName;
end;

procedure TfrmExtract.btnCancelClick(Sender: TObject);
begin
  Close;  { FormClose gestisce il caso busy con conferma }
end;

procedure TfrmExtract.btnOKClick(Sender: TObject);
begin
  if (FMode = emExtract) and (Trim(cmbDestPath.Text) = '') then
  begin
    ShowMessage('Please enter or select a destination folder.');
    cmbDestPath.SetFocus;
    Exit;
  end;
  ExecuteCommand;
end;

end.
