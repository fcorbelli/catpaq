unit uzpaqbridge;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, AsyncProcess, Process, Forms, ucatpaqtypes;

type
  TZpaqCompleteEvent = procedure(Sender: TObject; ExitCode: Integer) of object;
  TZpaqLogEvent = procedure(Sender: TObject; const ALine: string) of object;
  TZpaqProgressEvent = procedure(Sender: TObject; Percent: Integer; const AMsg: string) of object;

  { TZpaqBridge }
  TZpaqBridge = class
  private
    FProcess: TAsyncProcess;
    FBusy: Boolean;
    FExePath: string;
    FIsDataMode: Boolean;

    // --- Telemetria in tempo reale ---
    FProgFilePerc: Integer;
    FProgGlobalPerc: Integer;
    FProgLavorati: Int64;
    FProgTotali: Int64;
    FProgETA: Integer;

    // --- Fase caricamento LIST ---
    // 'DEC' = decompressione indice (barra 0→100)
    // 'PRG' = enumerazione file (barra 100→0)
    FListPhase: string;
    FProgDecPerc: Integer;

    FOnComplete: TZpaqCompleteEvent;
    FOnLog: TZpaqLogEvent;
    FOnProgress: TZpaqProgressEvent;

    FOutputBuffer: string;
    FLogBuffer: TStringList;
    FDataBuffer: TStringList;

    procedure ProcessReadData(Sender: TObject);
    procedure ProcessTerminate(Sender: TObject);

    procedure TriggerComplete(Data: PtrInt);
    procedure TriggerProgress(Data: PtrInt);

    procedure ProcessLogLine(const S: string);
  public
    constructor Create;
    destructor Destroy; override;

    function LoadDLL(const APath: string = ''): Boolean;
    function RunCommandAsync(const ACmd: string): Boolean;
    procedure AbortCommand; // Nuova funzione per interrompere brutalmente

    function FlushLogBuffer: TStringList;
    function FlushDataBuffer: TStringList;
    function ParsePakkaList(AData: TStringList): TArchiveData;

    property DLLPath: string read FExePath;
    property Busy: Boolean read FBusy;
    property IsDataMode: Boolean read FIsDataMode write FIsDataMode;

    // Proprietà esposte per leggere la telemetria da TfrmMain
    property ProgFilePerc: Integer read FProgFilePerc;
    property ProgGlobalPerc: Integer read FProgGlobalPerc;
    property ProgLavorati: Int64 read FProgLavorati;
    property ProgTotali: Int64 read FProgTotali;
    property ProgETA: Integer read FProgETA;
    property ProgDecPerc: Integer read FProgDecPerc;
    property ListPhase: string read FListPhase;

    property OnComplete: TZpaqCompleteEvent read FOnComplete write FOnComplete;
    property OnLog: TZpaqLogEvent read FOnLog write FOnLog;
    property OnProgress: TZpaqProgressEvent read FOnProgress write FOnProgress;
  end;

var
  ZpaqBridgeMain: TZpaqBridge = nil;
  ZpaqBridge: TZpaqBridge = nil;

implementation

uses
  StrUtils;

{ ============================================================================ }
{ Funzione di Logging Interna                                                  }
{ ============================================================================ }

procedure ZpaqDbgLog(const AMsg: string);
var
  LogFile: string;
  F: TextFile;
  T: string;
begin
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
{ TZpaqBridge (Versione TAsyncProcess + Telemetria Catpaq)                     }
{ ============================================================================ }

constructor TZpaqBridge.Create;
begin
  inherited Create;
  FProcess := nil;
  FBusy := False;
  FIsDataMode := False;
  FExePath := '';

  // Inizializzazione Telemetria
  FProgFilePerc := 0;
  FProgGlobalPerc := 0;
  FProgLavorati := 0;
  FProgTotali := 0;
  FProgETA := 0;
  FListPhase := '';
  FProgDecPerc := 0;

  FLogBuffer := TStringList.Create;
  FDataBuffer := TStringList.Create;

  if ZpaqBridgeMain = nil then
  begin
    ZpaqBridgeMain := Self;
    ZpaqBridge := Self;
  end;
end;

destructor TZpaqBridge.Destroy;
begin
  if Assigned(FProcess) then
  begin
    if FProcess.Running then
      FProcess.Terminate(0);
    FProcess.Free;
  end;

  FLogBuffer.Free;
  FDataBuffer.Free;

  if ZpaqBridgeMain = Self then ZpaqBridgeMain := nil;
  if ZpaqBridge = Self then ZpaqBridge := nil;

  inherited;
end;

function TZpaqBridge.LoadDLL(const APath: string): Boolean;
var
  TestPath: string;
begin
  // Questa funzione si chiama ancora LoadDLL per compatibilità, ma cerca l'eseguibile!
  if APath <> '' then FExePath := APath;

  if FExePath = '' then
  begin
    {$IFDEF WINDOWS}
    TestPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';
    {$ENDIF}
    {$IFDEF LINUX}
    TestPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz';
    {$ENDIF}
    {$IFDEF DARWIN}
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

  // Pulizia processo precedente
  if Assigned(FProcess) then
  begin
    if FProcess.Running then FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;

  FOutputBuffer := '';

  // Reset variabili telemetria
  FProgFilePerc := 0;
  FProgGlobalPerc := 0;
  FProgLavorati := 0;
  FProgTotali := 0;
  FProgETA := 0;
  FListPhase := '';
  FProgDecPerc := 0;

  // Creazione nuovo processo isolato
  FProcess := TAsyncProcess.Create(nil);
  FProcess.Executable := FExePath;
  FProcess.Parameters.AddText(ACmd);

  // Opzioni critiche per intercettare lo standard output in modo invisibile
  FProcess.Options := [poUsePipes, poNoConsole, poStderrToOutPut];

  FProcess.OnReadData := @ProcessReadData;
  FProcess.OnTerminate := @ProcessTerminate;

  FBusy := True;

  try
    ZpaqDbgLog('Avvio TAsyncProcess con argomenti: ' + ACmd);
    FProcess.Execute;
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
    FProcess.Terminate(0); // L'OS interviene e uccide istantaneamente l'exe
    // Questo causerà lo scatto immediato di OnTerminate
  end;
end;

procedure TZpaqBridge.ProcessLogLine(const S: string);
var
  Parts: TStringArray;
  CalcoloPerc: Double;
begin
  // --- FASE 1: decompressione indice (@SPK@DEC@perc@lavorati@totali@eta) ---
  if Pos('@SPK@DEC@', S) = 1 then
  begin
    Parts := S.Split(['@']);
    // [0='', 1='SPK', 2='DEC', 3='Perc', 4='Lavorati', 5='Totali', 6='ETA']
    if Length(Parts) >= 7 then
    begin
      FListPhase      := 'DEC';
      FProgDecPerc    := StrToIntDef(Trim(Parts[3]), 0);
      FProgLavorati   := StrToInt64Def(Trim(Parts[4]), 0);
      FProgTotali     := StrToInt64Def(Trim(Parts[5]), 0);
      FProgETA        := StrToIntDef(Trim(Parts[6]), 0);
      FProgGlobalPerc := FProgDecPerc;

      ZpaqDbgLog('SPK@DEC perc=' + IntToStr(FProgDecPerc) +
                 ' lav=' + IntToStr(FProgLavorati) +
                 ' tot=' + IntToStr(FProgTotali) +
                 ' eta=' + IntToStr(FProgETA));

      Application.QueueAsyncCall(@TriggerProgress, 0);
    end;
  end

  // --- FASE 2: enumerazione file (@SPK@PRG@perc@lavorati@totali@eta) ---
  else if Pos('@SPK@PRG@', S) = 1 then
  begin
    Parts := S.Split(['@']);
    // [0='', 1='SPK', 2='PRG', 3='Perc_File', 4='Lavorati', 5='Totali', 6='ETA']
    if Length(Parts) >= 7 then
    begin
      FListPhase    := 'PRG';
      FProgFilePerc := StrToIntDef(Trim(Parts[3]), 0);
      FProgLavorati := StrToInt64Def(Trim(Parts[4]), 0);
      FProgTotali   := StrToInt64Def(Trim(Parts[5]), 0);
      FProgETA      := StrToIntDef(Trim(Parts[6]), 0);

      // PRG: la barra scende da 100 verso 0 man mano che i file vengono processati
      if FProgTotali > 0 then
      begin
        CalcoloPerc := (FProgLavorati / FProgTotali) * 100.0;
        FProgGlobalPerc := 100 - Trunc(CalcoloPerc);
      end
      else
        FProgGlobalPerc := 100;

      ZpaqDbgLog('SPK@PRG perc=' + IntToStr(FProgFilePerc) +
                 ' global=' + IntToStr(FProgGlobalPerc) +
                 ' lav=' + IntToStr(FProgLavorati) +
                 ' tot=' + IntToStr(FProgTotali) +
                 ' eta=' + IntToStr(FProgETA));

      Application.QueueAsyncCall(@TriggerProgress, 0);
    end;
  end

  else
  begin
    // Tutto il resto va nei buffer dati/log normali
    if FIsDataMode then
      FDataBuffer.Add(S)
    else
      FLogBuffer.Add(S);
  end;
end;

procedure TZpaqBridge.ProcessReadData(Sender: TObject);
var
  Buffer: array[0..2047] of Char;
  BytesRead, i: Integer;
  LineStr: string;
begin
  if not Assigned(FProcess) then Exit;

  // Leggi tutto ciò che c'è nel pipe del processo C++
  while FProcess.Output.NumBytesAvailable > 0 do
  begin
    BytesRead := FProcess.Output.Read(Buffer, SizeOf(Buffer));
    if BytesRead > 0 then
      FOutputBuffer := FOutputBuffer + Copy(Buffer, 0, BytesRead);
  end;

  // Spezza il buffer in righe e mandale al parser
  while Length(FOutputBuffer) > 0 do
  begin
    i := Pos(#10, FOutputBuffer);
    if i = 0 then i := Pos(#13, FOutputBuffer);

    if i > 0 then
    begin
      LineStr := Copy(FOutputBuffer, 1, i - 1);
      Delete(FOutputBuffer, 1, i);

      // Elimina eventuali \r o \n residui successivi
      while (Length(FOutputBuffer) > 0) and (FOutputBuffer[1] in [#10, #13]) do
        Delete(FOutputBuffer, 1, 1);

      if LineStr <> '' then ProcessLogLine(LineStr);
    end
    else
      Break; // La riga non è ancora completa, aspettiamo
  end;
end;

procedure TZpaqBridge.ProcessTerminate(Sender: TObject);
var
  FinalExitCode: PtrInt;
begin
  ZpaqDbgLog('Processo terminato. Eseguo lettura finale dei buffer.');

  // Svuota le ultimissime righe rimaste
  ProcessReadData(Sender);
  if FOutputBuffer <> '' then
  begin
    ProcessLogLine(FOutputBuffer);
    FOutputBuffer := '';
  end;

  FinalExitCode := FProcess.ExitStatus;

  ZpaqDbgLog('ExitCode processo: ' + IntToStr(FinalExitCode));

  // Deleghiamo alla GUI per evitare problemi di concorrenza
  Application.QueueAsyncCall(@TriggerComplete, FinalExitCode);
end;

procedure TZpaqBridge.TriggerComplete(Data: PtrInt);
begin
  FBusy := False;
  if Assigned(FOnComplete) then
    FOnComplete(Self, Integer(Data));
end;

procedure TZpaqBridge.TriggerProgress(Data: PtrInt);
begin
  // Notifichiamo il form che i dati della telemetria sono cambiati
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

{ --- Parsing --- }

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

  // Ottimizzazioni per la memoria
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

  // 1. PRE-ALLOCAZIONE: evita la frammentazione della memoria
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
         Number := StrToIntDef(ExtractWord(1, DateStr, [' ']), 0);
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
      SizeVal := StrToInt64Def(SizeLine, 0);

      if not GetNextValidLine(NameLine) then Break;

      if NameLine = '?' then
      begin
        if LastFileName = '' then NameLine := 'UNKNOWN_FILE_ERROR'
        else NameLine := LastFileName;
      end
      else LastFileName := NameLine;

      // 2. MAGIA O(1): Il comando pakka restituisce le versioni vicine!
      // Basta guardare solo ed esclusivamente l'ultimo file aggiunto.
      CurrentFileIdx := -1;
      if ActualFileCount > 0 then
      begin
        if Result.Files[ActualFileCount - 1].FileName = NameLine then
          CurrentFileIdx := ActualFileCount - 1;
      end;

      // Se non è uguale all'ultimo, è un file nuovo
      if CurrentFileIdx = -1 then
      begin
        CurrentFileIdx := ActualFileCount;
        Inc(ActualFileCount); // Usiamo l'array pre-allocato, velocità istantanea
        Result.Files[CurrentFileIdx].FileName := NameLine;
        SetLength(Result.Files[CurrentFileIdx].Versions, 0);
      end;

      // 3. Inserimento della versione per questo file
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

  // 4. Fine: Riduciamo l'array scartando lo spazio pre-allocato non usato
  SetLength(Result.Files, ActualFileCount);
end;
{
function TZpaqBridge.ParsePakkaList(AData: TStringList): TArchiveData;
var
  CleanData: TStringList;
  CurrentLine: string;
  LineIdx, i: Integer;
  VerNum: Integer;
  DateLine, SizeLine, NameLine: string;
  SizeVal: Int64;
  IsDeleted: Boolean;
  LastFileName: string;
  CurrentFileIdx: Integer;

  function GetNextValidLine(var OutLine: string): Boolean;
  begin
    Result := False;
    while LineIdx < CleanData.Count do
    begin
      OutLine := CleanData[LineIdx];
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
  SetLength(Result.Files, 0);

  CleanData := TStringList.Create;
  try
    CleanData.Text := AData.Text;

    CurrentLine  := ''; DateLine := ''; SizeLine := '';
    NameLine     := ''; LastFileName := ''; LineIdx := 0;

    while GetNextValidLine(CurrentLine) do
    begin
      if (Length(CurrentLine) > 1) and (CurrentLine[1] = '|') then
      begin
        SetLength(Result.GlobalVersions, Length(Result.GlobalVersions) + 1);
        with Result.GlobalVersions[High(Result.GlobalVersions)] do
        begin
          DateStr := Trim(Copy(CurrentLine, 2, Length(CurrentLine)));
          Number  := StrToIntDef(ExtractWord(1, DateStr, [' ']), 0);
        end;
        Continue;
      end;

      if (Length(CurrentLine) > 1) and (CurrentLine[1] = '+') then
      begin
        Result.TotalLines := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);
        Continue;
      end;

      if (Length(CurrentLine) > 1) and (CurrentLine[1] = '-') and (CurrentLine[2] in ['0'..'9']) then
      begin
        VerNum := StrToIntDef(Copy(CurrentLine, 2, Length(CurrentLine)), 0);

        if not GetNextValidLine(DateLine) then Break;
        IsDeleted := (Trim(DateLine) = 'D');

        if not GetNextValidLine(SizeLine) then Break;
        SizeLine := StringReplace(Trim(SizeLine), '.', '', [rfReplaceAll]);
        SizeVal  := StrToInt64Def(SizeLine, 0);

        if not GetNextValidLine(NameLine) then Break;

        if NameLine = '?' then
        begin
          if LastFileName = '' then NameLine := 'UNKNOWN_FILE_ERROR'
          else NameLine := LastFileName;
        end
        else
          LastFileName := NameLine;

        CurrentFileIdx := -1;
        for i := High(Result.Files) downto 0 do
        begin
          if Result.Files[i].FileName = NameLine then
          begin
            CurrentFileIdx := i;
            Break;
          end;
        end;

        if CurrentFileIdx = -1 then
        begin
          SetLength(Result.Files, Length(Result.Files) + 1);
          CurrentFileIdx := High(Result.Files);
          Result.Files[CurrentFileIdx].FileName := NameLine;
          SetLength(Result.Files[CurrentFileIdx].Versions, 0);
        end;

        with Result.Files[CurrentFileIdx] do
        begin
          SetLength(Versions, Length(Versions) + 1);
          with Versions[High(Versions)] do
          begin
            Version   := VerNum;
            IsDeleted := IsDeleted;
            Size      := SizeVal;
            if IsDeleted then DateStr := 'DELETED'
            else DateStr := DateLine;
          end;
        end;

        Continue;
      end;
    end;
  finally
    CleanData.Free;
  end;
end;
 }
end.
