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

    function  LoadExternal(const APath: string = ''): Boolean;
    function  RunCommandAsync(const ACmd: string): Boolean;
    procedure AbortCommand;

    function FlushLogBuffer:  TStringList;
    function FlushDataBuffer: TStringList;
    function ParsePakkaList(AData: TStringList): TArchiveData;
    function ParsePakkaListFromFile(const ATempFile: string): TArchiveData;
    function GetTempListingPath: string;

    property ExternalPath:    string  read FExePath;
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

{ Parser command line per macOS/Linux: split "cmd arg1 arg2" → TStrings }
procedure SplitCmdToParams(const ACmd: string; Params: TStrings);

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

function TZpaqBridge.LoadExternal(const APath: string): Boolean;
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
  if not LoadExternal then Exit;

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
  DbgFile: string;
  F: TextFile;
begin
  { === DEBUG LISTING PROGRESS: scrive ogni riga grezza su file ===
    Rimuovere questo blocco quando il problema e' risolto. }
  DbgFile := ExtractFilePath(ParamStr(0)) + 'catpaq_listing_debug.txt';
  AssignFile(F, DbgFile);
  {$I-}
  if FileExists(DbgFile) then Append(F) else Rewrite(F);
  if IOResult = 0 then
  begin
    Writeln(F, FormatDateTime('hh:nn:ss.zzz', Now) +
              ' IsDataMode=' + BoolToStr(FIsDataMode, 'T', 'F') +
              ' [' + S + ']');
    Flush(F);
    CloseFile(F);
  end;
  {$I+}
  { === FINE DEBUG === }

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

    { Intercetta righe "Scan NNN% ETA ..." emesse da zpaqfranz durante il listing.
      Aggiorna la telemetria e triggera OnProgress, così la GUI può aggiornare
      la barra di progresso senza bisogno di parsing nel timer.
      La riga viene comunque accodata nel LogBuffer per apparire nel MemoLog. }
    if (Length(S) >= 8) and (Copy(S, 1, 5) = 'Scan ') then
    begin
      { Estrae la percentuale: "Scan 099% ..." o "Scan  99% ..." }
      FProgGlobalPerc := StrToIntDef(Trim(Copy(S, 6, 3)), FProgGlobalPerc);
      FListPhase      := 'SCAN';
      Application.QueueAsyncCall(@TriggerProgress, 0);
      { Mette la riga nel LogBuffer (non DataBuffer) così il timer la mostra }
      FLogBuffer.Add(S);
      Exit;
    end;

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
      { Filtra marker '!N' e righe progresso 'W NNN%' }
      if (Length(OutLine) > 0) and (OutLine[1] = '!') then Continue;
      if (Length(OutLine) >= 6) and (Copy(OutLine, 1, 2) = 'W ') and
         (OutLine[6] = '%') then Continue;
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

      { Validazione: skip entry con DateLine corrotta (troppo lunga) }
      if (not bIsDeleted) and (Length(Trim(DateLine)) > 30) then
        Continue;

      if not GetNextValidLine(SizeLine) then Break;
      SizeLine := StringReplace(Trim(SizeLine), '.', '', [rfReplaceAll]);
      SizeVal  := StrToInt64Def(SizeLine, 0);

      { Validazione: skip entry con SizeLine non numerica }
      if (SizeLine <> '0') and (SizeVal = 0) and (Length(SizeLine) > 0) then
        Continue;

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

{ ============================================================================ }
{ FileSizeUtf8: helper cross-platform per dimensione file                      }
{ ============================================================================ }

function FileSizeUtf8(const AFileName: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    SysUtils.FindClose(SR);
  end;
end;

{ ============================================================================ }
{ GetTempListingPath                                                           }
{ Genera un path unico per il file temporaneo di listing, cross-platform.      }
{ Il file NON viene creato qui — sarà zpaqfranz stesso a scriverlo via -out.   }
{ ============================================================================ }

function TZpaqBridge.GetTempListingPath: string;
var
  TempDir: string;
begin
  TempDir := GetTempDir(False);
  if TempDir = '' then
    TempDir := ExtractFilePath(ParamStr(0));
  TempDir := IncludeTrailingPathDelimiter(TempDir);
  Result := TempDir + 'catpaq_listing_' +
            FormatDateTime('yyyymmdd_hhnnss_zzz', Now) + '.tmp';
  ZpaqDbgLog('GetTempListingPath: ' + Result);
end;

{ ============================================================================ }
{ ParsePakkaListFromFile                                                        }
{ Parsing riga per riga da file su disco — nessun TStringList in RAM.          }
{ Gestisce archivi con milioni di righe senza esaurire la memoria.             }
{ I file temporanei NON vengono cancellati (debug).                            }
{ ============================================================================ }

function TZpaqBridge.ParsePakkaListFromFile(const ATempFile: string): TArchiveData;
var
  F: TextFile;
  RawLine, CurrentLine: string;
  VerNum: Integer;
  DateLine, SizeLine, NameLine: string;
  SizeVal: Int64;
  bIsDeleted: Boolean;
  LastFileName: string;
  CurrentFileIdx: Integer;
  ActualFileCount: Integer;
  LinesRead, DataLines: Integer;
  FileSizeBytes: Int64;
  LogInterval: Integer;
  CapacityFiles: Integer;

  { Buffer di righe pendenti per il parsing a gruppi di 4 }
  PendingLines: array of string;
  PendingCount: Integer;

  procedure AddPendingLine(const ALine: string);
  begin
    if PendingCount >= Length(PendingLines) then
      SetLength(PendingLines, PendingCount + 1024);
    PendingLines[PendingCount] := ALine;
    Inc(PendingCount);
  end;

  function GetNextValidLine(var OutLine: string): Boolean;
  begin
    Result := False;
    { Prima consuma le righe dal buffer pendente }
    while PendingCount > 0 do
    begin
      OutLine := PendingLines[0];
      { Shift array }
      Move(PendingLines[1], PendingLines[0],
           (PendingCount - 1) * SizeOf(string));
      { Non liberare la stringa spostata: Move ha spostato il puntatore }
      FillChar(PendingLines[PendingCount - 1], SizeOf(string), 0);
      Dec(PendingCount);
      if Trim(OutLine) = '' then Continue;
      if Pos('$$$NULL-W', OutLine) = 1 then Continue;
      Result := True;
      Exit;
    end;
    { Poi legge dal file }
    while not EOF(F) do
    begin
      ReadLn(F, OutLine);
      Inc(LinesRead);
      { Log periodico per debug }
      if (LinesRead mod LogInterval) = 0 then
        ZpaqDbgLog('ParseFromFile: read ' + IntToStr(LinesRead) + ' lines so far...');
      if Trim(OutLine) = '' then Continue;
      if Pos('$$$NULL-W', OutLine) = 1 then Continue;
      { Filtra righe '!N' che zpaqfranz emette come marker nel file -out }
      if (Length(OutLine) > 0) and (OutLine[1] = '!') then Continue;
      { Filtra righe @SPK@ di telemetria catpaqmode }
      if Pos('@SPK@', OutLine) = 1 then Continue;
      { Filtra righe di progresso 'W NNN%' che possono finire nel file -out }
      if (Length(OutLine) >= 6) and (Copy(OutLine, 1, 2) = 'W ') and
         (OutLine[6] = '%') then Continue;
      { Filtra timestamp zpaqfranz (DD/MM/YYYY HH:NN:SS prefisso di righe W) }
      if (Length(OutLine) > 20) and (Copy(OutLine, 3, 1) = '/') and
         (Copy(OutLine, 6, 1) = '/') and (Pos(' W ', OutLine) > 10) then Continue;
      Result := True;
      Exit;
    end;
  end;

begin
  Result.TotalLines := 0;
  SetLength(Result.GlobalVersions, 0);
  SetLength(Result.Files, 0);
  LinesRead := 0;
  DataLines := 0;
  ActualFileCount := 0;
  LastFileName := '';
  PendingCount := 0;
  SetLength(PendingLines, 0);
  CapacityFiles := 10000;
  LogInterval := 100000;

  ZpaqDbgLog('ParsePakkaListFromFile: START file=' + ATempFile);

  if not FileExists(ATempFile) then
  begin
    ZpaqDbgLog('ParsePakkaListFromFile: file not found!');
    Exit;
  end;

  { Stima dimensione per pre-allocazione }
  FileSizeBytes := FileSizeUtf8(ATempFile);
  ZpaqDbgLog('ParsePakkaListFromFile: file size=' + IntToStr(FileSizeBytes) + ' bytes');
  if FileSizeBytes > 0 then
  begin
    { Stima ~80 bytes per riga, 4 righe per file entry }
    CapacityFiles := (FileSizeBytes div 320) + 100;
    if CapacityFiles > 50000000 then CapacityFiles := 50000000; { cap ragionevole }
  end;
  SetLength(Result.Files, CapacityFiles);
  ZpaqDbgLog('ParsePakkaListFromFile: pre-allocated ' + IntToStr(CapacityFiles) + ' file slots');

  AssignFile(F, ATempFile);
  {$I-}
  Reset(F);
  if IOResult <> 0 then
  begin
    ZpaqDbgLog('ParsePakkaListFromFile: cannot open file!');
    Exit;
  end;
  {$I+}

  try
    CurrentLine := '';

    while GetNextValidLine(CurrentLine) do
    begin
      { Strip CR se presente }
      if (Length(CurrentLine) > 0) and (CurrentLine[Length(CurrentLine)] = #13) then
        SetLength(CurrentLine, Length(CurrentLine) - 1);

      { Versione globale: riga che inizia con '|' }
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

      { Conteggio righe attese: riga che inizia con '+' }
      if (Length(CurrentLine) > 0) and (CurrentLine[1] = '+') then
      begin
        Result.TotalLines := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);
        ZpaqDbgLog('ParsePakkaListFromFile: TotalLines hint = ' + IntToStr(Result.TotalLines));
        Continue;
      end;

      { Entry file: riga che inizia con '-' }
      if (Length(CurrentLine) > 0) and (CurrentLine[1] = '-') then
      begin
        VerNum := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);

        if not GetNextValidLine(DateLine) then Break;
        bIsDeleted := (Trim(DateLine) = 'D');

        { Validazione robusta: la riga data deve essere corta (max ~30 char)
          e assomigliare a una data "DD/MM/YYYY HH:NN:SS" o "D" (deleted).
          Se è troppo lunga o non valida, l'entry è corrotta — skip e resync.
          Questo gestisce il caso in cui zpaqfranz con -out produce righe
          concatenate (bug osservato sul primo record di archivi grandi). }
        if (not bIsDeleted) and (Length(Trim(DateLine)) > 30) then
        begin
          ZpaqDbgLog('ParsePakkaListFromFile: CORRUPT entry skipped — DateLine too long (' +
                     IntToStr(Length(DateLine)) + ' chars): [' +
                     Copy(DateLine, 1, 60) + '...]');
          { Non possiamo fare resync pulito — saltiamo e speriamo che la
            prossima riga '-N' riporti il parser in carreggiata }
          Continue;
        end;

        if not GetNextValidLine(SizeLine) then Break;
        SizeLine := StringReplace(Trim(SizeLine), '.', '', [rfReplaceAll]);
        SizeVal  := StrToInt64Def(SizeLine, 0);

        { Validazione: se SizeLine non è numerica dopo il cleanup, entry corrotta }
        if (SizeLine <> '0') and (SizeVal = 0) and (Length(SizeLine) > 0) then
        begin
          ZpaqDbgLog('ParsePakkaListFromFile: CORRUPT entry skipped — SizeLine not numeric: [' +
                     Copy(SizeLine, 1, 60) + ']');
          Continue;
        end;

        if not GetNextValidLine(NameLine) then Break;

        if NameLine = '?' then
        begin
          if LastFileName = '' then NameLine := 'UNKNOWN_FILE_ERROR'
          else NameLine := LastFileName;
        end
        else LastFileName := NameLine;

        Inc(DataLines);

        CurrentFileIdx := -1;
        if ActualFileCount > 0 then
          if Result.Files[ActualFileCount - 1].FileName = NameLine then
            CurrentFileIdx := ActualFileCount - 1;

        if CurrentFileIdx = -1 then
        begin
          CurrentFileIdx := ActualFileCount;
          Inc(ActualFileCount);
          { Espandi array se necessario }
          if ActualFileCount > Length(Result.Files) then
            SetLength(Result.Files, ActualFileCount + 10000);
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

      { Righe Scan/telemetria: ignorate silenziosamente }
      if (Length(CurrentLine) >= 5) and (Copy(CurrentLine, 1, 5) = 'Scan ') then
        Continue;
      if (Length(CurrentLine) > 1) and (CurrentLine[1] = '@') and
         (Pos('@', CurrentLine, 2) > 1) then
        Continue;
    end;

  finally
    CloseFile(F);
    SetLength(PendingLines, 0);
  end;

  SetLength(Result.Files, ActualFileCount);

  ZpaqDbgLog('ParsePakkaListFromFile: END - LinesRead=' + IntToStr(LinesRead) +
             ' DataLines=' + IntToStr(DataLines) +
             ' GlobalVersions=' + IntToStr(Length(Result.GlobalVersions)) +
             ' Files=' + IntToStr(ActualFileCount));
end;

end.

