unit uglobals;

{$mode objfpc}{$H+}

{ ============================================================================ }
{  Catpaq - funzioni di libreria condivise tra frmMain e frmSimply             }
{  - Geometria finestre (save/load su INI)                                     }
{  - Caricamento lingua da file INI (stesso formato di frmMain)                }
{  - Scansione file lingua disponibili                                         }
{ ============================================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, IniFiles, Math;

{ ---------------------------------------------------------------------------- }
{  INI path                                                                     }
{ ---------------------------------------------------------------------------- }

{ Restituisce il path corretto del file INI di catpaq per la piattaforma:
    Windows : accanto all'eseguibile (catpaq.ini)
    macOS   : ~/Library/Application Support/catpaq/catpaq.ini
    Linux   : ~/.config/catpaq/catpaq.ini  (AppImage-safe)
  Crea la directory se non esiste. }
function GetCatpaqIniPath: string;

{ ---------------------------------------------------------------------------- }
{  Debug mode                                                                   }
{ ---------------------------------------------------------------------------- }

{ Variabile globale: True = scrittura log bridge su file abilitata.
  Letta dalla sezione [Debug] chiave BridgeLog del file INI di catpaq.
  Default: False (log disabilitato). }
var
  DebugMode: Boolean = False;

{ Legge il valore di DebugMode dal file INI. Da chiamare dopo GetCatpaqIniPath. }
procedure LoadDebugMode(const AIniPath: string);

{ ---------------------------------------------------------------------------- }
{  Window geometry                                                              }
{ ---------------------------------------------------------------------------- }

procedure SaveWindowGeometry(const AIniPath, ASection: string; AForm: TForm);
function  LoadWindowGeometry(const AIniPath, ASection: string; AForm: TForm;
                              ADefWidthPct: Integer = 80;
                              ADefHeightPct: Integer = 80): Boolean;

{ ---------------------------------------------------------------------------- }
{  Language                                                                     }
{ ---------------------------------------------------------------------------- }

function LoadLanguageFile(const ALangName: string; ALang: TStringList): Boolean;
function LangStr(ALang: TStringList; const AKey, ADefault: string): string;
function ScanLanguageFiles: TStringList;

implementation

{ ============================================================================ }
{  INI path                                                                    }
{ ============================================================================ }

function GetCatpaqIniPath: string;
begin
  {$IFDEF DARWIN}
  Result := GetUserDir + 'Library/Application Support/catpaq/catpaq.ini';
  {$ELSE}
  {$IFDEF LINUX}
  Result := GetUserDir + '.config/catpaq/catpaq.ini';
  {$ELSE}
  // Windows: accanto all'eseguibile
  Result := ChangeFileExt(Application.ExeName, '.ini');
  {$ENDIF}
  {$ENDIF}
  ForceDirectories(ExtractFilePath(Result));
end;

{ ============================================================================ }
{  Debug mode                                                                  }
{ ============================================================================ }

procedure LoadDebugMode(const AIniPath: string);
var
  Ini: TIniFile;
begin
  DebugMode := False;  { default: disabilitato }
  if (AIniPath = '') or not FileExists(AIniPath) then Exit;
  Ini := TIniFile.Create(AIniPath);
  try
    DebugMode := Ini.ReadBool('Debug', 'BridgeLog', False);
  finally
    Ini.Free;
  end;
end;

{ ============================================================================ }
{  Window geometry                                                              }
{ ============================================================================ }

procedure SaveWindowGeometry(const AIniPath, ASection: string; AForm: TForm);
var Ini: TIniFile;
begin
  if (AIniPath = '') or (AForm = nil) then Exit;
  if AForm.WindowState <> wsNormal then Exit;
  Ini := TIniFile.Create(AIniPath);
  try
    Ini.WriteInteger(ASection, 'Left',   AForm.Left);
    Ini.WriteInteger(ASection, 'Top',    AForm.Top);
    Ini.WriteInteger(ASection, 'Width',  AForm.Width);
    Ini.WriteInteger(ASection, 'Height', AForm.Height);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function LoadWindowGeometry(const AIniPath, ASection: string; AForm: TForm;
                             ADefWidthPct: Integer;
                             ADefHeightPct: Integer): Boolean;
const
  SANE_MIN_W = 300;
  SANE_MIN_H = 200;
var
  Ini: TIniFile;
  L, T, Wd, Ht: Integer;

  procedure ApplyDefault;
  var W2, H2: Integer;
  begin
    W2 := Screen.WorkAreaWidth  * ADefWidthPct  div 100;
    H2 := Screen.WorkAreaHeight * ADefHeightPct div 100;
    AForm.Width  := W2;
    AForm.Height := H2;
    AForm.Left   := Screen.WorkAreaLeft + (Screen.WorkAreaWidth  - W2) div 2;
    AForm.Top    := Screen.WorkAreaTop  + (Screen.WorkAreaHeight - H2) div 2;
    AForm.Position := poDesigned;
  end;

begin
  Result := False;
  if (AIniPath = '') or (AForm = nil) then Exit;
  if not FileExists(AIniPath) then begin ApplyDefault; Exit; end;

  Ini := TIniFile.Create(AIniPath);
  try
    L  := Ini.ReadInteger(ASection, 'Left',   -1);
    T  := Ini.ReadInteger(ASection, 'Top',    -1);
    Wd := Ini.ReadInteger(ASection, 'Width',   0);
    Ht := Ini.ReadInteger(ASection, 'Height',  0);
  finally
    Ini.Free;
  end;

  if (Wd >= SANE_MIN_W) and (Ht >= SANE_MIN_H) then
  begin
    if Wd > Screen.WorkAreaWidth  then Wd := Screen.WorkAreaWidth;
    if Ht > Screen.WorkAreaHeight then Ht := Screen.WorkAreaHeight;
    if L < Screen.WorkAreaLeft then L := Screen.WorkAreaLeft;
    if T < Screen.WorkAreaTop  then T := Screen.WorkAreaTop;
    if L + Wd > Screen.WorkAreaLeft + Screen.WorkAreaWidth then
      L := Max(Screen.WorkAreaLeft,
               Screen.WorkAreaLeft + Screen.WorkAreaWidth - Wd);
    if T + Ht > Screen.WorkAreaTop + Screen.WorkAreaHeight then
      T := Max(Screen.WorkAreaTop,
               Screen.WorkAreaTop + Screen.WorkAreaHeight - Ht);
    AForm.Position := poDesigned;
    AForm.Left := L; AForm.Top := T;
    AForm.Width := Wd; AForm.Height := Ht;
    Result := True;
  end
  else
    ApplyDefault;
end;

{ ============================================================================ }
{  Language                                                                     }
{ ============================================================================ }

function LoadLanguageFile(const ALangName: string; ALang: TStringList): Boolean;
var
  LangFile: string;
  Ini:  TIniFile;
  Keys: TStringList;
  I:    Integer;
begin
  Result := False;
  ALang.Clear;
  if (ALangName = '') or SameText(ALangName, 'english') then Exit;
  LangFile := ExtractFilePath(Application.ExeName) +
              'languages_' + LowerCase(ALangName) + '.ini';
  if not FileExists(LangFile) then Exit;
  Ini  := TIniFile.Create(LangFile);
  Keys := TStringList.Create;
  try
    Ini.ReadSection('Strings', Keys);
    for I := 0 to Keys.Count - 1 do
      ALang.Add(Keys[I] + '=' + Ini.ReadString('Strings', Keys[I], ''));
    Result := True;
  finally
    Keys.Free; Ini.Free;
  end;
end;

function LangStr(ALang: TStringList; const AKey, ADefault: string): string;
var Idx: Integer;
begin
  if ALang.Count = 0 then begin Result := ADefault; Exit; end;
  Idx := ALang.IndexOfName(AKey);
  if Idx >= 0 then Result := ALang.ValueFromIndex[Idx]
  else Result := ADefault;
end;

function ScanLanguageFiles: TStringList;
var SR: TSearchRec; BaseName, LangName: string;
begin
  Result := TStringList.Create;
  if FindFirst(ExtractFilePath(Application.ExeName) + 'languages_*.ini',
               faAnyFile, SR) = 0 then
  begin
    repeat
      BaseName := ChangeFileExt(SR.Name, '');
      LangName := Copy(BaseName, Length('languages_') + 1, Length(BaseName));
      if LangName <> '' then Result.Add(LowerCase(LangName));
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
end;

end.
