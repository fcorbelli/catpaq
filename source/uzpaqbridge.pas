unit uzpaqbridge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Forms, ucatpaqtypes;

type
  TZpaqCompleteEvent  = procedure(Sender: TObject; ExitCode: Integer) of object;
  TZpaqLogEvent       = procedure(Sender: TObject; const ALine: string) of object;
  TZpaqProgressEvent  = procedure(Sender: TObject; Percent: Integer; const AMsg: string) of object;

  { Forward declaration }
  TZpaqBridge = class;

  { TZpaqReaderThread
    Legge stdout+stderr del processo zpaqfranz in un thread dedicato.
    Questo è il pattern corretto su macOS, dove TAsyncProcess/OnReadData
    non funziona affidabilmente con le pipe kqueue. }
  TZpaqReaderThread = class(TThread)
  private
    FBridge:  TZpaqBridge;
    FProcess: TProcess;
  protected
    procedure Execute; override;
  public
    constructor Create(ABridge: TZpaqBridge; AProcess: TProcess);
  end;

  { TZpaqBridge }
  TZpaqBridge = class
  private
    FProcess:       TProcess;
    FReaderThread:  TZpaqReaderThread;
    FBusy:          Boolean;
    FExePath:       string;
    FIsDataMode:    Boolean;

    // --- Telemetria ---
    FProgFilePerc:   Integer;
    FProgGlobalPerc: Integer;
    FProgLavorati:   Int64;
    FProgTotali:     Int64;
    FProgETA:        Integer;
    FListPhase:      string;
    FProgDecPerc:    Integer;

    FOnComplete: TZpaqCompleteEvent;
    FOnLog:      TZpaqLogEvent;
    FOnProgress: TZpaqProgressEvent;

    FLogBuffer:  TStringList;
    FDataBuffer: TStringList;

    procedure TriggerComplete(Data: PtrInt);
    procedure TriggerProgress(Data: PtrInt);

  public
    constructor Create;
    destructor  Destroy; override;

    // Chiamato dal TZpaqReaderThread: processa una singola riga di output
    procedure ProcessLogLine(const S: string);
    // Chiamato dal TZpaqReaderThread al termine: notifica la GUI
    procedure OnThreadDone(ExitCode: Integer);

    function  LoadDLL(const APath: string = ''): Boolean;
    function  RunCommandAsync(const ACmd: string): Boolean;
    procedure AbortCommand;

    function FlushLogBuffer:  TStringList;
    function FlushDataBuffer: TStringList;
    function ParsePakkaList(AData: TStringList): TArchiveData;

    property DLLPath:    string  read FExePath;
    property Busy:       Boolean read FBusy;
    property IsDataMode: Boolean read FIsDataMode write FIsDataMode;

    property ProgFilePerc:   Integer read FProgFilePerc;
    property ProgGlobalPerc: Integer read FProgGlobalPerc;
    property ProgLavorati:   Int64   read FProgLavorati;
    property ProgTotali:     Int64   read FProgTotali;
    property ProgETA:        Integer read FProgETA;
    property ProgDecPerc:    Integer read FProgDecPerc;
    property ListPhase:      string  read FListPhase;

    property OnComplete: TZpaqCompleteEvent read FOnComplete write FOnComplete;
    property OnLog:      TZpaqLogEvent      read FOnLog      write FOnLog;
    property OnProgress: TZpaqProgressEvent read FOnProgress write FOnProgress;
  end;

var
  ZpaqBridgeMain: TZpaqBridge = nil;
  ZpaqBridge:     TZpaqBridge = nil;

implementation

uses
  StrUtils, uglobals;

{ ============================================================================ }
{ Logging interno su file                                                       }
{ ============================================================================ }

procedure ZpaqDbgLog(const AMsg: string);
var
  LogFile: string;
  F: TextFile;
  T: string;
begin
  if not DebugMode then Exit;   { log disabilitato → esce subito }
  T := FormatDateTime('hh:nn:ss.zzz', Now) + ' [ProcessBridge] ' + AMsg;
  LogFile := ExtractFilePath(ParamStr(0)) + 'catpaq_bridge_debug.txt';
  AssignFile(F, LogFile);
  {$I-}
  if FileExists(LogFile) then Append(F) else Rewrite(F);
  if IOResult = 0 then
  begin
    Writeln(F, T);
    Flush(F);
    CloseFile(F);
  end;
  {$I+}
end;

{ ============================================================================ }
{ Parser command line per macOS/Linux                                           }
{ TProcess.Parameters.Add() vuole un token per chiamata.                       }
{ AddText() NON fa parsing shell su Unix.                                      }
{ Esempio: 'pakka "/path/file.zpaq" -all'                                      }
{   → Add('pakka')  Add('/path/file.zpaq')  Add('-all')                        }
{ ============================================================================ }

procedure SplitCmdToParams(const ACmd: string; Params: TStrings);
var
  i: Integer;
  Token: string;
  InQuote: Boolean;
begin
  Token   := '';
  InQuote := False;
  for i := 1 to Length(ACmd) do
  begin
    if ACmd[i] = '"' then
      InQuote := not InQuote
    else if (ACmd[i] = ' ') and not InQuote then
    begin
      if Token <> '' then
      begin
        Params.Add(Token);
        Token := '';
      end;
    end
    else
      Token := Token + ACmd[i];
  end;
  if Token <> '' then
    Params.Add(Token);
end;

{ ============================================================================ }
{ TZpaqReaderThread                                                             }
{ ============================================================================ }

constructor TZpaqReaderThread.Create(ABridge: TZpaqBridge; AProcess: TProcess);
begin
  inherited Create(True); // CreateSuspended
  FBridge  := ABridge;
  FProcess := AProcess;
  FreeOnTerminate := False;
end;

procedure TZpaqReaderThread.Execute;
const
  BufSize = 4096;
var
  Buffer:    array[0..BufSize - 1] of Byte;
  BytesRead: Integer;
  LineAccum: string;
  i:         Integer;
  Ch:        Char;
  ExitCode:  Integer;
begin
  LineAccum := '';

  repeat
    if Terminated then Break;

    BytesRead := 0;
    try
      if FProcess.Output.NumBytesAvailable > 0 then
        BytesRead := FProcess.Output.Read(Buffer, BufSize)
      else if FProcess.Running then
        Sleep(10)
      else
      begin
        // Processo terminato: svuota gli ultimi byte rimasti nel pipe
        BytesRead := FProcess.Output.Read(Buffer, BufSize);
        if BytesRead = 0 then Break;
      end;
    except
      Break;
    end;

    for i := 0 to BytesRead - 1 do
    begin
      Ch := Char(Buffer[i]);
      if Ch = #10 then
      begin
        if (Length(LineAccum) > 0) and (LineAccum[Length(LineAccum)] = #13) then
          SetLength(LineAccum, Length(LineAccum) - 1);
        if LineAccum <> '' then
          FBridge.ProcessLogLine(LineAccum);
        LineAccum := '';
      end
      else if Ch <> #13 then
        LineAccum := LineAccum + Ch;
    end;
  until False;

  // Ultima riga senza newline
  if LineAccum <> '' then
    FBridge.ProcessLogLine(LineAccum);

  // Attendi exit code
  ExitCode := -1;
  try
    while FProcess.Running do Sleep(5);
    ExitCode := FProcess.ExitStatus;
  except
  end;

  ZpaqDbgLog('Thread lettura terminato. ExitCode=' + IntToStr(ExitCode));
  FBridge.OnThreadDone(ExitCode);
end;

{ ============================================================================ }
{ TZpaqBridge                                                                  }
{ ============================================================================ }

constructor TZpaqBridge.Create;
begin
  inherited Create;
  FProcess      := nil;
  FReaderThread := nil;
  FBusy         := False;
  FIsDataMode   := False;
  FExePath      := '';

  FProgFilePerc   := 0;
  FProgGlobalPerc := 0;
  FProgLavorati   := 0;
  FProgTotali     := 0;
  FProgETA        := 0;
  FListPhase      := '';
  FProgDecPerc    := 0;

  FLogBuffer  := TStringList.Create;
  FDataBuffer := TStringList.Create;

  if ZpaqBridgeMain = nil then
  begin
    ZpaqBridgeMain := Self;
    ZpaqBridge     := Self;
  end;
end;

destructor TZpaqBridge.Destroy;
begin
  if Assigned(FReaderThread) then
  begin
    FReaderThread.Terminate;
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;
  if Assigned(FProcess) then
  begin
    if FProcess.Running then FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;
  FLogBuffer.Free;
  FDataBuffer.Free;
  if ZpaqBridgeMain = Self then ZpaqBridgeMain := nil;
  if ZpaqBridge     = Self then ZpaqBridge     := nil;
  inherited;
end;

function TZpaqBridge.LoadDLL(const APath: string): Boolean;
var
  TestPath: string;
begin
  if APath <> '' then FExePath := APath;

  if FExePath = '' then
  begin
    {$IFDEF WINDOWS}
    TestPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';
    {$ELSE}
    TestPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz';
    {$ENDIF}
    if FileExists(TestPath) then FExePath := TestPath;
  end;

  Result := FileExists(FExePath);
end;

function TZpaqBridge.RunCommandAsync(const ACmd: string): Boolean;
begin
  ZpaqDbgLog('RunCommandAsync: Inizio preparazione processo...');
  Result := False;

  if FBusy then Exit;
  if not LoadDLL then Exit;

  // Cleanup ciclo precedente
  if Assigned(FReaderThread) then
  begin
    FReaderThread.Terminate;
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;
  if Assigned(FProcess) then
  begin
    if FProcess.Running then FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;

  // Reset telemetria
  FProgFilePerc   := 0;
  FProgGlobalPerc := 0;
  FProgLavorati   := 0;
  FProgTotali     := 0;
  FProgETA        := 0;
  FListPhase      := '';
  FProgDecPerc    := 0;

  FProcess := TProcess.Create(nil);
  FProcess.Executable := FExePath;

  {$IFDEF WINDOWS}
  FProcess.Parameters.AddText(ACmd);
  FProcess.Options := [poUsePipes, poNoConsole, poStderrToOutPut];
  {$ELSE}
  SplitCmdToParams(ACmd, FProcess.Parameters);
  FProcess.Options := [poUsePipes, poStderrToOutPut];
  {$ENDIF}

  FBusy := True;

  try
    ZpaqDbgLog('Avvio TProcess con argomenti: ' + ACmd);
    FProcess.Execute;
    ZpaqDbgLog('Processo avviato. PID=' + IntToStr(FProcess.ProcessID));

    // Avvia thread di lettura
    FReaderThread := TZpaqReaderThread.Create(Self, FProcess);
    FReaderThread.Start;

    Result := True;
  except
    on E: Exception do
    begin
      ZpaqDbgLog('ERRORE avvio processo: ' + E.Message);
      FreeAndNil(FProcess);
      FBusy := False;
    end;
  end;
end;

procedure TZpaqBridge.AbortCommand;
begin
  if Assigned(FProcess) and FProcess.Running then
  begin
    ZpaqDbgLog('Richiesto ABORT: Kill del processo...');
    FProcess.Terminate(0);
  end;
end;

procedure TZpaqBridge.OnThreadDone(ExitCode: Integer);
begin
  ZpaqDbgLog('OnThreadDone: ExitCode=' + IntToStr(ExitCode));
  Application.QueueAsyncCall(@TriggerComplete, ExitCode);
end;

procedure TZpaqBridge.ProcessLogLine(const S: string);
var
  Parts: TStringArray;
  CalcoloPerc: Double;
begin
  if Pos('@SPK@DEC@', S) = 1 then
  begin
    Parts := S.Split(['@']);
    if Length(Parts) >= 7 then
    begin
      FListPhase      := 'DEC';
      FProgDecPerc    := StrToIntDef(Trim(Parts[3]), 0);
      FProgLavorati   := StrToInt64Def(Trim(Parts[4]), 0);
      FProgTotali     := StrToInt64Def(Trim(Parts[5]), 0);
      FProgETA        := StrToIntDef(Trim(Parts[6]), 0);
      FProgGlobalPerc := FProgDecPerc;
      Application.QueueAsyncCall(@TriggerProgress, 0);
    end;
  end
  else if Pos('@SPK@PRG@', S) = 1 then
  begin
    Parts := S.Split(['@']);
    if Length(Parts) >= 7 then
    begin
      FListPhase    := 'PRG';
      FProgFilePerc := StrToIntDef(Trim(Parts[3]), 0);
      FProgLavorati := StrToInt64Def(Trim(Parts[4]), 0);
      FProgTotali   := StrToInt64Def(Trim(Parts[5]), 0);
      FProgETA      := StrToIntDef(Trim(Parts[6]), 0);
      if FProgTotali > 0 then
      begin
        CalcoloPerc     := (FProgLavorati / FProgTotali) * 100.0;
        FProgGlobalPerc := 100 - Trunc(CalcoloPerc);
      end
      else
        FProgGlobalPerc := 100;
      Application.QueueAsyncCall(@TriggerProgress, 0);
    end;
  end
  else if Pos('@SPK@EXT@', S) = 1 then
  begin
    { Formato: @SPK@EXT@<perc_globale>@<td>@<ts>@<eta_sec>@<i_percentuale>
      Emesso da print_progress() in modalità detailed (extract/test senza -catpaqmode).
      Parts[0]='' Parts[1]='' Parts[2]='' Parts[3]=perc Parts[4]=td
      Parts[5]=ts Parts[6]=eta Parts[7]=i_perc }
    Parts := S.Split(['@']);
    if Length(Parts) >= 7 then
    begin
      FListPhase      := 'EXT';
      FProgGlobalPerc := StrToIntDef(Trim(Parts[3]), 0);
      FProgLavorati   := StrToInt64Def(Trim(Parts[4]), 0);
      FProgTotali     := StrToInt64Def(Trim(Parts[5]), 0);
      FProgETA        := StrToIntDef(Trim(Parts[6]), 0);
      if Length(Parts) >= 8 then
        FProgFilePerc := StrToIntDef(Trim(Parts[7]), 0)
      else
        FProgFilePerc := 0;
      Application.QueueAsyncCall(@TriggerProgress, 0);
    end;
  end
  else
  begin
    { Filtra tag di telemetria non riconosciuti (es. @DEC@DEC@, future varianti)
      che non devono comparire nel log visibile. Criterio: riga che inizia con '@'
      e contiene almeno un secondo '@' — è certamente un marker interno. }
    if (Length(S) > 1) and (S[1] = '@') and (Pos('@', S, 2) > 1) then
      Exit;  { scarta silenziosamente }
    if FIsDataMode then
      FDataBuffer.Add(S)
    else
      FLogBuffer.Add(S);
  end;
end;

procedure TZpaqBridge.TriggerComplete(Data: PtrInt);
begin
  FBusy := False;
  if Assigned(FOnComplete) then
    FOnComplete(Self, Integer(Data));
end;

procedure TZpaqBridge.TriggerProgress(Data: PtrInt);
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self, FProgGlobalPerc, '');
end;

function TZpaqBridge.FlushLogBuffer: TStringList;
begin
  Result := TStringList.Create;
  Result.Assign(FLogBuffer);
  FLogBuffer.Clear;
end;

function TZpaqBridge.FlushDataBuffer: TStringList;
begin
  Result := TStringList.Create;
  Result.Assign(FDataBuffer);
  FDataBuffer.Clear;
end;

function TZpaqBridge.ParsePakkaList(AData: TStringList): TArchiveData;
var
  CurrentLine: string;
  LineIdx: Integer;
  VerNum: Integer;
  DateLine, SizeLine, NameLine: string;
  SizeVal: Int64;
  bIsDeleted: Boolean;
  LastFileName: string;
  CurrentFileIdx: Integer;
  ActualFileCount: Integer;
  MaxPossibleFiles: Integer;

  function GetNextValidLine(var OutLine: string): Boolean;
  begin
    Result := False;
    while LineIdx < AData.Count do
    begin
      OutLine := AData[LineIdx];
      Inc(LineIdx);
      if Trim(OutLine) = '' then Continue;
      if Pos('$$$NULL-W', OutLine) = 1 then Continue;
      Result := True;
      Exit;
    end;
  end;

begin
  Result.TotalLines := 0;
  SetLength(Result.GlobalVersions, 0);

  MaxPossibleFiles := (AData.Count div 4) + 10;
  SetLength(Result.Files, MaxPossibleFiles);
  ActualFileCount := 0;

  CurrentLine := ''; LastFileName := ''; LineIdx := 0;

  while GetNextValidLine(CurrentLine) do
  begin
    if (Length(CurrentLine) > 0) and (CurrentLine[1] = '|') then
    begin
      SetLength(Result.GlobalVersions, Length(Result.GlobalVersions) + 1);
      with Result.GlobalVersions[High(Result.GlobalVersions)] do
      begin
        DateStr := Trim(Copy(CurrentLine, 2, Length(CurrentLine)));
        Number  := StrToIntDef(ExtractWord(1, DateStr, [' ']), 0);
      end;
      Continue;
    end;

    if (Length(CurrentLine) > 0) and (CurrentLine[1] = '+') then
    begin
      Result.TotalLines := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);
      Continue;
    end;

    if (Length(CurrentLine) > 0) and (CurrentLine[1] = '-') then
    begin
      VerNum := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);

      if not GetNextValidLine(DateLine) then Break;
      bIsDeleted := (Trim(DateLine) = 'D');

      if not GetNextValidLine(SizeLine) then Break;
      SizeLine := StringReplace(Trim(SizeLine), '.', '', [rfReplaceAll]);
      SizeVal  := StrToInt64Def(SizeLine, 0);

      if not GetNextValidLine(NameLine) then Break;

      if NameLine = '?' then
      begin
        if LastFileName = '' then NameLine := 'UNKNOWN_FILE_ERROR'
        else NameLine := LastFileName;
      end
      else LastFileName := NameLine;

      CurrentFileIdx := -1;
      if ActualFileCount > 0 then
        if Result.Files[ActualFileCount - 1].FileName = NameLine then
          CurrentFileIdx := ActualFileCount - 1;

      if CurrentFileIdx = -1 then
      begin
        CurrentFileIdx := ActualFileCount;
        Inc(ActualFileCount);
        Result.Files[CurrentFileIdx].FileName := NameLine;
        SetLength(Result.Files[CurrentFileIdx].Versions, 0);
      end;

      with Result.Files[CurrentFileIdx] do
      begin
        SetLength(Versions, Length(Versions) + 1);
        with Versions[High(Versions)] do
        begin
          Version   := VerNum;
          IsDeleted := bIsDeleted;
          Size      := SizeVal;
          if bIsDeleted then DateStr := 'DELETED' else DateStr := DateLine;
        end;
      end;

      Continue;
    end;
  end;

  SetLength(Result.Files, ActualFileCount);
end;

end.
