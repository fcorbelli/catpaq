unit ucatpaq_update;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ucatpaq_sha256;

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

    {$IFNDEF WINDOWS}
    procedure HandleDataReceived(Sender: TObject; const ContentLength, CurrentPos: Int64);
    {$ENDIF}
    procedure Log(const AMsg: string);
    function  ParseVersionFile(const Content: string): TUpdateInfo;
    function  ValidateVersionFile(const Content: string): Boolean;
    function  DownloadFile(const URL: string; var Content: TBytes): Boolean;
  public
    constructor Create;

    function CheckForUpdate(CurrentBuild: Integer; out UpdateInfo: TUpdateInfo): Boolean;
    function DownloadUpdate(const UpdateInfo: TUpdateInfo; out CatpaqPath, EXEPath: string): Boolean;
    function ApplyUpdate(const NewCatpaqPath, NewEXEPath: string): Boolean;
    function DownloadFile_Public(out EXEData: TBytes): Boolean;
    function CalculateSHA256FromBytes_Public(const Data: TBytes): string;

    property LastError:   string               read FLastError;
    property OnLog:       TUpdateLogEvent      read FOnLog      write FOnLog;
    property OnProgress:  TUpdateProgressEvent read FOnProgress write FOnProgress;
  end;

implementation

uses
  {$IFDEF WINDOWS}
  Windows, ShellApi, wininet,
  {$ELSE}
  fphttpclient,
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
  {$IFDEF CPU32}
  FVersionURL := 'https://www.francocorbelli.it/catpaq/latest/win32/version32.txt';
  FBaseURL    := 'https://www.francocorbelli.it/catpaq/latest/win32/';
  {$ELSE}
  FVersionURL := 'https://www.francocorbelli.it/catpaq/latest/win64/version.txt';
  FBaseURL    := 'https://www.francocorbelli.it/catpaq/latest/win64/';
  {$ENDIF}
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

{$IFNDEF WINDOWS}
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
{$ENDIF}

{$IFDEF WINDOWS}
function TUpdateChecker.DownloadFile(const URL: string; var Content: TBytes): Boolean;
var
  hInet, hUrl: HINTERNET;
  Buffer: array[0..8191] of Byte;
  BytesRead: DWORD;
  ContentLengthStr: string;
  ContentLengthLen: DWORD;
  Index: DWORD;
  BufStr: array[0..255] of Char;
  StatusCode: Integer;
  Stream: TBytesStream;
  Flags: DWORD;
  TimeoutMs: DWORD;
begin
  Result     := False;
  FLastError := '';
  SetLength(Content, 0);
  FDownloadTotal    := 0;
  FDownloadReported := 0;
  if Assigned(FOnProgress) then FOnProgress(0, 0);
  Log('DownloadFile (Native Windows): URL=' + URL);

  hInet := InternetOpen('CatpaqUpdater', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hInet = nil then
  begin
    FLastError := 'InternetOpen failed';
    Log('DownloadFile: FAILED - ' + FLastError);
    Exit;
  end;

  try
    // Imposta i timeout (es. 15 secondi) per evitare freeze
    TimeoutMs := 15000;
    InternetSetOption(hInet, INTERNET_OPTION_CONNECT_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hInet, INTERNET_OPTION_RECEIVE_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));
    InternetSetOption(hInet, INTERNET_OPTION_SEND_TIMEOUT, @TimeoutMs, SizeOf(TimeoutMs));

    // Imposta il flag sicuro SOLO se l'URL usa HTTPS
    Flags := INTERNET_FLAG_RELOAD; // Ignora la cache
    if Pos('https://', LowerCase(URL)) = 1 then
      Flags := Flags or INTERNET_FLAG_SECURE;

    hUrl := InternetOpenUrl(hInet, PChar(URL), nil, 0, Flags, 0);
    if hUrl = nil then
    begin
      FLastError := 'InternetOpenUrl failed for ' + URL;
      Log('DownloadFile: FAILED - ' + FLastError);
      Exit;
    end;

    try
      // Controlla lo Status Code HTTP (es. 200 OK)
      ContentLengthLen := SizeOf(BufStr);
      Index := 0;
      if HttpQueryInfo(hUrl, HTTP_QUERY_STATUS_CODE, @BufStr, ContentLengthLen, Index) then
      begin
        StatusCode := StrToIntDef(StrPas(BufStr), 0);
        Log('DownloadFile: HTTP status=' + IntToStr(StatusCode));
        if StatusCode <> 200 then
        begin
          FLastError := 'HTTP ' + IntToStr(StatusCode) + ' for URL: ' + URL;
          Log('DownloadFile: FAILED - ' + FLastError);
          Exit;
        end;
      end;

      // Cerca di ottenere il Content-Length
      ContentLengthLen := SizeOf(BufStr);
      Index := 0;
      if HttpQueryInfo(hUrl, HTTP_QUERY_CONTENT_LENGTH, @BufStr, ContentLengthLen, Index) then
      begin
        ContentLengthStr := StrPas(BufStr);
        FDownloadTotal := StrToInt64Def(ContentLengthStr, 0);
      end;

      Stream := TBytesStream.Create;
      try
        repeat
          if not InternetReadFile(hUrl, @Buffer, SizeOf(Buffer), BytesRead) then
          begin
            FLastError := 'InternetReadFile failed';
            Log('DownloadFile: FAILED - ' + FLastError);
            Exit;
          end;

          if BytesRead > 0 then
          begin
            Stream.Write(Buffer[0], BytesRead);
            if Assigned(FOnProgress) then
            begin
              // Notifica il progresso ogni ~32KB o alla fine
              if (Stream.Size - FDownloadReported >= 32768) or ((FDownloadTotal > 0) and (Stream.Size = FDownloadTotal)) then
              begin
                FDownloadReported := Stream.Size;
                FOnProgress(Stream.Size, FDownloadTotal);
              end;
            end;
          end;
        until BytesRead = 0;

        if Stream.Size = 0 then
        begin
          FLastError := 'Empty response (0 bytes) for URL: ' + URL;
          Log('DownloadFile: FAILED - ' + FLastError);
          Exit;
        end;

        Content := Stream.Bytes;
        SetLength(Content, Stream.Size); // Tronca la lunghezza al byte esatto
        Result := True;
        if Assigned(FOnProgress) then FOnProgress(Stream.Size, Stream.Size);
        Log('DownloadFile: OK (' + IntToStr(Length(Content)) + ' bytes)');
      finally
        Stream.Free;
      end;
    finally
      InternetCloseHandle(hUrl);
    end;
  finally
    InternetCloseHandle(hInet);
  end;
end;

{$ELSE}

// Versione macOS/Linux: usa fphttpclient originale (HTTP)
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
  Log('DownloadFile (FPHTTP): URL=' + URL);
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
{$ENDIF}

function TUpdateChecker.ValidateVersionFile(const Content: string): Boolean;
var
  Lines: TStringList;
  i: Integer;
  c: Char;
const
  MaxLines = 11;
  MinLines = 7;   // 7 = formato 32-bit (build + 2 file x 3 righe)
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
    if (Length(Lines[0]) < 1) or (Length(Lines[0]) > 5) then
    begin
      FLastError := 'ValidateVersionFile: line[0] bad length=' + IntToStr(Length(Lines[0]));
      Log(FLastError); Exit;
    end;
    if StrToIntDef(Lines[0], -1) < 0 then
    begin
      FLastError := 'ValidateVersionFile: line[0] not a number: "' + Lines[0] + '"';
      Log(FLastError); Exit;
    end;
    // line[1]: data catpaq
    if Length(Lines[1]) <> 19 then
    begin
      FLastError := 'ValidateVersionFile: line[1] length=' + IntToStr(Length(Lines[1])) + ' expected 19';
      Log(FLastError); Exit;
    end;
    // line[2]: hash catpaq
    if Length(Lines[2]) <> 64 then
    begin
      FLastError := 'ValidateVersionFile: line[2] length=' + IntToStr(Length(Lines[2])) + ' expected 64';
      Log(FLastError); Exit;
    end;
    // line[4]: data exe/xp
    if Length(Lines[4]) <> 19 then
    begin
      FLastError := 'ValidateVersionFile: line[4] length=' + IntToStr(Length(Lines[4])) + ' expected 19';
      Log(FLastError); Exit;
    end;
    // line[5]: hash exe/xp
    if Length(Lines[5]) <> 64 then
    begin
      FLastError := 'ValidateVersionFile: line[5] length=' + IntToStr(Length(Lines[5])) + ' expected 64';
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
    // Formato 64-bit
    Result.Valid := True;
    Log('ParseVersionFile: OK');
    Log('  Catpaq build=' + IntToStr(Result.CatpaqInfo.BuildNumber) +
        ' date=' + Result.CatpaqInfo.DateTime +
        ' size=' + IntToStr(Result.CatpaqInfo.FileSize));
    Log('  zpaqfranz date=' + Result.EXEInfo.DateTime +
        ' size=' + IntToStr(Result.EXEInfo.FileSize));
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
  out CatpaqPath, EXEPath: string): Boolean;
var
  CatpaqData, EXEData: TBytes;
  CatpaqHash, EXEHash: string;
  FS: TFileStream;
begin
  CatpaqData := nil;
  EXEData    := nil;
  Result     := False;
  CatpaqPath := '';
  EXEPath    := '';

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
  {$IFDEF CPU32}
  Log('DownloadUpdate: downloading zpaqfranzxp.exe...');
  if not DownloadFile(FBaseURL + 'zpaqfranzxp.exe', EXEData) then
  begin Log('DownloadUpdate: FAILED zpaqfranzxp.exe - ' + FLastError); Exit; end;
  {$ELSE}
  Log('DownloadUpdate: downloading zpaqfranz.exe...');
  if not DownloadFile(FBaseURL + 'zpaqfranz.exe', EXEData) then
  begin Log('DownloadUpdate: FAILED zpaqfranz.exe - ' + FLastError); Exit; end;
  {$ENDIF}
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



  // --- Salva in temp ---
  {$IFDEF WINDOWS}
  {$IFDEF CPU32}
  CatpaqPath := FTempDir + 'catpaq32.exe';
  EXEPath    := FTempDir + 'zpaqfranzxp.exe';
  {$ELSE}
  CatpaqPath := FTempDir + 'catpaq.exe';
  EXEPath    := FTempDir + 'zpaqfranz.exe';
  {$ENDIF}
  {$ELSE}
  CatpaqPath := FTempDir + 'catpaq';
  EXEPath    := FTempDir + 'zpaqfranz';
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

    Log('DownloadUpdate: OK - all files verified and saved');
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
  {$IFDEF CPU32}
  const ExeName = 'zpaqfranzxp.exe';
  {$ELSE}
  const ExeName = 'zpaqfranz.exe';
  {$ENDIF}
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


function TUpdateChecker.CalculateSHA256FromBytes_Public(const Data: TBytes): string;
begin
  Result := SHA256Bytes(Data);
end;

function TUpdateChecker.ApplyUpdate(const NewCatpaqPath, NewEXEPath: string): Boolean;
{$IFDEF WINDOWS}
var
  TargetCatpaq, TargetZpaqExe,BatchFile: string;
  BatchContent: TStringList;
{$ENDIF}
begin
  Result := False;
  Log('ApplyUpdate: NewCatpaqPath=' + NewCatpaqPath);
  Log('ApplyUpdate: NewEXEPath='    + NewEXEPath);

  {$IFDEF WINDOWS}
  TargetCatpaq  := ParamStr(0);
  TargetZpaqExe := ExtractFilePath(TargetCatpaq) + 'zpaqfranz.exe';
  BatchFile     := FTempDir + 'update.bat';
  Log('ApplyUpdate: target catpaq=' + TargetCatpaq);
  Log('ApplyUpdate: target exe='    + TargetZpaqExe);
  Log('ApplyUpdate: batch file='    + BatchFile);

  BatchContent := TStringList.Create;
  try
    BatchContent.Add('@echo off');
    BatchContent.Add('echo Updating Catpaq...');
    BatchContent.Add('timeout /t 2 /nobreak >nul');
    BatchContent.Add('taskkill /F /IM catpaq.exe >nul 2>&1');
    BatchContent.Add('timeout /t 1 /nobreak >nul');

    // Inizializza contatore per evitare loop infiniti
    BatchContent.Add('set COUNT=0');
    BatchContent.Add(':RETRY');
    BatchContent.Add('set /A COUNT+=1');
    BatchContent.Add('if %COUNT% GTR 15 goto FAIL'); // Max 15 tentativi (~15 secondi)

    // Prova a copiare catpaq.exe
    BatchContent.Add('copy /Y "' + NewCatpaqPath + '" "' + TargetCatpaq  + '" >nul 2>&1');
    BatchContent.Add('if errorlevel 1 (');
    BatchContent.Add('  timeout /t 1 /nobreak >nul');
    BatchContent.Add('  goto RETRY');
    BatchContent.Add(')');

    // Se catpaq è stato copiato, copia gli altri file
    BatchContent.Add('copy /Y "' + NewEXEPath   + '" "' + TargetZpaqExe + '" >nul 2>&1');

    // Riavvia l'applicazione aggiornata
    BatchContent.Add('start "" "' + TargetCatpaq + '"');
    BatchContent.Add('goto END');

    // Gestione errore
    BatchContent.Add(':FAIL');
    BatchContent.Add('echo UPDATE FAILED! File could not be replaced. Ensure catpaq is closed.');
    BatchContent.Add('timeout /t 5 >nul'); // Lascia il messaggio visibile per 5 secondi

    BatchContent.Add(':END');
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
