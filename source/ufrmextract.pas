unit ufrmextract;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, IniFiles, FileUtil, uzpaqbridge, Menus, ComCtrls, uglobals, LCLIntf;

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
    FFileName: string;         // singolo file (o vuoto = tutto)
    FFileNames: TStringList;   // lista file selezionati (per extract multi)
    FExtractAllMode: Boolean;  // True = extract all (nessun filtro file, -to = cartella)
    FVersion: Integer;
    FPasswordAES: string;
    FPasswordFranzen: string;

    FMode: TExtractMode;

    FSavedOnComplete: TZpaqCompleteEvent;
    FSavedOnLog: TZpaqLogEvent;
    FSavedOnProgress: TZpaqProgressEvent;
    FSavedIsDataMode: Boolean;

    FLogPollTimer: TTimer;

    chkForceOverwrite: TCheckBox;   { creato a runtime nel pnlBottom }
    FForceOverwrite: Boolean;        { True = aggiunge -force al comando }

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
    procedure UpdateMultiPreview;
    procedure cmbDestPathChange(Sender: TObject);
    procedure chkForceOverwriteClick(Sender: TObject);
    procedure OpenDestInExplorer(const ADestPath: string; ASingleFile: Boolean);
  public
    procedure SetExtractionParams(
      const AArchivePath: string;
      const AFileName: string;
      AVersion: Integer;
      const APasswordAES: string;
      const APasswordFranzen: string);

    { Estrae una lista di N file; il campo To: deve contenere N path separati da spazio }
    procedure SetExtractionParamsMulti(
      const AArchivePath: string;
      const AFileNames: TStringList;
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

    procedure SetExternalPath(const AExternalPath: string);
    function GetDestPath: string;

    property Mode: TExtractMode read FMode write FMode;
  end;

var
  frmExtract: TfrmExtract;

implementation

{$R *.lfm}

uses LCLType
  {$IFDEF WINDOWS}
  , Windows, ShellApi
  {$ENDIF}
  ;

{ ============================================================================
  SanitizePathDir: converte la parte DIRECTORY di un path archivio in una
  stringa sicura da usare come sottocartella nella destinazione.

  Logica:
    - Estrae solo la parte directory (esclude il nome file finale).
    - Ogni carattere che NON sia lettera, cifra o '.' viene sostituito con '_'.
    - Se la directory risultante è vuota (file senza percorso) restituisce ''.

  Esempi:
    ''               → ''          (nessuna sottocartella)
    'va01.cpp'       → ''          (nessuna dir)
    'c:/pippo/x.cpp' → 'c__pippo'
    'd:\01.cpp'      → 'd_'
    '../nome.cpp'    → '__'
    '//srv/sh/f.cpp' → '____srv_sh'
    '/nome.cpp'      → '_'
    './nome.cpp'     → '_'
  ============================================================================ }
function SanitizePathDir(const AFilePath: string): string;
var
  Dir: string;
  I:   Integer;
  C:   Char;
begin
  Result := '';
  Dir := ExtractFilePath(AFilePath);

  { Rimuove il separatore finale prodotto da ExtractFilePath }
  while (Length(Dir) > 0) and
        ((Dir[Length(Dir)] = '/') or (Dir[Length(Dir)] = '\')) do
    SetLength(Dir, Length(Dir) - 1);

  if Dir = '' then Exit;

  { Sanitizza: ogni char non alfanumerico e non '.' → '_' }
  for I := 1 to Length(Dir) do
  begin
    C := Dir[I];
    if ((C >= 'a') and (C <= 'z')) or
       ((C >= 'A') and (C <= 'Z')) or
       ((C >= '0') and (C <= '9')) or
       (C = '.') then
      Result := Result + C
    else
      Result := Result + '_';
  end;
end;

{ Dato un path sorgente dell'archivio e una cartella base di destinazione,
  calcola il path completo di destinazione:
    - se la dir sanitizzata è vuota → BaseFolder/NomeFile
    - altrimenti                    → BaseFolder/DirSanitizzata/NomeFile    }
function BuildDestPath(const AFilePath, ABaseFolder: string): string;
var
  SanDir, FName, Base: string;
begin
  SanDir := SanitizePathDir(AFilePath);
  FName  := ExtractFileName(AFilePath);

  { Assicura che BaseFolder termini con '/' }
  Base := StringReplace(ABaseFolder, '\', '/', [rfReplaceAll]);
  if (Length(Base) > 0) and (Base[Length(Base)] <> '/') then
    Base := Base + '/';

  if SanDir = '' then
    Result := Base + FName
  else
    Result := Base + SanDir + '/' + FName;
end;

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
  if Assigned(chkForceOverwrite) then
    chkForceOverwrite.Enabled := not ARunning;
end;

procedure TfrmExtract.UpdateUIForMode;
var
  LastBottom: Integer;
begin
  if FMode = emTest then
  begin
    Caption              := S('extract_title_test', 'Test archive');
    lblDestPath.Caption  := S('extract_lbl_temp_folder', 'Temp test folder:');
    btnOK.Caption        := S('extract_btn_test', 'Test');
    SelectDirectoryDialog1.Title := S('extract_dlg_temp_folder', 'Select temp test folder');
    pnlExtraFields.Visible := False;
  end
  else if FExtractAllMode then
  begin
    { Extract all: solo cartella, nessun campo To/Find/Replace }
    lblDestPath.Caption  := S('extract_lbl_dest_folder', 'Destination folder:');
    btnOK.Caption        := S('extract_btn_extract', 'Extract');
    SelectDirectoryDialog1.Title := S('extract_dlg_dest_folder', 'Select destination folder');
    pnlExtraFields.Visible := False;
  end
  else
  begin
    { Singolo file o multi-file: dest è sempre una CARTELLA.
      edtTo opzionale: vuoto = nome originale, popolato = -to espliciti. }
    lblDestPath.Caption  := S('extract_lbl_dest_folder', 'Destination folder:');
    btnOK.Caption        := S('extract_btn_extract', 'Extract');
    SelectDirectoryDialog1.Title := S('extract_dlg_dest_folder', 'Select destination folder');
    pnlExtraFields.Visible := True;

    { Hint contestuale sul campo To: }
    if FFileNames.Count > 1 then
      edtTo.TextHint := Format(
        S('extract_hint_to_multi_opt',
          'Optional: %d space-separated paths to rename each file'),
        [FFileNames.Count])
    else
      edtTo.TextHint := S('extract_hint_to_opt',
        'Optional: destination file path to rename the extracted file');
  end;

  { Altezza parametrica: bottom dell'ultimo componente visibile + margine }
  if pnlExtraFields.Visible then
    LastBottom := pnlExtraFields.Top + pnlExtraFields.Height
  else
    LastBottom := cmbDestPath.Top + cmbDestPath.Height;
  pnlTop.Height := LastBottom + 20;

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

{ Aggiorna il memo con l'anteprima dei -to che saranno generati
  per la modalità multi-file, in base alla cartella base corrente. }
procedure TfrmExtract.UpdateMultiPreview;
var
  BaseDest, ToVal, FName: string;
  I: Integer;
begin
  if FFileNames.Count <= 1 then Exit;

  BaseDest := NormalizePath(Trim(cmbDestPath.Text));
  ToVal    := Trim(edtTo.Text);

  { Assicura slash finale per la preview }
  if (BaseDest <> '') and (BaseDest[Length(BaseDest)] <> '/') and
     (BaseDest[Length(BaseDest)] <> '\') then
    BaseDest := BaseDest + '/';

  memLog.Lines.BeginUpdate;
  try
    memLog.Lines.Clear;
    memLog.Lines.Add('=== ' +
      S('extract_preview_title', 'Extraction preview') + ' ===');
    memLog.Lines.Add('');

    if Trim(cmbDestPath.Text) = '' then
      memLog.Lines.Add(S('extract_preview_empty',
        '  (enter destination folder above to see preview)'))
    else if ToVal <> '' then
    begin
      { Override esplicito: mostra i token dell'utente }
      memLog.Lines.Add(S('extract_lbl_to_override', 'To override:') + '  ' + ToVal);
    end
    else
    begin
      { Auto: mostra il -to calcolato per ciascun file }
      for I := 0 to FFileNames.Count - 1 do
      begin
        FName := ExtractFileName(FFileNames[I]);
        memLog.Lines.Add(Format('  [%d] %s', [I + 1, FFileNames[I]]));
        memLog.Lines.Add(Format('       -to "%s%s"', [BaseDest, FName]));
      end;
    end;

    memLog.Lines.Add('');
    memLog.Lines.Add(Format(
      S('extract_preview_note', '%d file(s) will be extracted.'),
      [FFileNames.Count]));
  finally
    memLog.Lines.EndUpdate;
  end;
end;

procedure TfrmExtract.cmbDestPathChange(Sender: TObject);
begin
  if FFileNames.Count > 1 then
    UpdateMultiPreview;
end;

procedure TfrmExtract.chkForceOverwriteClick(Sender: TObject);
begin
  FForceOverwrite := chkForceOverwrite.Checked;
  FIniFile.WriteBool('Extract', 'ForceOverwrite', FForceOverwrite);
  FIniFile.UpdateFile;
end;

{ Apre il gestore file sulla destinazione estratta.
  - ASingleFile=True  : ADestPath è un FILE → apre Explorer con /select
                        per posizionarsi sul file (Windows);
                        su altri OS apre la cartella padre.
  - ASingleFile=False : ADestPath è una CARTELLA → la apre direttamente. }
procedure TfrmExtract.OpenDestInExplorer(const ADestPath: string;
  ASingleFile: Boolean);
begin
  if ADestPath = '' then Exit;

  if ASingleFile then
  begin
    {$IFDEF WINDOWS}
    { Explorer /select,<path> apre la cartella padre e seleziona il file }
    ShellExecute(0, 'open', 'explorer.exe',
      PChar('/select,"' + StringReplace(ADestPath, '/', '\', [rfReplaceAll]) + '"'),
      nil, SW_SHOWNORMAL);
    {$ELSE}
    { Non-Windows: apre la cartella padre }
    OpenDocument(ExtractFilePath(ADestPath));
    {$ENDIF}
  end
  else
  begin
    {$IFDEF WINDOWS}
    ShellExecute(0, 'explore',
      PChar(StringReplace(ADestPath, '/', '\', [rfReplaceAll])),
      nil, nil, SW_SHOWNORMAL);
    {$ELSE}
    OpenDocument(ADestPath);
    {$ENDIF}
  end;
end;

procedure TfrmExtract.FormCreate(Sender: TObject);
begin
  FIniFileName := GetCatpaqIniPath;
  FIniFile     := TIniFile.Create(FIniFileName);

  FSavedOnComplete := nil;
  FSavedOnLog      := nil;
  FSavedOnProgress := nil;
  FSavedIsDataMode := False;

  FFileNames       := TStringList.Create;
  FExtractAllMode  := False;

  FLogPollTimer          := TTimer.Create(Self);
  FLogPollTimer.Interval := 150;
  FLogPollTimer.Enabled  := False;
  FLogPollTimer.OnTimer  := @OnLogPollTimer;

  cmbDestPath.OnChange := @cmbDestPathChange;

  btnOK.ModalResult := mrNone;
  btnAbort.Visible  := False;
  btnAbort.Enabled  := False;
  pgrProgress.Visible := False;
  lbleta.Visible  := False;
  lbleta.Caption  := '00:00:00';

  { --- Checkbox "Force overwrite" creato a runtime nel pnlBottom --- }
  FForceOverwrite := FIniFile.ReadBool('Extract', 'ForceOverwrite', False);
  chkForceOverwrite := TCheckBox.Create(Self);
  chkForceOverwrite.Parent  := pnlBottom;
  chkForceOverwrite.Caption := S('chk_force_overwrite', 'Force overwrite (-force)');
  chkForceOverwrite.Checked := FForceOverwrite;
  chkForceOverwrite.Left    := 8;
  chkForceOverwrite.Top     := 8;
  chkForceOverwrite.Width   := 300;
  chkForceOverwrite.OnClick := @chkForceOverwriteClick;

  FMode := emExtract;

  KeyPreview := True;
  btnCancel.Caption := S('extract_btn_cancel', 'Cancel');
  btnAbort.Caption  := S('extract_btn_abort', 'ABORT');

  LoadRecentPaths;
  UpdateUIForMode;
end;

procedure TfrmExtract.FormDestroy(Sender: TObject);
begin
  FLogPollTimer.Enabled := False;
  RestoreMainBridge;
  FFileNames.Free;
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
  FExtractAllMode  := False;
  FArchivePath     := AArchivePath;
  FFileName        := AFileName;
  FFileNames.Clear;
  if AFileName <> '' then
    FFileNames.Add(AFileName);
  FVersion         := AVersion;
  FPasswordAES     := APasswordAES;
  FPasswordFranzen := APasswordFranzen;

  if FFileName <> '' then
    Caption := S('extract_title_file', 'Extract') + ': ' + ExtractFileName(ExcludeTrailingPathDelimiter(FFileName))
  else
    Caption := S('extract_title_extract', 'Extract from archive');

  if FFileName <> '' then
    lblInfo.Caption := S('extract_lbl_file', 'File') + ': ' + FFileName +
                       '   ' + S('extract_lbl_version', 'Version') + ': ' + IntToStr(FVersion)
  else
    lblInfo.Caption := S('extract_lbl_archive', 'Archive') + ': ' + ExtractFileName(FArchivePath) +
                       '   (' + S('extract_lbl_everything', 'extract everything') + ')';

  { Hint sul campo To: per singolo file }
  if FFileName <> '' then
    edtTo.TextHint := S('extract_hint_to_file', 'Destination file path (leave empty = use archive path)')
  else
    edtTo.TextHint := '';

  UpdateUIForMode;
end;

{ Estrae una lista di N file dall'archivio.
  La cartella base viene inserita dall'utente; i -to vengono calcolati
  automaticamente tramite SanitizePathDir senza input manuale. }
procedure TfrmExtract.SetExtractionParamsMulti(
  const AArchivePath: string;
  const AFileNames: TStringList;
  const APasswordAES: string;
  const APasswordFranzen: string);
var
  I: Integer;
  FileList: string;
begin
  FMode            := emExtract;
  FExtractAllMode  := False;
  FArchivePath     := AArchivePath;
  FVersion         := -1;
  FPasswordAES     := APasswordAES;
  FPasswordFranzen := APasswordFranzen;

  FFileNames.Clear;
  FFileName := '';
  FileList  := '';
  for I := 0 to AFileNames.Count - 1 do
  begin
    FFileNames.Add(AFileNames[I]);
    if FileList <> '' then FileList := FileList + ', ';
    FileList := FileList + ExtractFileName(
                  ExcludeTrailingPathDelimiter(AFileNames[I]));
  end;

  Caption := Format(S('extract_title_multi', 'Extract %d files'), [AFileNames.Count]);

  { lblInfo mostrerà l'elenco file; il log di anteprima dei -to viene
    aggiornato in UpdateMultiPreview ogni volta che cambia la dest }
  lblInfo.Caption := Format(
    S('extract_lbl_multi', 'Files (%d): %s'), [AFileNames.Count, FileList]);

  lblDestPath.Caption := S('extract_lbl_dest_folder', 'Destination folder:');

  UpdateUIForMode;
  { Mostra subito l'anteprima (con dest eventualmente già precompilata) }
  UpdateMultiPreview;
end;

procedure TfrmExtract.SetExtractionParamsAll(
  const AArchivePath: string;
  const APasswordAES: string;
  const APasswordFranzen: string);
begin
  SetExtractionParams(AArchivePath, '', -1, APasswordAES, APasswordFranzen);
  FExtractAllMode := True;   { deve stare DOPO SetExtractionParams che lo resetta a False }
  Caption := S('extract_title_all', 'Extract everything from archive');
  { In modalità "extract all" il -to è sempre una cartella }
  edtTo.TextHint := S('extract_hint_to_folder',
    'Leave empty: files extracted with their full path inside destination folder');
  UpdateUIForMode;  { ricalcola layout con FExtractAllMode=True }
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

  Caption          := S('extract_title_test', 'Test archive') + ': ' + ExtractFileName(AArchivePath);
  lblInfo.Caption  := S('extract_lbl_archive', 'Archive') + ': ' + ExtractFileName(AArchivePath);

  UpdateUIForMode;
end;

procedure TfrmExtract.SetExternalPath(const AExternalPath: string);
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
{ Logica:
  - cmbDestPath è SEMPRE una cartella base.
  - Per ogni file selezionato viene costruito -to "cartella/nomefile".
  - Se edtTo è popolato con N token (spazio-separati), quei token
    sostituiscono i -to auto-calcolati (rinomina/reindirizza esplicita).
  - extract-all: solo -to <cartella>, nessun file esplicito. }
var
  DestPath: string;
  ToVal, FindVal, ReplaceVal: string;
  ToTokens: TStringList;
  I: Integer;
  BaseDest, FName, DestFile: string;
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
    Exit;
  end;

  { === Modalità EXTRACT === }
  Result := 'x "' + NormalizePath(FArchivePath) + '"';

  if FExtractAllMode then
  begin
    { Extract all: nessun file esplicito, -to è la cartella intera }
    Result := Result + ' -to "' + DestPath + '"';
    if FPasswordAES <> '' then
      Result := Result + ' -key "' + FPasswordAES + '"';
    if FPasswordFranzen <> '' then
      Result := Result + ' -franzen "' + FPasswordFranzen + '"';
    Result := Result + ' -catpaqmode';
    Exit;
  end;

  { Aggiunge i nomi dei file da estrarre }
  for I := 0 to FFileNames.Count - 1 do
    Result := Result + ' "' + NormalizePath(FFileNames[I]) + '"';

  { Assicura che la cartella base termini con / }
  BaseDest := DestPath;
  if (BaseDest <> '') and (BaseDest[Length(BaseDest)] <> '/') then
    BaseDest := BaseDest + '/';

  { Controlla se edtTo contiene override espliciti }
  ToVal := Trim(edtTo.Text);
  if ToVal <> '' then
  begin
    { Override esplicito: splitta i token e usa quelli come -to }
    ToTokens := TStringList.Create;
    try
      ExtractStrings([' '], ['"'], PChar(ToVal), ToTokens);
      for I := ToTokens.Count - 1 downto 0 do
        if Trim(ToTokens[I]) = '' then ToTokens.Delete(I);
      for I := 0 to ToTokens.Count - 1 do
        Result := Result + ' -to "' + NormalizePath(Trim(ToTokens[I])) + '"';
    finally
      ToTokens.Free;
    end;
  end
  else
  begin
    { Auto: per ogni file costruisce cartella_base/nome_file }
    for I := 0 to FFileNames.Count - 1 do
    begin
      FName    := ExtractFileName(FFileNames[I]);
      DestFile := BaseDest + FName;
      Result   := Result + ' -to "' + NormalizePath(DestFile) + '"';
    end;
  end;

  if (FVersion > 0) and (FFileNames.Count = 1) then
    Result := Result + ' -until ' + IntToStr(FVersion);
  if FPasswordAES <> '' then
    Result := Result + ' -key "' + FPasswordAES + '"';
  if FPasswordFranzen <> '' then
    Result := Result + ' -franzen "' + FPasswordFranzen + '"';

  FindVal    := Trim(edtFind.Text);
  ReplaceVal := Trim(edtReplace.Text);
  if FindVal    <> '' then Result := Result + ' -find "'    + FindVal    + '"';
  if ReplaceVal <> '' then Result := Result + ' -replace "' + ReplaceVal + '"';
  Result := Result + ' -catpaqmode';
end;

procedure TfrmExtract.ExecuteCommand;
var
  DestPath, CommandLine: string;
begin
  DestPath := Trim(cmbDestPath.Text);

  if (FMode = emExtract) and (DestPath = '') then
  begin
    ShowMessage(S('msg_enter_dest', 'Please enter or select a destination folder.'));
    cmbDestPath.SetFocus;
    Exit;
  end;

  { cmbDestPath è SEMPRE una cartella: la creiamo se non esiste }
  if DestPath <> '' then
  begin
    if not ForceDirectories(DestPath) then
    begin
      ShowMessage(S('msg_cannot_create_folder', 'Cannot create folder:') +
                  LineEnding + DestPath);
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

  if not ZpaqBridgeMain.LoadExternal then
  begin
    ShowMessage('zpaqfranz not found.');
    Exit;
  end;

  if DestPath <> '' then
    SaveRecentPath(DestPath);

  CommandLine := BuildCommandLine;

  { -force: aggiunto solo se il checkbox "Force overwrite" è spuntato }
  if (FMode = emExtract) and FForceOverwrite then
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
    if FExtractAllMode then
      memLog.Lines.Add('File/Folder: (extract everything)')
    else if FFileNames.Count > 1 then
      memLog.Lines.Add(Format('File/Folder: %d files', [FFileNames.Count]))
    else if FFileName <> '' then
      memLog.Lines.Add('File/Folder: ' + FFileName)
    else
      memLog.Lines.Add('File/Folder: (everything)');
    memLog.Lines.Add('Destination: ' + DestPath);
    if Trim(edtTo.Text) <> '' then
      memLog.Lines.Add('To override: ' + Trim(edtTo.Text));
    if (FVersion > 0) and (FFileNames.Count <= 1) then
      memLog.Lines.Add('Version    : ' + IntToStr(FVersion))
    else
      memLog.Lines.Add('Version    : latest');
    if FForceOverwrite then
      memLog.Lines.Add('Force      : YES (-force)');
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
      Msg := S('msg_extract_ok', 'Extraction completed successfully.') + LineEnding +
             S('extract_lbl_dest_folder', 'Destination folder:') + ' ' +
             Trim(cmbDestPath.Text);
      memLog.Lines.Add(Msg);

      { Determina se la dest è un FILE singolo o una CARTELLA:
        - singolo file (FFileNames.Count=1 e non extract-all) → apri cartella + seleziona file
        - multi-file o extract-all → apri la cartella base }
      if MessageDlg(
           S('msg_extract_ok', 'Extraction completed successfully.') + LineEnding +
           S('extract_lbl_dest_folder', 'Destination:') + ' ' +
           Trim(cmbDestPath.Text) + LineEnding + LineEnding +
           S('msg_open_dest', 'Open destination in Explorer?'),
           mtConfirmation, [mbYes, mbNo], 0, mbNo) = mrYes then
        { cmbDestPath è sempre una cartella }
        OpenDestInExplorer(Trim(cmbDestPath.Text), False);
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
