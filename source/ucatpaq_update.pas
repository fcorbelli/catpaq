unit ucatpaq_update;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, ucatpaq_sha256;

type
  TVersionInfo = record
    BuildNumber: Integer;
    DateTime:    string;
    SHA256Hash:  string;
    FileSize:    Int64;
  end;

  TUpdateInfo = record
    CatpaqInfo: TVersionInfo;
    EXEInfo:    TVersionInfo;  // zpaqfranz.exe / zpaqfranz
    DLLInfo:    TVersionInfo;  // zpaqfranz.dll (Windows only)
    Valid:      Boolean;
  end;

  TUpdateLogEvent      = procedure(const AMsg: string) of object;
  TUpdateProgressEvent = procedure(Downloaded, Total: Int64) of object;

  { TUpdateChecker }
  TUpdateChecker = class
  private
    FVersionURL: string;
    FBaseURL:    string;
    FTempDir:    string;
    FLastError:        string;
    FOnLog:            TUpdateLogEvent;
    FOnProgress:       TUpdateProgressEvent;
    FDownloadTotal:    Int64;
    FDownloadReported: Int64;

    procedure HandleDataReceived(Sender: TObject; const ContentLength, CurrentPos: Int64);
    procedure Log(const AMsg: string);
    function  ParseVersionFile(const Content: string): TUpdateInfo;
    function  ValidateVersionFile(const Content: string): Boolean;
    function  DownloadFile(const URL: string; var Content: TBytes): Boolean;
  public
    constructor Create;

    function CheckForUpdate(CurrentBuild: Integer; out UpdateInfo: TUpdateInfo): Boolean;
    function DownloadUpdate(const UpdateInfo: TUpdateInfo; out CatpaqPath, EXEPath, DLLPath: string): Boolean;
    function ApplyUpdate(const NewCatpaqPath, NewEXEPath, NewDLLPath: string): Boolean;
    function DownloadFile_Public(out EXEData: TBytes): Boolean;
    function DownloadDLLFile(out DLLData: TBytes): Boolean;
    function CalculateSHA256FromBytes_Public(const Data: TBytes): string;

    property LastError:   string               read FLastError;
    property OnLog:       TUpdateLogEvent      read FOnLog      write FOnLog;
    property OnProgress:  TUpdateProgressEvent read FOnProgress write FOnProgress;
  end;

implementation

uses
  {$IFDEF WINDOWS}
  Windows, ShellApi,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  FileUtil;

procedure TUpdateChecker.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then FOnLog(AMsg);
end;

constructor TUpdateChecker.Create;
begin
  {$IFDEF WINDOWS}
  FVersionURL := 'http://www.francocorbelli.it/catpaq/latest/win64/version.txt';
  FBaseURL    := 'http://www.francocorbelli.it/catpaq/latest/win64/';
  {$ELSE}
  {$IFDEF DARWIN}
  FVersionURL := 'http://www.francocorbelli.it/catpaq/latest/macos/version.txt';
  FBaseURL    := 'http://www.francocorbelli.it/catpaq/latest/macos/';
  {$ELSE}
  FVersionURL := 'http://www.francocorbelli.it/catpaq/latest/linux64/version.txt';
  FBaseURL    := 'http://www.francocorbelli.it/catpaq/latest/linux64/';
  {$ENDIF}
  {$ENDIF}
  FTempDir    := GetTempDir(False) + 'catpaq_update' + PathDelim;
  FLastError         := '';
  FOnLog             := nil;
  FOnProgress        := nil;
  FDownloadTotal     := 0;
  FDownloadReported  := 0;
  ForceDirectories(FTempDir);
  Log('TUpdateChecker.Create: TempDir=' + FTempDir);
end;

procedure TUpdateChecker.HandleDataReceived(Sender: TObject;
  const ContentLength, CurrentPos: Int64);
begin
  if FDownloadTotal = 0 then FDownloadTotal := ContentLength;
  if Assigned(FOnProgress) and (CurrentPos - FDownloadReported >= 32768) then
  begin
    FDownloadReported := CurrentPos;
    FOnProgress(CurrentPos, FDownloadTotal);
  end;
end;

function TUpdateChecker.DownloadFile(const URL: string; var Content: TBytes): Boolean;
var
  HTTP:       TFPHTTPClient;
  Stream:     TBytesStream;
  StatusCode: Integer;
begin
  Result     := False;
  FLastError := '';
  SetLength(Content, 0);
  FDownloadTotal    := 0;
  FDownloadReported := 0;
  if Assigned(FOnProgress) then FOnProgress(0, 0);
  Log('DownloadFile: URL=' + URL);
  HTTP   := TFPHTTPClient.Create(nil);
  Stream := TBytesStream.Create;
  try
    try
      HTTP.AllowRedirect  := True;
      HTTP.IOTimeout      := 20000;
      HTTP.OnDataReceived := @HandleDataReceived;
      HTTP.Get(URL, Stream);
      StatusCode := HTTP.ResponseStatusCode;
      Log('DownloadFile: HTTP status=' + IntToStr(StatusCode) +
          ' bytes=' + IntToStr(Stream.Size));
      if StatusCode <> 200 then
      begin
        FLastError := 'HTTP ' + IntToStr(StatusCode) +
                      ' ' + HTTP.ResponseStatusText + ' for URL: ' + URL;
        Log('DownloadFile: FAILED - ' + FLastError);
        if Assigned(FOnProgress) then FOnProgress(0, 0);
        Exit;
      end;
      if Stream.Size = 0 then
      begin
        FLastError := 'Empty response (0 bytes) for URL: ' + URL;
        Log('DownloadFile: FAILED - ' + FLastError);
        if Assigned(FOnProgress) then FOnProgress(0, 0);
        Exit;
      end;
      Content := Stream.Bytes;
      SetLength(Content, Stream.Size);
      Result := True;
      if Assigned(FOnProgress) then FOnProgress(Stream.Size, Stream.Size);
      Log('DownloadFile: OK (' + IntToStr(Length(Content)) + ' bytes)');
    except
      on E: Exception do
      begin
        FLastError := E.ClassName + ': ' + E.Message + ' (URL: ' + URL + ')';
        Log('DownloadFile: EXCEPTION - ' + FLastError);
        if Assigned(FOnProgress) then FOnProgress(0, 0);
      end;
    end;
  finally
    Stream.Free;
    HTTP.Free;
  end;
end;

function TUpdateChecker.ValidateVersionFile(const Content: string): Boolean;
var
  Lines: TStringList;
  i: Integer;
  c: Char;
const
  MaxLines = 11;
  MinLines = 9;
  MaxSize  = 1024;
  AllowedChars = ['0'..'9', 'a'..'f', 'A'..'F', '/', ':', ' ', #13, #10];
begin
  Result := False;
  if Length(Content) > MaxSize then
  begin
    FLastError := 'ValidateVersionFile: content too long (' +
                  IntToStr(Length(Content)) + ' > ' + IntToStr(MaxSize) + ')';
    Log(FLastError); Exit;
  end;
  for i := 1 to Length(Content) do
  begin
    c := Content[i];
    if not (c in AllowedChars) then
    begin
      FLastError := 'ValidateVersionFile: invalid char #' +
                    IntToStr(Ord(c)) + ' at pos ' + IntToStr(i);
      Log(FLastError); Exit;
    end;
  end;
  Lines := TStringList.Create;
  try
    Lines.Text := Content;
    while (Lines.Count > 0) and (Trim(Lines[Lines.Count - 1]) = '') do
      Lines.Delete(Lines.Count - 1);
    Log('ValidateVersionFile: line count (trimmed)=' + IntToStr(Lines.Count));
    if (Lines.Count < MinLines) or (Lines.Count > MaxLines) then
    begin
      FLastError := 'ValidateVersionFile: wrong line count ' + IntToStr(Lines.Count) +
                    ' (expected ' + IntToStr(MinLines) + '..' + IntToStr(MaxLines) + ')';
      Log(FLastError); Exit;
    end;
    if (Length(Lines[0]) < 1) or (Length(Lines[0]) > 3) then
    begin
      FLastError := 'ValidateVersionFile: line[0] bad length=' + IntToStr(Length(Lines[0]));
      Log(FLastError); Exit;
    end;
    if StrToIntDef(Lines[0], -1) < 0 then
    begin
      FLastError := 'ValidateVersionFile: line[0] not a number: "' + Lines[0] + '"';
      Log(FLastError); Exit;
    end;
    if Length(Lines[1]) <> 19 then
    begin
      FLastError := 'ValidateVersionFile: line[1] length=' + IntToStr(Length(Lines[1])) + ' expected 19';
      Log(FLastError); Exit;
    end;
    if Length(Lines[4]) <> 19 then
    begin
      FLastError := 'ValidateVersionFile: line[4] length=' + IntToStr(Length(Lines[4])) + ' expected 19';
      Log(FLastError); Exit;
    end;
    if Length(Lines[7]) <> 19 then
    begin
      FLastError := 'ValidateVersionFile: line[7] length=' + IntToStr(Length(Lines[7])) + ' expected 19';
      Log(FLastError); Exit;
    end;
    if Length(Lines[2]) <> 64 then
    begin
      FLastError := 'ValidateVersionFile: line[2] length=' + IntToStr(Length(Lines[2])) + ' expected 64';
      Log(FLastError); Exit;
    end;
    if Length(Lines[5]) <> 64 then
    begin
      FLastError := 'ValidateVersionFile: line[5] length=' + IntToStr(Length(Lines[5])) + ' expected 64';
      Log(FLastError); Exit;
    end;
    if Length(Lines[8]) <> 64 then
    begin
      FLastError := 'ValidateVersionFile: line[8] length=' + IntToStr(Length(Lines[8])) + ' expected 64';
      Log(FLastError); Exit;
    end;
    Result := True;
    Log('ValidateVersionFile: OK');
  finally
    Lines.Free;
  end;
end;

function TUpdateChecker.ParseVersionFile(const Content: string): TUpdateInfo;
var
  Lines: TStringList;
begin
  Result.Valid := False;
  Result.CatpaqInfo.BuildNumber := 0;
  Result.CatpaqInfo.DateTime    := '';
  Result.CatpaqInfo.SHA256Hash  := '';
  Result.CatpaqInfo.FileSize    := 0;
  Result.EXEInfo.DateTime       := '';
  Result.EXEInfo.SHA256Hash     := '';
  Result.EXEInfo.FileSize       := 0;
  Result.DLLInfo.DateTime       := '';
  Result.DLLInfo.SHA256Hash     := '';
  Result.DLLInfo.FileSize       := 0;
  if not ValidateVersionFile(Content) then
  begin
    Log('ParseVersionFile: validation FAILED - ' + FLastError);
    Exit;
  end;
  Lines := TStringList.Create;
  try
    Lines.Text := Content;
    while (Lines.Count > 0) and (Trim(Lines[Lines.Count - 1]) = '') do
      Lines.Delete(Lines.Count - 1);
    Result.CatpaqInfo.BuildNumber := StrToIntDef(Lines[0], 0);
    Result.CatpaqInfo.DateTime    := Lines[1];
    Result.CatpaqInfo.SHA256Hash  := LowerCase(Lines[2]);
    Result.CatpaqInfo.FileSize    := StrToInt64Def(Lines[3], 0);
    Result.EXEInfo.DateTime       := Lines[4];
    Result.EXEInfo.SHA256Hash     := LowerCase(Lines[5]);
    Result.EXEInfo.FileSize       := StrToInt64Def(Lines[6], 0);
    Result.DLLInfo.DateTime       := Lines[7];
    Result.DLLInfo.SHA256Hash     := LowerCase(Lines[8]);
    if Lines.Count > 9 then
      Result.DLLInfo.FileSize := StrToInt64Def(Lines[9], 0);
    Result.Valid := True;
    Log('ParseVersionFile: OK');
    Log('  Catpaq build=' + IntToStr(Result.CatpaqInfo.BuildNumber) +
        ' date=' + Result.CatpaqInfo.DateTime +
        ' size=' + IntToStr(Result.CatpaqInfo.FileSize));
    Log('  zpaqfranz date=' + Result.EXEInfo.DateTime +
        ' size=' + IntToStr(Result.EXEInfo.FileSize));
    {$IFDEF WINDOWS}
    Log('  zpaqfranz.dll date=' + Result.DLLInfo.DateTime +
        ' size=' + IntToStr(Result.DLLInfo.FileSize));
    {$ENDIF}
  finally
    Lines.Free;
  end;
end;

function TUpdateChecker.CheckForUpdate(CurrentBuild: Integer;
  out UpdateInfo: TUpdateInfo): Boolean;
var
  Content:    TBytes;
  StrContent: string;
begin
  Content    := nil;
  Result     := False;
  SetLength(Content, 0);
  StrContent := '';
  UpdateInfo.Valid := False;
  Log('CheckForUpdate: currentBuild=' + IntToStr(CurrentBuild));
  Log('CheckForUpdate: fetching ' + FVersionURL);
  if not DownloadFile(FVersionURL, Content) then
  begin
    Log('CheckForUpdate: FAILED to download version file - ' + FLastError);
    Exit;
  end;
  SetLength(StrContent, Length(Content));
  if Length(Content) > 0 then
    Move(Content[0], StrContent[1], Length(Content));
  Log('CheckForUpdate: raw content (' + IntToStr(Length(StrContent)) + ' chars): [' +
      StringReplace(StringReplace(StrContent, #13, '', [rfReplaceAll]),
                    #10, '|', [rfReplaceAll]) + ']');
  UpdateInfo := ParseVersionFile(StrContent);
  if not UpdateInfo.Valid then
  begin
    Log('CheckForUpdate: version file parse FAILED - ' + FLastError);
    Exit;
  end;
  Result := UpdateInfo.CatpaqInfo.BuildNumber > CurrentBuild;
  Log('CheckForUpdate: serverBuild=' + IntToStr(UpdateInfo.CatpaqInfo.BuildNumber) +
      ' currentBuild=' + IntToStr(CurrentBuild) +
      ' => updateAvailable=' + BoolToStr(Result, 'TRUE', 'FALSE'));
end;

function TUpdateChecker.DownloadUpdate(const UpdateInfo: TUpdateInfo;
  out CatpaqPath, EXEPath, DLLPath: string): Boolean;
var
  CatpaqData, EXEData: TBytes;
  CatpaqHash, EXEHash: string;
  FS: TFileStream;
  {$IFDEF WINDOWS}
  DLLData: TBytes;
  DLLHash: string;
  {$ENDIF}
begin
  CatpaqData := nil;
  EXEData    := nil;
  Result     := False;
  CatpaqPath := '';
  EXEPath    := '';
  DLLPath    := '';

  // --- catpaq ---
  {$IFDEF WINDOWS}
  Log('DownloadUpdate: downloading catpaq.exe...');
  if not DownloadFile(FBaseURL + 'catpaq.exe', CatpaqData) then
  begin Log('DownloadUpdate: FAILED catpaq.exe - ' + FLastError); Exit; end;
  {$ELSE}
  Log('DownloadUpdate: downloading catpaq...');
  if not DownloadFile(FBaseURL + 'catpaq', CatpaqData) then
  begin Log('DownloadUpdate: FAILED catpaq - ' + FLastError); Exit; end;
  {$ENDIF}
  if Length(CatpaqData) <> UpdateInfo.CatpaqInfo.FileSize then
  begin
    FLastError := 'catpaq size mismatch: got ' + IntToStr(Length(CatpaqData)) +
                  ' expected ' + IntToStr(UpdateInfo.CatpaqInfo.FileSize);
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;
  CatpaqHash := SHA256Bytes(CatpaqData);
  if CatpaqHash <> UpdateInfo.CatpaqInfo.SHA256Hash then
  begin
    FLastError := 'catpaq hash mismatch';
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;

  // --- zpaqfranz ---
  {$IFDEF WINDOWS}
  Log('DownloadUpdate: downloading zpaqfranz.exe...');
  if not DownloadFile(FBaseURL + 'zpaqfranz.exe', EXEData) then
  begin Log('DownloadUpdate: FAILED zpaqfranz.exe - ' + FLastError); Exit; end;
  {$ELSE}
  Log('DownloadUpdate: downloading zpaqfranz...');
  if not DownloadFile(FBaseURL + 'zpaqfranz', EXEData) then
  begin Log('DownloadUpdate: FAILED zpaqfranz - ' + FLastError); Exit; end;
  {$ENDIF}
  if Length(EXEData) <> UpdateInfo.EXEInfo.FileSize then
  begin
    FLastError := 'zpaqfranz size mismatch: got ' + IntToStr(Length(EXEData)) +
                  ' expected ' + IntToStr(UpdateInfo.EXEInfo.FileSize);
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;
  EXEHash := SHA256Bytes(EXEData);
  if EXEHash <> UpdateInfo.EXEInfo.SHA256Hash then
  begin
    FLastError := 'zpaqfranz hash mismatch';
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;

  {$IFDEF WINDOWS}
  // --- zpaqfranz.dll (solo Windows) ---
  DLLData := nil;
  Log('DownloadUpdate: downloading zpaqfranz.dll...');
  if not DownloadFile(FBaseURL + 'zpaqfranz.dll', DLLData) then
  begin Log('DownloadUpdate: FAILED zpaqfranz.dll - ' + FLastError); Exit; end;
  if Length(DLLData) <> UpdateInfo.DLLInfo.FileSize then
  begin
    FLastError := 'zpaqfranz.dll size mismatch: got ' + IntToStr(Length(DLLData)) +
                  ' expected ' + IntToStr(UpdateInfo.DLLInfo.FileSize);
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;
  DLLHash := SHA256Bytes(DLLData);
  if DLLHash <> UpdateInfo.DLLInfo.SHA256Hash then
  begin
    FLastError := 'zpaqfranz.dll hash mismatch';
    Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
  end;
  {$ENDIF}

  // --- Salva in temp ---
  {$IFDEF WINDOWS}
  CatpaqPath := FTempDir + 'catpaq.exe';
  EXEPath    := FTempDir + 'zpaqfranz.exe';
  DLLPath    := FTempDir + 'zpaqfranz.dll';
  {$ELSE}
  CatpaqPath := FTempDir + 'catpaq';
  EXEPath    := FTempDir + 'zpaqfranz';
  DLLPath    := '';
  {$ENDIF}
  Log('DownloadUpdate: saving to ' + FTempDir);

  try
    FS := TFileStream.Create(CatpaqPath, fmCreate);
    try
      if Length(CatpaqData) > 0 then FS.Write(CatpaqData[0], Length(CatpaqData));
    finally FS.Free; end;

    FS := TFileStream.Create(EXEPath, fmCreate);
    try
      if Length(EXEData) > 0 then FS.Write(EXEData[0], Length(EXEData));
    finally FS.Free; end;

    {$IFDEF WINDOWS}
    FS := TFileStream.Create(DLLPath, fmCreate);
    try
      if Length(DLLData) > 0 then FS.Write(DLLData[0], Length(DLLData));
    finally FS.Free; end;
    Log('DownloadUpdate: OK - all 3 files verified and saved');
    {$ELSE}
    Log('DownloadUpdate: OK - catpaq and zpaqfranz verified and saved');
    {$ENDIF}
  except
    on E: Exception do
    begin
      FLastError := 'Error saving temp files: ' + E.ClassName + ': ' + E.Message;
      Log('DownloadUpdate: FAILED - ' + FLastError); Exit;
    end;
  end;

  Result := True;
end;

function TUpdateChecker.DownloadFile_Public(out EXEData: TBytes): Boolean;
{$IFDEF WINDOWS}
const ExeName = 'zpaqfranz.exe';
{$ELSE}
const ExeName = 'zpaqfranz';
{$ENDIF}
begin
  EXEData := nil;
  Log('DownloadFile_Public: downloading ' + FBaseURL + ExeName);
  Result := DownloadFile(FBaseURL + ExeName, EXEData);
  if not Result then
    Log('DownloadFile_Public: FAILED - ' + FLastError)
  else
    Log('DownloadFile_Public: OK (' + IntToStr(Length(EXEData)) + ' bytes)');
end;

function TUpdateChecker.DownloadDLLFile(out DLLData: TBytes): Boolean;
begin
  DLLData := nil;
  {$IFDEF WINDOWS}
  Log('DownloadDLLFile: downloading ' + FBaseURL + 'zpaqfranz.dll');
  Result := DownloadFile(FBaseURL + 'zpaqfranz.dll', DLLData);
  if not Result then
    Log('DownloadDLLFile: FAILED - ' + FLastError)
  else
    Log('DownloadDLLFile: OK (' + IntToStr(Length(DLLData)) + ' bytes)');
  {$ELSE}
  Result := False;
  FLastError := 'DownloadDLLFile: not applicable on this platform';
  Log(FLastError);
  {$ENDIF}
end;

function TUpdateChecker.CalculateSHA256FromBytes_Public(const Data: TBytes): string;
begin
  Result := SHA256Bytes(Data);
end;

function TUpdateChecker.ApplyUpdate(const NewCatpaqPath, NewEXEPath, NewDLLPath: string): Boolean;
{$IFDEF WINDOWS}
var
  TargetCatpaq, TargetZpaqExe, TargetZpaqDll, BatchFile: string;
  BatchContent: TStringList;
{$ENDIF}
begin
  Result := False;
  Log('ApplyUpdate: NewCatpaqPath=' + NewCatpaqPath);
  Log('ApplyUpdate: NewEXEPath='    + NewEXEPath);
  Log('ApplyUpdate: NewDLLPath='    + NewDLLPath);

  {$IFDEF WINDOWS}
  TargetCatpaq  := ParamStr(0);
  TargetZpaqExe := ExtractFilePath(TargetCatpaq) + 'zpaqfranz.exe';
  TargetZpaqDll := ExtractFilePath(TargetCatpaq) + 'zpaqfranz.dll';
  BatchFile     := FTempDir + 'update.bat';
  Log('ApplyUpdate: target catpaq=' + TargetCatpaq);
  Log('ApplyUpdate: target exe='    + TargetZpaqExe);
  Log('ApplyUpdate: target dll='    + TargetZpaqDll);
  Log('ApplyUpdate: batch file='    + BatchFile);

  BatchContent := TStringList.Create;
  try
    BatchContent.Add('@echo off');
    BatchContent.Add('echo Updating Catpaq...');
    BatchContent.Add('timeout /t 2 /nobreak >nul');
    BatchContent.Add('taskkill /F /IM catpaq.exe >nul 2>&1');
    BatchContent.Add('timeout /t 1 /nobreak >nul');
    BatchContent.Add(':RETRY');
    BatchContent.Add('copy /Y "' + NewCatpaqPath + '" "' + TargetCatpaq  + '" >nul 2>&1');
    BatchContent.Add('if errorlevel 1 (');
    BatchContent.Add('  timeout /t 1 /nobreak >nul');
    BatchContent.Add('  goto RETRY');
    BatchContent.Add(')');
    BatchContent.Add('copy /Y "' + NewEXEPath   + '" "' + TargetZpaqExe + '" >nul 2>&1');
    BatchContent.Add('copy /Y "' + NewDLLPath   + '" "' + TargetZpaqDll + '" >nul 2>&1');
    BatchContent.Add('start "" "' + TargetCatpaq + '"');
    BatchContent.Add('del "%~f0"');
    try
      BatchContent.SaveToFile(BatchFile);
    except
      on E: Exception do
      begin
        FLastError := 'Cannot write batch file: ' + E.Message;
        Log('ApplyUpdate: FAILED - ' + FLastError);
        Exit;
      end;
    end;
    ShellExecute(0, 'open', PChar(BatchFile), nil, nil, SW_HIDE);
    Result := True;
    Log('ApplyUpdate: batch launched OK');
  finally
    BatchContent.Free;
  end;

  {$ELSE}
  // macOS / Linux: copia catpaq e zpaqfranz, imposta permessi eseguibili
  Log('ApplyUpdate: copying on Unix/macOS...');
  if not FileUtil.CopyFile(NewCatpaqPath, ParamStr(0)) then
  begin
    FLastError := 'CopyFile failed: ' + NewCatpaqPath + ' -> ' + ParamStr(0);
    Log('ApplyUpdate: FAILED - ' + FLastError);
    Exit;
  end;
  if not FileUtil.CopyFile(NewEXEPath,
       ExtractFilePath(ParamStr(0)) + 'zpaqfranz') then
  begin
    FLastError := 'CopyFile failed: ' + NewEXEPath + ' -> zpaqfranz';
    Log('ApplyUpdate: FAILED - ' + FLastError);
    Exit;
  end;
  {$IFDEF UNIX}
  FpChmod(ParamStr(0), &755);
  FpChmod(ExtractFilePath(ParamStr(0)) + 'zpaqfranz', &755);
  {$ENDIF}
  Result := True;
  Log('ApplyUpdate: OK');
  {$ENDIF}
end;

end.
