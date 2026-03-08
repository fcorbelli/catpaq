unit ufrmsimply;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Buttons, MaskEdit, IniFiles, StrUtils, FileUtil, uzpaqbridge, Types,
  Math, Menus, uglobals;

type

  { TfrmSimply }

  TfrmSimply = class(TForm)
    btnmenoonly: TBitBtn;
    btnmenoalways: TBitBtn;
    btnpiunot: TBitBtn;
    btnmenonot: TBitBtn;
    btnArchiveName: TButton;
    btnCancel: TButton;
    btnOK: TButton;
    btnpiuonly: TBitBtn;
    btnpiualways: TBitBtn;
    Button1: TButton;
    chkForce: TCheckBox;
    chkForce1: TCheckBox;
    chkForce10: TCheckBox;
    chkForce11: TCheckBox;
    chkForce12: TCheckBox;
    chkUtc: TCheckBox;
    chkForce14: TCheckBox;
    chkForce15: TCheckBox;
    chkForce16: TCheckBox;
    chkForce2: TCheckBox;
    chkForce3: TCheckBox;
    chkForce4: TCheckBox;
    chkForce5: TCheckBox;
    chkForce6: TCheckBox;
    chkForce7: TCheckBox;
    chkForce8: TCheckBox;
    chkForce9: TCheckBox;
    chkUtc1: TCheckBox;
    chkUtc2: TCheckBox;
    chkUtc3: TCheckBox;
    chkUtc4: TCheckBox;
    cmbArchiveFormat: TComboBox;
    cmbArchiveName: TComboBox;
    cmbCompressionLevel: TComboBox;
    cmbBlocksize: TComboBox;
    cmbMinsize: TComboBox;
    cmbMaxsize: TComboBox;
    cmbnot: TComboBox;
    cmbonly: TComboBox;
    cmbalways: TComboBox;
    cmbThreads: TComboBox;
    cmbHash: TComboBox;
    cmbMultipart: TComboBox;
    cmbChunked: TComboBox;
    cmbDrive: TComboBox;
    cmbFragment: TComboBox;
    edtdateto: TMaskEdit;
    edtPasswordAES1: TEdit;
    edtPasswordAES2: TEdit;
    edtPasswordFranzen1: TEdit;
    edtPasswordFranzen2: TEdit;
    edtDatefrom: TMaskEdit;
    edtTo: TEdit;
    edtFind: TEdit;
    edtReplace: TEdit;
    edtcomment: TEdit;
    lblArchiveFormat: TLabel;
    lblfind: TLabel;
    lblreplace: TLabel;
    lblArchiveFormat3: TLabel;
    lblto: TLabel;
    lblCompressionLevel: TLabel;
    lblCompressionLevel1: TLabel;
    lblCompressionLevel10: TLabel;
    lblCompressionLevel11: TLabel;
    lblCompressionLevel12: TLabel;
    lblCompressionLevel13: TLabel;
    lblCompressionLevel14: TLabel;
    lblCompressionLevel2: TLabel;
    lblCompressionLevel3: TLabel;
    lblCompressionLevel4: TLabel;
    lblCompressionLevel5: TLabel;
    lblCompressionLevel6: TLabel;
    lblCompressionLevel7: TLabel;
    lblCompressionLevel8: TLabel;
    lblCompressionLevel9: TLabel;
    lblAES: TLabel;
    lblFranzen: TLabel;
    edtTimestamp: TMaskEdit;
    memLog: TMemo;
    memHelp: TMemo;
    pgOptions: TPageControl;
    PanelSettings: TPanel;
    pnlFlags: TPanel;
    pnlTo: TPanel;
    pnlTop: TPanel;
    pnlBottom: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    SaveDialog1: TSaveDialog;
    tbLog: TTabSheet;
    tbAdvanced: TTabSheet;
    tbBackup: TTabSheet;
    tbC: TTabSheet;
    tbExternal: TTabSheet;
    tbImage: TTabSheet;
    tbSelection: TTabSheet;
    tbSfx: TTabSheet;
    tbStandard: TTabSheet;
    
    // --- Nuovi Controlli Progress ---
    pnlProgress: TPanel;
    lblGlobalProgress: TLabel;
    pbGlobal: TProgressBar;
    lblFileProgress: TLabel;
    pbFile: TProgressBar;
    btnAbort: TButton;

    procedure btnArchiveNameClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnAbortClick(Sender: TObject);
    procedure cmbArchiveFormatChange(Sender: TObject);
    procedure cmbArchiveNameChange(Sender: TObject);
    procedure cmbCompressionLevelChange(Sender: TObject);
    procedure cmbChunkedChange(Sender: TObject);
    procedure edtFindEnter(Sender: TObject);
    procedure edtToEnter(Sender: TObject);
    procedure edtToExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure pgOptionsChange(Sender: TObject);
    procedure pnlTopResize(Sender: TObject);
    procedure pnlToResize(Sender: TObject);
    procedure tbAdvancedContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure tbSelectionResize(Sender: TObject);
    procedure tbStandardContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure btnpiunotClick(Sender: TObject);
    procedure btnmenonotClick(Sender: TObject);
    procedure btnpiuonlyClick(Sender: TObject);
    procedure btnmenoonly1Click(Sender: TObject);
    procedure btnpiualwaysClick(Sender: TObject);
    procedure btnmenoalways1Click(Sender: TObject);
    procedure tbStandardResize(Sender: TObject);
  private
    FIniFile: TIniFile;
    FIniFileName: string;
    FFilesList: TStringList;
    FInitialFileSize: Int64;
    FOperationCount: Integer;

    FLogPopupMenu: TPopupMenu;
    FSaveLogDialog: TSaveDialog;

    FSavedOnComplete: TZpaqCompleteEvent;
    FSavedOnLog: TZpaqLogEvent;
    FSavedOnProgress: TZpaqProgressEvent; 
    FSavedIsDataMode: Boolean;

    FLogPollTimer: TTimer;
    FOperationStartTime: TDateTime;

    // --- Lingua ---
    FLang:     TStringList;  // key=value coppie dalla lingua corrente
    FLangName: string;       // nome corrente (lowercase)
    function  S(const AKey, ADefault: string): string;
    procedure LoadLanguage(const ALangName: string);
    procedure ApplyLanguage;

    procedure LoadRecentArchives;
    procedure AddToRecentList(const AFileName: string);
    procedure UpdatePasswordFields;
    procedure AdjustArchiveExtension;
    function ValidatePasswords(out ErrorMsg: string): Boolean;
    function GetArchiveFileName: string;
    function BuildCommandLine: string;
    procedure ExecuteAddOperation;
    procedure OnBridgeComplete(Sender: TObject; ExitCode: Integer);
    procedure OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
    procedure OnLogPollTimer(Sender: TObject);
    function NormalizePath(const APath: string): string;
    procedure DbgLog(const AMsg: string);
    procedure AddLogLines(const AMsg: string);
    procedure SaveLogToFile(Sender: TObject);
    procedure RestoreMainBridge;
    function FormatFileSize(const ABytes: Int64): string;
    procedure HookHints(AParent: TWinControl);
    procedure ControlMouseEnter(Sender: TObject);
    procedure LoadWindowSettings;
    procedure SaveWindowSettings;
    function BuildSwitches: string;
  public
    procedure SetFileList(const AFiles: TStringList);
    procedure SaveRecentArchive(const AFileName: string);
    procedure SetDLLPath(const ADLLPath: string);
  end;

var
  frmSimply: TfrmSimply;

implementation

{$R *.lfm}

{ TfrmSimply }

{ ---------------------------------------------------------------------------- }
{ Filter preset helpers — must appear before FormCreate                        }
{ ---------------------------------------------------------------------------- }

procedure LoadFilterPresets(AIni: TIniFile; const ASection: string; ACmb: TComboBox);
var
  i: Integer;
  V: string;
begin
  ACmb.Items.Clear;
  ACmb.Items.Add('NONE');
  i := 1;
  repeat
    V := AIni.ReadString(ASection, 'P' + IntToStr(i), '');
    if V <> '' then
    begin
      ACmb.Items.Add(V);
      Inc(i);
    end;
  until V = '';
  ACmb.ItemIndex := 0;
end;

procedure SaveFilterPresets(AIni: TIniFile; const ASection: string; ACmb: TComboBox);
var
  i, n: Integer;
begin
  AIni.EraseSection(ASection);
  n := 1;
  for i := 0 to ACmb.Items.Count - 1 do
    if not SameText(ACmb.Items[i], 'NONE') then
    begin
      AIni.WriteString(ASection, 'P' + IntToStr(n), ACmb.Items[i]);
      Inc(n);
    end;
  AIni.UpdateFile;
end;

function TfrmSimply.FormatFileSize(const ABytes: Int64): string;
const
  K = 1024;
  M = K * K;
  G = K * M;
begin
  if ABytes < K then Result := IntToStr(ABytes) + ' B'
  else if ABytes < M then Result := Format('%.1f KB', [ABytes / K])
  else if ABytes < G then Result := Format('%.1f MB', [ABytes / M])
  else Result := Format('%.1f GB', [ABytes / G]);
end;

function TfrmSimply.NormalizePath(const APath: string): string;
begin
  Result := StringReplace(APath, '\', '/', [rfReplaceAll]);
end;

procedure TfrmSimply.DbgLog(const AMsg: string);
begin
  memLog.Lines.Add('[DBG] ' + AMsg);
end;

// Split a multi-line string on LineEnding / #13#10 / #10 and add each line,
// skipping internal zpaqfranz progress tokens (@DEC@... / @INC@...)
procedure TfrmSimply.AddLogLines(const AMsg: string);
var
  SL: TStringList;
  i: Integer;
  Line: string;
begin
  SL := TStringList.Create;
  try
    SL.Text := AMsg;
    for i := 0 to SL.Count - 1 do
    begin
      Line := SL[i];
      // Skip zpaqfranz internal progress lines like @DEC@DEC@100@...
      if (Length(Line) > 1) and (Line[1] = '@') then Continue;
      memLog.Lines.Add(Line);
    end;
  finally
    SL.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{  Language support (same INI format as frmMain)                               }
{ ---------------------------------------------------------------------------- }

function TfrmSimply.S(const AKey, ADefault: string): string;
begin
  Result := LangStr(FLang, AKey, ADefault);
end;

procedure TfrmSimply.LoadLanguage(const ALangName: string);
begin
  FLangName := LowerCase(ALangName);
  if not LoadLanguageFile(FLangName, FLang) then
    FLangName := 'english';
  ApplyLanguage;
end;

procedure TfrmSimply.ApplyLanguage;
begin
  // -------------------------------------------------------------------------
  // Tab labels
  // -------------------------------------------------------------------------
  tbStandard.Caption  := S('simply_tab_standard',  'Standard');
  tbAdvanced.Caption  := S('simply_tab_advanced',  'Advanced');
  tbSelection.Caption := S('simply_tab_selection', 'Selection');
  tbSfx.Caption       := S('simply_tab_sfx',       'SFX');
  tbExternal.Caption  := S('simply_tab_external',  'External');
  tbBackup.Caption    := S('simply_tab_backup',    'Backup');
  tbLog.Caption       := S('simply_tab_log',       'Log');

  // -------------------------------------------------------------------------
  // Buttons
  // -------------------------------------------------------------------------
  btnOK.Caption          := S('simply_btn_ok',             'OK');
  btnCancel.Caption      := S('simply_btn_cancel',         'Cancel');
  btnAbort.Caption       := S('simply_btn_abort',          'ABORT');
  btnArchiveName.Caption := S('simply_btn_archive_browse', 'Archive Name');

  // -------------------------------------------------------------------------
  // Save-log popup menu item
  // -------------------------------------------------------------------------
  if Assigned(FLogPopupMenu) and (FLogPopupMenu.Items.Count > 0) then
    FLogPopupMenu.Items[0].Caption := S('simply_save_log', 'Save log to file...');

  // -------------------------------------------------------------------------
  // Hints — for controls whose hint begins with a switch flag ("-xxx ...")
  // the flag prefix is preserved verbatim; only the description is translated.
  // For controls without a switch prefix the whole hint is translated.
  // -------------------------------------------------------------------------

  // --- pnlTop controls ---
  btnOK.Hint :=
    S('hint_btn_ok', 'Start the add-to-archive operation with the current settings');
  btnCancel.Hint :=
    S('hint_btn_cancel', 'Close this window. If an operation is running it will not be interrupted');
  btnArchiveName.Hint :=
    S('hint_btn_archive_name', 'Browse or type a destination archive filename (.zpaq or .zpaq.franzen)');
  cmbArchiveName.Hint :=
    S('hint_cmb_archive_name', 'Path to the target archive. Recent archives are listed here. Type or select one');
  memHelp.Hint :=
    S('hint_mem_help', 'Hover over any control to see its description here');

  // --- pnlTo (path rewrite) ---
  edtTo.Hint      := '-to '      + S('hint_to',      'Replace the stored path prefix with this value.');
  edtFind.Hint    := '-find '    + S('hint_find',    'Path fragment to search for when rewriting internal archive paths.');
  edtReplace.Hint := '-replace ' + S('hint_replace', 'The string that replaces the Find fragment in internal archive paths.');

  // --- pnlFlags checkboxes ---
  chkForce.Hint    := '-force '        + S('hint_force',        'Force add even if files are unchanged.');
  chkForce1.Hint   := '-verbose '      + S('hint_verbose',      'Show detailed output during the operation.');
  chkForce2.Hint   := '-longpath '     + S('hint_longpath',     'Enable support for paths longer than 255 characters in Windows');
  chkForce3.Hint   := '-space '        + S('hint_space',        'Ignore free disk space check before writing the archive.');
  chkForce10.Hint  := '-forcewindows ' + S('hint_forcewindows', 'Force storing Windows stuff');
  chkForce11.Hint  := '-xls '          + S('hint_xls',          'Force compatibility with old Microsoft Office formats (.xls, .doc, .ppt).');
  chkForce14.Hint  := '-vss '          + S('hint_vss',          'Use Volume Shadow Copy Service to back up open/locked files.');
  chkForce16.Hint  := '-nozfs '        + S('hint_nozfs',        'Disable .zfs'' snapshot folders');

  // --- tbStandard ---
  cmbArchiveFormat.Hint  :=
    S('hint_archive_format', 'Archive format: Normal (no encryption), AES (symmetric encryption), Franzen (alternative encryption), or both');
  cmbCompressionLevel.Hint :=
    S('hint_compression_level', 'Compression level: 0=Store (fastest, no compression) up to 5=Top (slowest, best ratio). Default is 1');
  cmbHash.Hint :=
    S('hint_hash', 'Hash algorithm used to verify file integrity inside the archive. XXHASH is fast and recommended');
  cmbMultipart.Hint :=
    S('hint_multipart', 'Multipart mode: split the archive into numbered parts (e.g. _? for up to 9 parts). NO = single archive');
  cmbChunked.Hint :=
    S('hint_chunked', 'Chunked mode: limit each archive chunk to a specific size (useful for optical media or FAT32 drives)');
  chkForce4.Hint  := '-715 '        + S('hint_715',         'Use the zpaq 7.15 file format for compatibility with older tools.');
  chkForce5.Hint  := '-home '       + S('hint_home',        'Store files using only a single-level path relative to home directory.');
  chkForce6.Hint  := '-stdout '     + S('hint_stdout',      'Write archive output to stdout for piping to another process.');
  chkForce12.Hint := '-store '      + S('hint_store',       'Store files without compression (equivalent to level 0).');
  chkForce15.Hint := '-nochecksum ' + S('hint_nochecksum',  'Skip checksum calculation to speed up archiving (less safe).');
  edtcomment.Hint := '-comment '    + S('hint_comment',     'Embed this text as a comment inside the archive.');

  // --- tbAdvanced ---
  cmbThreads.Hint   :=
    S('hint_threads',   'Select the number of concurrent threads');
  cmbFragment.Hint  :=
    S('hint_fragment',  'Select fragment size. Smaller number=smaller size, but higher workload');
  cmbBlocksize.Hint :=
    S('hint_blocksize', 'Average size of blocks');
  edtTimestamp.Hint :=
    S('hint_timestamp', 'Set timestamp of the next version');
  chkUtc.Hint   := '-utc '       + S('hint_utc',       'Force utc time');
  chkUtc1.Hint  := '-touch '     + S('hint_touch',     'Force touch of every file (convert file formats)');
  chkUtc2.Hint  := '-kill '      + S('hint_kill',      'Do dangerous stuff');
  chkUtc3.Hint  := '-zero '      + S('hint_zero',      'Fill with zero the files (for debug)');
  chkUtc4.Hint  := '-collision ' + S('hint_collision', 'Check for SHA-1 collisions');

  // --- tbSelection ---
  cmbMinsize.Hint :=
    S('hint_minsize', 'Minimum file size (ex. 1000, 10M, 20GB)');
  cmbMaxsize.Hint :=
    S('hint_maxsize', 'Maximum file size');
  edtDatefrom.Hint :=
    S('hint_datefrom', 'Minimum date');
  edtdateto.Hint :=
    S('hint_dateto', 'Maximum date');
  cmbnot.Hint :=
    S('hint_not', 'Files to exclude (use space as delimiter)');
  cmbalways.Hint :=
    S('hint_always', 'Files to always add (use space as delimiter)');

  // --- tbLog ---
  memLog.Hint :=
    S('hint_mem_log', 'Operation log: shows commands sent to zpaqfranz and its output. Use right mouse to save to txt');

  // --- btnAbort (progress panel) ---
  btnAbort.Hint :=
    S('hint_btn_abort', 'Immediately terminate the running operation. The archive may be left in an incomplete state');

  // --- Password fields ---
  edtPasswordAES1.Hint     := S('hint_pwd_aes1',     'AES password (first entry). Must match the confirmation field');
  edtPasswordAES2.Hint     := S('hint_pwd_aes2',     'AES password confirmation. Must be identical to the first field');
  edtPasswordFranzen1.Hint := S('hint_pwd_franzen1', 'Franzen password (first entry). Must match the confirmation field');
  edtPasswordFranzen2.Hint := S('hint_pwd_franzen2', 'Franzen password confirmation. Must be identical to the first field');
end;

procedure TfrmSimply.RestoreMainBridge;
begin
  if Assigned(ZpaqBridgeMain) then
  begin
    ZpaqBridgeMain.OnComplete := FSavedOnComplete;
    ZpaqBridgeMain.OnLog      := FSavedOnLog;
    ZpaqBridgeMain.OnProgress := FSavedOnProgress;
    ZpaqBridgeMain.IsDataMode := FSavedIsDataMode;
    DbgLog('RestoreMainBridge: callbacks restored');
  end;
end;

procedure TfrmSimply.FormCreate(Sender: TObject);
var
  MnuSave: TMenuItem;
  SavedLang: string;
begin
  FIniFileName := GetCatpaqIniPath;
  FIniFile     := TIniFile.Create(FIniFileName);

  // --- Lingua: usa la stessa chiave del main (Language/Name) ---
  FLang     := TStringList.Create;
  FLangName := 'english';
  SavedLang := FIniFile.ReadString('Language', 'Name', 'english');
  if (SavedLang <> '') and not SameText(SavedLang, 'english') then
    LoadLanguage(SavedLang);

  FFilesList       := TStringList.Create;
  FInitialFileSize := 0;
  FOperationCount  := 0;

  FSavedOnComplete := nil;
  FSavedOnLog      := nil;
  FSavedOnProgress := nil;
  FSavedIsDataMode := False;

  FLogPollTimer          := TTimer.Create(Self);
  FLogPollTimer.Interval := 150;
  FLogPollTimer.Enabled  := False;
  FLogPollTimer.OnTimer  := @OnLogPollTimer;

  SaveDialog1.Filter :=
    'ZPAQ Archive (*.zpaq)|*.zpaq|' +
    'ZPAQ Franzen Archive (*.zpaq.franzen)|*.zpaq.franzen|' +
    'All Files (*.*)|*.*';
  SaveDialog1.FilterIndex := 1;
  SaveDialog1.DefaultExt  := 'zpaq';

  cmbArchiveFormat.Items.Clear;
  cmbArchiveFormat.Items.Add('Normal');
  cmbArchiveFormat.Items.Add('AES');
  cmbArchiveFormat.Items.Add('Franzen');
  cmbArchiveFormat.Items.Add('AES+Franzen');
  cmbArchiveFormat.ItemIndex := 0;

  cmbCompressionLevel.Items.Clear;
  cmbCompressionLevel.Items.Add('0 (Store)');
  cmbCompressionLevel.Items.Add('1 (Default)');
  cmbCompressionLevel.Items.Add('2 (Fast)');
  cmbCompressionLevel.Items.Add('3 (Slow)');
  cmbCompressionLevel.Items.Add('4 (High)');
  cmbCompressionLevel.Items.Add('5 (Top)');
  cmbCompressionLevel.ItemIndex := 1;

  edtPasswordAES1.PasswordChar     := '*';
  edtPasswordAES2.PasswordChar     := '*';
  edtPasswordFranzen1.PasswordChar := '*';
  edtPasswordFranzen2.PasswordChar := '*';

  Width    := 800;   // valore di design neutro; sovrascitto da LoadWindowSettings/FormShow
  Height   := 600;
  Position := poDesigned;

  btnOK.ModalResult := mrNone;

  LoadRecentArchives;
  UpdatePasswordFields;

  // Load NOT/ONLY/ALWAYS presets from INI
  LoadFilterPresets(FIniFile, 'FilterNot',    cmbnot);
  LoadFilterPresets(FIniFile, 'FilterOnly',   cmbonly);
  LoadFilterPresets(FIniFile, 'FilterAlways', cmbalways);

  // Wire NOT/ONLY/ALWAYS buttons
  btnpiunot.OnClick    := @btnpiunotClick;
  btnmenonot.OnClick   := @btnmenonotClick;
  btnpiuonly.OnClick   := @btnpiuonlyClick;
  btnmenoonly.OnClick  := @btnmenoonly1Click;
  btnpiualways.OnClick := @btnpiualwaysClick;
  btnmenoalways.OnClick:= @btnmenoalways1Click;

  // Make cmbnot editable (user can type directly)
  cmbnot.Style   := csDropDown;
  cmbonly.Style  := csDropDown;
  cmbalways.Style:= csDropDown;



  // Hook all visual controls so hovering shows their Hint in memHelp
  HookHints(Self);

  // --- Log context menu: right-click -> Save log to file ---
  FSaveLogDialog := TSaveDialog.Create(Self);
  FSaveLogDialog.Title      := 'Save log to file';
  FSaveLogDialog.Filter     := 'Text files (*.txt)|*.txt|Log files (*.log)|*.log|All files (*.*)|*.*';
  FSaveLogDialog.DefaultExt := 'txt';
  FSaveLogDialog.Options    := FSaveLogDialog.Options + [ofOverwritePrompt];

  FLogPopupMenu := TPopupMenu.Create(Self);
  MnuSave := TMenuItem.Create(FLogPopupMenu);
  MnuSave.Caption := 'Save log to file...';
  MnuSave.OnClick := @SaveLogToFile;
  FLogPopupMenu.Items.Add(MnuSave);
end;

procedure TfrmSimply.FormDestroy(Sender: TObject);
begin
  FLogPollTimer.Enabled := False;

  RestoreMainBridge;

  if Trim(cmbArchiveName.Text) <> '' then
    SaveRecentArchive(cmbArchiveName.Text);

  FFilesList.Free;
  FLang.Free;
  FIniFile.Free;
end;

procedure TfrmSimply.FormShow(Sender: TObject);
begin
  // Geometria finestra (Screen.WorkArea affidabile solo qui)
  LoadWindowSettings;

  // Applica stringhe lingua ai componenti
  ApplyLanguage;

  if cmbArchiveName.CanFocus then
    cmbArchiveName.SetFocus;
  pgOptions.ActivePageIndex := 0;

  // Assign log popup here — after full form construction
  memLog.PopupMenu := FLogPopupMenu;

  // Setup initial Progress Panel
  pnlProgress.Visible := False;
end;

procedure TfrmSimply.pgOptionsChange(Sender: TObject);
begin
end;

procedure TfrmSimply.pnlTopResize(Sender: TObject);
var
  mywidth:integer;
begin
  cmbarchivename.width:=tpanel(sender).width-cmbarchivename.left-10;
  mywidth:=tpanel(sender).width-lblaes.width-lblfranzen.width-100;
  mywidth:=mywidth div 4;
  edtpasswordAES1.width:=mywidth;
  edtpasswordAES2.width:=mywidth;
  edtpasswordfranzen1.width:=mywidth;
  edtpasswordfranzen2.width:=mywidth;

  edtpasswordAES1.left:=cmbarchivename.left;
  edtpasswordAES2.left:=edtpasswordaes1.left+edtpasswordaes1.width+4;
  lblfranzen.left:=edtpasswordaes2.left+edtpasswordaes2.width+4;
  edtpasswordfranzen1.left:=lblfranzen.left+lblfranzen.width+4;
  edtpasswordfranzen2.left:=edtpasswordfranzen1.left+edtpasswordfranzen2.width;
end;

procedure TfrmSimply.pnlToResize(Sender: TObject);
var
  mywidth:integer;
begin
  mywidth:=tpanel(sender).width-lblto.width-lblfind.width-lblreplace.width-20*4;
  mywidth:=mywidth div 3;
  edtto.width:=mywidth;
  edtfind.width:=mywidth;
  edtreplace.width:=mywidth;

  edtto.left:=lblto.left+lblto.width+4;
  lblfind.left:=edtto.left+edtto.width+4;
  edtfind.left:=lblfind.left+lblfind.width+4;
  lblreplace.left:=edtfind.left+edtfind.width+4;
  edtreplace.left:=lblreplace.left+lblreplace.width+4;
end;

procedure TfrmSimply.tbAdvancedContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin

end;

procedure TfrmSimply.tbSelectionResize(Sender: TObject);
begin
  cmbnot.width:=ttabsheet(sender).width-cmbnot.left-10;
  cmbonly.width:=ttabsheet(sender).width-cmbonly.left-10;
  cmbalways.width:=ttabsheet(sender).width-cmbalways.left-10;

end;

procedure TfrmSimply.tbStandardContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: Boolean);
begin
end;

{ ---------------------------------------------------------------------------- }
{ Public interface                                                              }
{ ---------------------------------------------------------------------------- }

procedure TfrmSimply.SetDLLPath(const ADLLPath: string);
begin
end;

procedure TfrmSimply.SetFileList(const AFiles: TStringList);
begin
  FFilesList.Clear;
  FFilesList.AddStrings(AFiles);

  memLog.Lines.Clear;
  memLog.Lines.Add('=== Files to Add ===');
  memLog.Lines.Add('');
  memLog.Lines.AddStrings(AFiles);
  memLog.Lines.Add('');
  memLog.Lines.Add('Total: ' + IntToStr(AFiles.Count) + ' item(s)');
  memLog.Lines.Add('');
end;

procedure TfrmSimply.SaveRecentArchive(const AFileName: string);
var
  i: Integer;
begin
  if AFileName = '' then Exit;
  AddToRecentList(AFileName);
  for i := 0 to cmbArchiveName.Items.Count - 1 do
    if i < 10 then
      FIniFile.WriteString('RecentArchives', 'File' + IntToStr(i + 1),
                           cmbArchiveName.Items[i]);
  FIniFile.UpdateFile;
end;

{ ---------------------------------------------------------------------------- }
{ Private helpers                                                               }
{ ---------------------------------------------------------------------------- }

procedure TfrmSimply.LoadRecentArchives;
var
  i: Integer;
  FileName: string;
begin
  cmbArchiveName.Items.Clear;
  for i := 1 to 10 do
  begin
    FileName := FIniFile.ReadString('RecentArchives', 'File' + IntToStr(i), '');
    if FileName <> '' then
      cmbArchiveName.Items.Add(FileName);
  end;
  if cmbArchiveName.Items.Count > 0 then
    cmbArchiveName.ItemIndex := 0;
end;

procedure TfrmSimply.AddToRecentList(const AFileName: string);
var
  idx: Integer;
begin
  idx := cmbArchiveName.Items.IndexOf(AFileName);
  if idx >= 0 then
    cmbArchiveName.Items.Delete(idx);
  cmbArchiveName.Items.Insert(0, AFileName);
  cmbArchiveName.ItemIndex := 0;
  while cmbArchiveName.Items.Count > 10 do
    cmbArchiveName.Items.Delete(cmbArchiveName.Items.Count - 1);
end;

procedure TfrmSimply.UpdatePasswordFields;
var
  FormatIdx: Integer;
begin
  FormatIdx := cmbArchiveFormat.ItemIndex;
  case FormatIdx of
    0:
    begin
      lblAES.Visible     := False;
      edtPasswordAES1.Visible     := False;
      edtPasswordAES2.Visible     := False;
      lblFranzen.Visible := False;
      edtPasswordFranzen1.Visible := False;
      edtPasswordFranzen2.Visible := False;
    end;
    1:
    begin
      lblAES.Visible     := True;
      edtPasswordAES1.Visible     := True;
      edtPasswordAES2.Visible     := True;
      lblFranzen.Visible := False;
      edtPasswordFranzen1.Visible := False;
      edtPasswordFranzen2.Visible := False;
    end;
    2:
    begin
      lblAES.Visible     := False;
      edtPasswordAES1.Visible     := False;
      edtPasswordAES2.Visible     := False;
      lblFranzen.Visible := True;
      edtPasswordFranzen1.Visible := True;
      edtPasswordFranzen2.Visible := True;
    end;
    3:
    begin
      lblAES.Visible     := True;
      edtPasswordAES1.Visible     := True;
      edtPasswordAES2.Visible     := True;
      lblFranzen.Visible := True;
      edtPasswordFranzen1.Visible := True;
      edtPasswordFranzen2.Visible := True;
    end;
  end;
  AdjustArchiveExtension;
end;

procedure TfrmSimply.AdjustArchiveExtension;
const
  // All multipart suffixes that zpaqfranz accepts — longest first so stripping
  // works correctly (e.g. strip "_????????" before trying "_?")
  MULTIPART_SUFFIXES: array[0..4] of string = (
    '_????????', '_????', '_???', '_??', '_?'
  );
var
  FileName, BaseName, MultipartSuffix, FinalExt, ItemText: string;
  FormatIdx, MultiIdx, k: Integer;
  SpacePos: Integer;
begin
  FileName := Trim(cmbArchiveName.Text);
  if FileName = '' then Exit;

  // --- 1. Strip known extension (.zpaq.franzen or .zpaq) ---
  if EndsText('.zpaq.franzen', FileName) then
    BaseName := Copy(FileName, 1, Length(FileName) - 14)
  else if EndsText('.zpaq', FileName) then
    BaseName := Copy(FileName, 1, Length(FileName) - 5)
  else
    BaseName := FileName;

  // --- 2. Strip any existing multipart suffix from BaseName ---
  for k := Low(MULTIPART_SUFFIXES) to High(MULTIPART_SUFFIXES) do
    if EndsText(MULTIPART_SUFFIXES[k], BaseName) then
    begin
      BaseName := Copy(BaseName, 1,
                       Length(BaseName) - Length(MULTIPART_SUFFIXES[k]));
      Break;
    end;

  // --- 3. Determine new multipart suffix from cmbMultipart ---
  // Items: 0="(NO-single archive)", 1="_? (9 PARTS)", 2="_?? (99 PARTS)" …
  // The suffix is the first token (before the first space) of each item,
  // except item 0 which means "no suffix".
  MultipartSuffix := '';
  MultiIdx := cmbMultipart.ItemIndex;
  if MultiIdx > 0 then
  begin
    ItemText := cmbMultipart.Items[MultiIdx];
    SpacePos := Pos(' ', ItemText);
    if SpacePos > 0 then
      MultipartSuffix := Copy(ItemText, 1, SpacePos - 1)
    else
      MultipartSuffix := ItemText;
  end;

  // --- 4. Determine extension from cmbArchiveFormat ---
  FormatIdx := cmbArchiveFormat.ItemIndex;
  if (FormatIdx = 2) or (FormatIdx = 3) then
    FinalExt := '.zpaq.franzen'
  else
    FinalExt := '.zpaq';

  // --- 5. Rebuild filename: base + multipart_suffix + extension ---
  cmbArchiveName.Text := BaseName + MultipartSuffix + FinalExt;
end;

function TfrmSimply.ValidatePasswords(out ErrorMsg: string): Boolean;
var
  FormatIdx: Integer;
begin
  Result    := True;
  ErrorMsg  := '';
  FormatIdx := cmbArchiveFormat.ItemIndex;

  if (FormatIdx = 1) or (FormatIdx = 3) then
  begin
    if Trim(edtPasswordAES1.Text) = '' then
    begin
      ErrorMsg := 'AES password cannot be empty';
      Result   := False;
      Exit;
    end;
    if edtPasswordAES1.Text <> edtPasswordAES2.Text then
    begin
      ErrorMsg := 'AES passwords do not match';
      Result   := False;
      Exit;
    end;
  end;

  if (FormatIdx = 2) or (FormatIdx = 3) then
  begin
    if Trim(edtPasswordFranzen1.Text) = '' then
    begin
      ErrorMsg := 'Franzen password cannot be empty';
      Result   := False;
      Exit;
    end;
    if edtPasswordFranzen1.Text <> edtPasswordFranzen2.Text then
    begin
      ErrorMsg := 'Franzen passwords do not match';
      Result   := False;
      Exit;
    end;
  end;
end;

function TfrmSimply.GetArchiveFileName: string;
begin
  Result := Trim(cmbArchiveName.Text);
  if Result = '' then
    Result := 'archive.zpaq';
end;

{ ---------------------------------------------------------------------------- }
{ Switch builder: scans all TCheckBox with Tag=1, uses first word of Hint     }
{ as the switch flag (e.g. "-715" from "-715 Use the zpaq 7.15 file format.") }
{ ---------------------------------------------------------------------------- }

function TfrmSimply.BuildSwitches: string;

  procedure ScanContainer(AParent: TWinControl);
  var
    i: Integer;
    Ctrl: TControl;
    chk: TCheckBox;
    HintText, SwitchFlag: string;
    SpacePos: Integer;
  begin
    for i := 0 to AParent.ControlCount - 1 do
    begin
      Ctrl := AParent.Controls[i];
      if (Ctrl is TCheckBox) and (Ctrl.Tag = 1) then
      begin
        chk := TCheckBox(Ctrl);
        if chk.Checked then
        begin
          HintText := Trim(chk.Hint);
          // Format: "-switch optional description"
          // Extract the first token (the switch itself)
          SpacePos := Pos(' ', HintText);
          if SpacePos > 0 then
            SwitchFlag := Copy(HintText, 1, SpacePos - 1)
          else
            SwitchFlag := HintText;
          if SwitchFlag <> '' then
            Result := Result + ' ' + SwitchFlag;
        end;
      end;
      if Ctrl is TWinControl then
        ScanContainer(TWinControl(Ctrl));
    end;
  end;

begin
  Result := '';
  ScanContainer(Self);
end;

{ ---------------------------------------------------------------------------- }
{ Helper: returns first token (before first space) of a combo item text        }
{ ---------------------------------------------------------------------------- }
function FirstToken(const S: string): string;
var SpacePos: Integer;
begin
  SpacePos := Pos(' ', S);
  if SpacePos > 0 then Result := Copy(S, 1, SpacePos - 1)
  else Result := S;
end;

{ ---------------------------------------------------------------------------- }
{ Helper: check if a string looks like a valid date fragment                   }
{ Accepted: YYYY, YYYYMM, YYYY-MM-DD (separators optional)                    }
{ ---------------------------------------------------------------------------- }
function IsReasonableDate(const S: string): Boolean;
var
  Cleaned: string;
  i: Integer;
begin
  Result := False;
  // Remove common separators
  Cleaned := '';
  for i := 1 to Length(S) do
    if (Ord(S[i]) >= Ord('0')) and (Ord(S[i]) <= Ord('9')) then
      Cleaned := Cleaned + S[i];
  // Must be 4 (year), 6 (YYYYMM) or 8 (YYYYMMDD) digits
  if not (Length(Cleaned) in [4, 6, 8]) then Exit;
  // Year sanity
  if StrToIntDef(Copy(Cleaned, 1, 4), 0) < 1900 then Exit;
  Result := True;
end;

{ ---------------------------------------------------------------------------- }
{ Helper: check if a MaskEdit timestamp is filled (not all spaces/underscores) }
{ and returns the formatted value for -timestamp                                }
{ ---------------------------------------------------------------------------- }
function ExtractTimestamp(const S: string): string;
var
  Cleaned: string;
  i: Integer;
begin
  Result := '';
  Cleaned := '';
  for i := 1 to Length(S) do
    if (Ord(S[i]) >= Ord('0')) and (Ord(S[i]) <= Ord('9')) then
      Cleaned := Cleaned + S[i];
  // Need at least 8 digits (DDMMYYYY)
  if Length(Cleaned) < 8 then Exit;
  // Rebuild as YYYY-MM-DD or YYYY-MM-DD HH:MM:SS
  // MaskEdit format: DD/MM/YYYY HH:MM:SS
  // Cleaned digits: D1D2 M1M2 Y1Y2Y3Y4 [H1H2 m1m2 s1s2]
  if Length(Cleaned) >= 8 then
    Result := Copy(Cleaned,5,4)+'-'+Copy(Cleaned,3,2)+'-'+Copy(Cleaned,1,2);
  if Length(Cleaned) >= 14 then
    Result := Result + ' ' + Copy(Cleaned,9,2)+':'+Copy(Cleaned,11,2)+':'+Copy(Cleaned,13,2);
end;

{ ---------------------------------------------------------------------------- }
{ Helper: extract date from MaskEdit (DD/MM/YYYY) -> YYYY-MM-DD               }
{ ---------------------------------------------------------------------------- }
function ExtractDateField(const S: string): string;
var
  Cleaned: string;
  i: Integer;
begin
  Result := '';
  Cleaned := '';
  for i := 1 to Length(S) do
    if (Ord(S[i]) >= Ord('0')) and (Ord(S[i]) <= Ord('9')) then
      Cleaned := Cleaned + S[i];
  if Length(Cleaned) < 8 then Exit;
  // DD MM YYYY
  Result := Copy(Cleaned,5,4)+'-'+Copy(Cleaned,3,2)+'-'+Copy(Cleaned,1,2);
  if not IsReasonableDate(Result) then Result := '';
end;

{ ---------------------------------------------------------------------------- }
{ Helper: expand a space-separated pattern list into repeated -switch tokens   }
{ e.g. '*.cpp *.txt' with switch '-not' -> '-not *.cpp -not *.txt'            }
{ ---------------------------------------------------------------------------- }
function ExpandPatterns(const SwitchName, Patterns: string): string;
var
  SL: TStringList;
  i: Integer;
  Pat: string;
begin
  Result := '';
  Pat := Trim(Patterns);
  if (Pat = '') or (SameText(Pat, 'NONE')) then Exit;
  SL := TStringList.Create;
  try
    SL.Delimiter := ' ';
    SL.StrictDelimiter := True;
    SL.DelimitedText := Pat;
    for i := 0 to SL.Count - 1 do
    begin
      if Trim(SL[i]) <> '' then
        Result := Result + ' ' + SwitchName + ' ' + Trim(SL[i]);
    end;
  finally
    SL.Free;
  end;
end;

function TfrmSimply.BuildCommandLine: string;
var
  I, CompressionLevel, FormatIdx: Integer;
  ChunkText, ChunkVal: string;
  ThreadIdx: Integer;
  FragIdx: Integer;
  BlockIdx: Integer;
  TSVal: string;
  DateFromVal, DateToVal: string;
  MinVal, MaxVal: string;
  NotText, OnlyText, AlwaysText: string;
  ArchiveName: string;
begin
  // ----- Chunked: must be resolved FIRST so archive name gets ? suffix -----
  if cmbChunked.ItemIndex > 0 then
  begin
    ChunkText := cmbChunked.Items[cmbChunked.ItemIndex];
    ChunkVal  := FirstToken(ChunkText);
    // If multipart not yet chosen, force _????????
    if cmbMultipart.ItemIndex = 0 then
      cmbMultipart.ItemIndex := 5; // _???????? (LOTS)
    AdjustArchiveExtension; // updates cmbArchiveName.Text with the ? suffix
  end;

  ArchiveName := NormalizePath(GetArchiveFileName);
  Result := 'a "' + ArchiveName + '"';

  for I := 0 to FFilesList.Count - 1 do
    Result := Result + ' "' + NormalizePath(FFilesList[I]) + '"';

  // ----- Compression level -----
  CompressionLevel := cmbCompressionLevel.ItemIndex;
  if CompressionLevel < 0 then CompressionLevel := 1;

  // ----- Block size: appended to -m flag -----
  BlockIdx := cmbBlocksize.ItemIndex;
  if BlockIdx > 0 then
    Result := Result + ' -m' + IntToStr(CompressionLevel) + FirstToken(cmbBlocksize.Items[BlockIdx])
  else
    Result := Result + ' -m' + IntToStr(CompressionLevel);

  // ----- Format / passwords -----
  FormatIdx := cmbArchiveFormat.ItemIndex;
  if (FormatIdx = 1) or (FormatIdx = 3) then
    Result := Result + ' -key "' + edtPasswordAES1.Text + '"';
  if (FormatIdx = 2) or (FormatIdx = 3) then
    Result := Result + ' -franzen "' + edtPasswordFranzen1.Text + '"';

  // ----- Chunked switch (value already computed above) -----
  if cmbChunked.ItemIndex > 0 then
    Result := Result + ' -chunk ' + ChunkVal;

  // ----- Threads -----
  // Items: 'MAX','1','2',...
  ThreadIdx := cmbThreads.ItemIndex;
  if ThreadIdx > 0 then // 0 = MAX (no flag)
    Result := Result + ' -t' + cmbThreads.Items[ThreadIdx];

  // ----- Fragment -----
  // Items: 'DEFAULT','0 1kb','1 2kb',...
  FragIdx := cmbFragment.ItemIndex;
  if FragIdx > 0 then
    Result := Result + ' -fragment ' + FirstToken(cmbFragment.Items[FragIdx]);

  // ----- Timestamp -----
  TSVal := ExtractTimestamp(edtTimestamp.Text);
  if TSVal <> '' then
    Result := Result + ' -timestamp ' + TSVal;

  // ----- Minsize / Maxsize -----
  if cmbMinsize.ItemIndex > 0 then
  begin
    MinVal := cmbMinsize.Items[cmbMinsize.ItemIndex];
    Result := Result + ' -minsize ' + MinVal;
  end;
  if cmbMaxsize.ItemIndex > 0 then
  begin
    MaxVal := cmbMaxsize.Items[cmbMaxsize.ItemIndex];
    Result := Result + ' -maxsize ' + MaxVal;
  end;

  // ----- Datefrom / Dateto -----
  DateFromVal := ExtractDateField(edtDatefrom.Text);
  if DateFromVal <> '' then
    Result := Result + ' -datefrom ' + DateFromVal;
  DateToVal := ExtractDateField(edtdateto.Text);
  if DateToVal <> '' then
    Result := Result + ' -dateto ' + DateToVal;

  // ----- -to / -find / -replace -----
  if Trim(edtTo.Text) <> '' then
    Result := Result + ' -to "' + Trim(edtTo.Text) + '"';
  if Trim(edtFind.Text) <> '' then
    Result := Result + ' -find "' + Trim(edtFind.Text) + '"';
  if Trim(edtReplace.Text) <> '' then
    Result := Result + ' -replace "' + Trim(edtReplace.Text) + '"';
  if Trim(edtcomment.Text) <> '' then
    Result := Result + ' -comment "' + Trim(edtcomment.Text) + '"';

  // ----- NOT / ONLY / ALWAYS patterns -----
  NotText   := Trim(cmbnot.Text);
  OnlyText  := Trim(cmbonly.Text);
  AlwaysText := Trim(cmbalways.Text);
  Result := Result + ExpandPatterns('-not',    NotText);
  Result := Result + ExpandPatterns('-only',   OnlyText);
  Result := Result + ExpandPatterns('-always', AlwaysText);

  // ----- All checked switches (Tag=1 checkboxes) -----
  Result := Result + BuildSwitches;

  Result := Result + ' -catpaqmode';
end;

procedure TfrmSimply.OnLogPollTimer(Sender: TObject);
var
  LogBuf: TStringList;
  i: Integer;
begin
  if not Assigned(ZpaqBridgeMain) then Exit;
  LogBuf := ZpaqBridgeMain.FlushLogBuffer;
  try
    for i := 0 to LogBuf.Count - 1 do
      AddLogLines(LogBuf[i]);
  finally
    LogBuf.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Execution using main bridge directly                                         }
{ ---------------------------------------------------------------------------- }

procedure TfrmSimply.ExecuteAddOperation;
var
  ArchiveFile, CommandLine: string;
begin
  Inc(FOperationCount);
  DbgLog('ExecuteAddOperation #' + IntToStr(FOperationCount));

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
    ShowMessage('zpaqfranz executable not found.');
    Exit;
  end;

  ArchiveFile := GetArchiveFileName;
  SaveRecentArchive(ArchiveFile);

  if FileExists(ArchiveFile) then
    FInitialFileSize := FileUtil.FileSize(ArchiveFile)
  else
    FInitialFileSize := 0;

  pgOptions.ActivePage := tbLog;

  memLog.Lines.Add('');
  memLog.Lines.Add('=== Starting Add Operation #' + IntToStr(FOperationCount) + ' ===');
  memLog.Lines.Add('Archive: ' + ArchiveFile);
  if FInitialFileSize > 0 then
    memLog.Lines.Add('Current size: ' + IntToStr(FInitialFileSize) +
                     ' bytes  (file will be updated)')
  else
    memLog.Lines.Add('Archive does not exist yet  (will be created from scratch)');
  memLog.Lines.Add('');

  CommandLine := BuildCommandLine;
  memLog.Lines.Add('Command: zpaqfranz ' + CommandLine);
  memLog.Lines.Add('');

  FSavedOnComplete := ZpaqBridgeMain.OnComplete;
  FSavedOnLog      := ZpaqBridgeMain.OnLog;
  FSavedOnProgress := ZpaqBridgeMain.OnProgress;
  FSavedIsDataMode := ZpaqBridgeMain.IsDataMode;

  ZpaqBridgeMain.OnLog      := nil;
  ZpaqBridgeMain.OnProgress := @OnBridgeProgress;
  ZpaqBridgeMain.OnComplete := @OnBridgeComplete;
  ZpaqBridgeMain.IsDataMode := False;

  // Progress UI setup
  pnlProgress.Visible := True;
  pbGlobal.Position := 0;
  pbFile.Position := 0;
  pbFile.Visible := False;
  lblFileProgress.Visible := False;
  lblGlobalProgress.Caption := 'Preparing operation...';
  
  btnOK.Enabled     := False;
  btnCancel.Enabled := False; // Prevent accidental close while command is running
  btnAbort.Enabled  := True;
  btnAbort.Visible  := True;
  FLogPollTimer.Enabled := True;
  FOperationStartTime   := Now;

  if not ZpaqBridgeMain.RunCommandAsync(CommandLine) then
  begin
    DbgLog('ERROR: RunCommandAsync returned False!');
    FLogPollTimer.Enabled := False;
    btnOK.Enabled         := True;
    btnCancel.Enabled     := True;
    btnAbort.Enabled      := False;
    RestoreMainBridge;
    memLog.Lines.Add('ERROR: Failed to execute zpaqfranz');
    ShowMessage('Failed to execute zpaqfranz.');
  end
  else
    DbgLog('RunCommandAsync started OK');
end;

procedure TfrmSimply.btnAbortClick(Sender: TObject);
begin
  if Assigned(ZpaqBridgeMain) and ZpaqBridgeMain.Busy then
  begin
    if MessageDlg('Warning', 'Are you sure you want to forcibly abort the current operation?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      DbgLog('Abort requested by user.');
      ZpaqBridgeMain.AbortCommand;
      btnAbort.Enabled := False;
      lblGlobalProgress.Caption := 'Cancelling operation...';
    end;
  end;
end;

procedure TfrmSimply.OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
var
  ETASec, ETAHours, ETAMins, ETASecs: Integer;
  ETAStr: string;

  function Pad2(N: Integer): string;
  begin
    Result := IntToStr(N);
    if Length(Result) < 2 then Result := '0' + Result;
  end;

begin
  ETASec   := ZpaqBridgeMain.ProgETA;
  ETAHours := ETASec div 3600;
  ETAMins  := (ETASec mod 3600) div 60;
  ETASecs  := ETASec mod 60;

  if ETASec > 0 then
    ETAStr := 'ETA: ' + Pad2(ETAHours) + ':' + Pad2(ETAMins) + ':' + Pad2(ETASecs)
  else
    ETAStr := 'ETA: --:--:--';

  Self.Caption := Format('Add to Archive - %d%%  %s', [Percent, ETAStr]);

  pbGlobal.Position := Percent;

  if ZpaqBridgeMain.ProgTotali > 0 then
    lblGlobalProgress.Caption := Format('Global progress: %d%%  -  Processed: %s / %s  (%s)',
      [Percent,
       FormatFileSize(ZpaqBridgeMain.ProgLavorati),
       FormatFileSize(ZpaqBridgeMain.ProgTotali),
       ETAStr])
  else
    lblGlobalProgress.Caption := Format('Global progress: %d%%  (%s)', [Percent, ETAStr]);

  // Current file progress bar
  if ZpaqBridgeMain.ProgFilePerc > 0 then
  begin
    pbFile.Visible          := True;
    lblFileProgress.Visible := True;
    pbFile.Position         := ZpaqBridgeMain.ProgFilePerc;
    lblFileProgress.Caption := Format('Current file: %d%%', [ZpaqBridgeMain.ProgFilePerc]);
  end
  else
  begin
    pbFile.Visible          := False;
    lblFileProgress.Visible := False;
  end;
end;

procedure TfrmSimply.OnBridgeComplete(Sender: TObject; ExitCode: Integer);
var
  ArchiveFile: string;
  FinalFileSize, SizeDiff: Int64;
  LogBuf: TStringList;
  Msg: string;
  ElapsedSec: Double;
  SpeedStr: string;
  j: Integer;
begin
  DbgLog('OnBridgeComplete: ExitCode=' + IntToStr(ExitCode));

  FLogPollTimer.Enabled := False;
  btnAbort.Enabled      := False;
  btnOK.Enabled         := True;
  btnCancel.Enabled     := True;

  // Elapsed time since operation start
  ElapsedSec := (Now - FOperationStartTime) * 86400.0;
  if ElapsedSec < 0.001 then ElapsedSec := 0.001;

  if Assigned(ZpaqBridgeMain) then
  begin
    LogBuf := ZpaqBridgeMain.FlushLogBuffer;
    try
      if LogBuf.Count > 0 then
      begin
        for j := 0 to LogBuf.Count - 1 do
          AddLogLines(LogBuf[j]);
      end;
    finally
      LogBuf.Free;
    end;
  end;

  memLog.Lines.Add('');
  memLog.Lines.Add('--- Operation complete --- Exit code: ' + IntToStr(ExitCode));

  if ExitCode = 0 then
  begin
    pbGlobal.Position         := 100;
    lblGlobalProgress.Caption := 'Operation completed successfully.';
    pbFile.Visible            := False;
    lblFileProgress.Visible   := False;
    pbGlobal.Position         := 0;
    pbFile.Position            := 0;
    btnAbort.Visible           := False;
  end
  else
  begin
    lblGlobalProgress.Caption     := 'Operation failed or cancelled by user.';
    lblGlobalProgress.Font.Color  := clRed;
  end;

  RestoreMainBridge;

  if ExitCode <> 0 then
  begin
    memLog.Lines.Add('ERROR: operation failed (exit code ' + IntToStr(ExitCode) + ')');
    ShowMessage('Operation failed (exit code ' + IntToStr(ExitCode) +
                '). Check the log for details.');
    Exit;
  end;

  ArchiveFile := GetArchiveFileName;
  if FileExists(ArchiveFile) then
  begin
    FinalFileSize := FileUtil.FileSize(ArchiveFile);

    if FInitialFileSize = 0 then
    begin
      // Speed based on total archive size written
      if ElapsedSec > 0 then
        SpeedStr := FormatFileSize(Round(FinalFileSize / ElapsedSec)) + '/s'
      else
        SpeedStr := 'N/A';

      Msg := 'Created new archive from scratch.' + LineEnding +
             'Archive size  : ' + FormatFileSize(FinalFileSize) +
               ' (' + IntToStr(FinalFileSize) + ' bytes)' + LineEnding +
             'Elapsed time  : ' + Format('%.1f s', [ElapsedSec]) + LineEnding +
             'Average speed : ' + SpeedStr;
    end
    else
    begin
      SizeDiff := FinalFileSize - FInitialFileSize;

      if ElapsedSec > 0 then
        SpeedStr := FormatFileSize(Round(Abs(SizeDiff) / ElapsedSec)) + '/s'
      else
        SpeedStr := 'N/A';

      Msg := 'Archive updated.' + LineEnding +
             'Previous size : ' + FormatFileSize(FInitialFileSize) +
               ' (' + IntToStr(FInitialFileSize) + ' bytes)' + LineEnding +
             'New size      : ' + FormatFileSize(FinalFileSize) +
               ' (' + IntToStr(FinalFileSize) + ' bytes)' + LineEnding +
             'Delta         : ' + FormatFileSize(SizeDiff) +
               ' (' + IntToStr(SizeDiff) + ' bytes)' + LineEnding +
             'Elapsed time  : ' + Format('%.1f s', [ElapsedSec]) + LineEnding +
             'Average speed : ' + SpeedStr;
    end;

    memLog.Lines.Add('');
    AddLogLines(Msg);
    ShowMessage(Msg);
  end
  else
    memLog.Lines.Add('WARNING: archive file not found after operation.');
end;

{ ---------------------------------------------------------------------------- }
{ Event handlers                                                                }
{ ---------------------------------------------------------------------------- }

procedure TfrmSimply.btnArchiveNameClick(Sender: TObject);
begin
  if cmbArchiveName.Text <> '' then
  begin
    SaveDialog1.FileName   := cmbArchiveName.Text;
    SaveDialog1.InitialDir := ExtractFileDir(cmbArchiveName.Text);
  end
  else
  begin
    SaveDialog1.InitialDir := GetCurrentDir;
    SaveDialog1.FileName   := 'archive.zpaq';
  end;
  if SaveDialog1.Execute then
    cmbArchiveName.Text := SaveDialog1.FileName;
end;

procedure TfrmSimply.btnHelpClick(Sender: TObject);
begin
  ShowMessage('Catpaq - Add Files to Archive' + LineEnding + LineEnding +
              'Select an archive file name and configure options.' + LineEnding +
              'Files to add are shown in the Base tab.');
end;

procedure TfrmSimply.btnOKClick(Sender: TObject);
var
  ErrorMsg, ArchiveFile: string;
begin
  if Assigned(ZpaqBridgeMain) and ZpaqBridgeMain.Busy then
  begin
    ShowMessage('Operation in progress, please wait.');
    Exit;
  end;

  ArchiveFile := Trim(cmbArchiveName.Text);
  if ArchiveFile = '' then
  begin
    ShowMessage('Please enter an archive filename');
    cmbArchiveName.SetFocus;
    Exit;
  end;

  if not (EndsText('.zpaq', ArchiveFile) or
          EndsText('.zpaq.franzen', ArchiveFile)) then
  begin
    ShowMessage('Archive must have .zpaq or .zpaq.franzen extension');
    cmbArchiveName.SetFocus;
    Exit;
  end;

  if not ValidatePasswords(ErrorMsg) then
  begin
    ShowMessage(ErrorMsg);
    Exit;
  end;

  if FFilesList.Count = 0 then
  begin
    ShowMessage('No files to add');
    Exit;
  end;

  ExecuteAddOperation;
end;

procedure TfrmSimply.cmbArchiveFormatChange(Sender: TObject);
begin
  UpdatePasswordFields;
end;

procedure TfrmSimply.cmbArchiveNameChange(Sender: TObject);
begin
  AdjustArchiveExtension;
end;

procedure TfrmSimply.cmbCompressionLevelChange(Sender: TObject);
begin
  // cmbMultipart (multipart) changes the archive filename suffix
  if Sender = cmbMultipart then
    AdjustArchiveExtension;
end;

procedure TfrmSimply.cmbChunkedChange(Sender: TObject);
begin
  if cmbChunked.ItemIndex > 0 then
  begin
    // Force _???????? multipart whenever a chunk size is active
    cmbMultipart.ItemIndex := 5;
  end;
  AdjustArchiveExtension;
end;

procedure TfrmSimply.edtFindEnter(Sender: TObject);
begin

end;

procedure TfrmSimply.edtToEnter(Sender: TObject);
begin
  tedit(sender).color:=clyellow;
end;

procedure TfrmSimply.edtToExit(Sender: TObject);
begin
  tedit(sender).color:=cldefault;
end;


{ ---------------------------------------------------------------------------- }
{ Hint hover system                                                             }
{ ---------------------------------------------------------------------------- }

procedure TfrmSimply.ControlMouseEnter(Sender: TObject);
var
  Ctrl: TControl;
  HintText: string;
begin
  if not (Sender is TControl) then Exit;
  Ctrl := TControl(Sender);

  // Skip memHelp itself to avoid recursive/distracting updates
  if Ctrl = memHelp then Exit;

  HintText := Trim(Ctrl.Hint);
  if HintText <> '' then
    memHelp.Text := HintText
  else
    memHelp.Text := '(' + Ctrl.Name + ')';
end;

procedure TfrmSimply.HookHints(AParent: TWinControl);
var
  i: Integer;
  Ctrl: TControl;
begin
  for i := 0 to AParent.ControlCount - 1 do
  begin
    Ctrl := AParent.Controls[i];

    // Attach mouse-enter handler
    if Ctrl is TButton      then TButton(Ctrl).OnMouseEnter      := @ControlMouseEnter
    else if Ctrl is TBitBtn then TBitBtn(Ctrl).OnMouseEnter      := @ControlMouseEnter
    else if Ctrl is TEdit   then TEdit(Ctrl).OnMouseEnter        := @ControlMouseEnter
    else if Ctrl is TComboBox then TComboBox(Ctrl).OnMouseEnter  := @ControlMouseEnter
    else if Ctrl is TCheckBox then TCheckBox(Ctrl).OnMouseEnter  := @ControlMouseEnter
    else if Ctrl is TMemo   then TMemo(Ctrl).OnMouseEnter        := @ControlMouseEnter
    else if Ctrl is TProgressBar then TProgressBar(Ctrl).OnMouseEnter := @ControlMouseEnter
    else if Ctrl is TPageControl then TPageControl(Ctrl).OnMouseEnter := @ControlMouseEnter;

    // Recurse into containers
    if Ctrl is TWinControl then
      HookHints(TWinControl(Ctrl));
  end;
end;

procedure TfrmSimply.LoadWindowSettings;
const
  SANE_MIN_W = 400;
  SANE_MIN_H = 300;
var
  L, T, Wd, Ht: Integer;
begin
  if not Assigned(FIniFile) then
  begin
    // Nessun INI: applica default
    Width  := Screen.WorkAreaWidth  * 8 div 10;
    Height := Screen.WorkAreaHeight * 7 div 10;
    Left   := Screen.WorkAreaLeft + (Screen.WorkAreaWidth  - Width)  div 2;
    Top    := Screen.WorkAreaTop  + (Screen.WorkAreaHeight - Height) div 2;
    Exit;
  end;

  L  := FIniFile.ReadInteger('SimplyWindow', 'Left',   -1);
  T  := FIniFile.ReadInteger('SimplyWindow', 'Top',    -1);
  Wd := FIniFile.ReadInteger('SimplyWindow', 'Width',   0);
  Ht := FIniFile.ReadInteger('SimplyWindow', 'Height',  0);

  if (Wd >= SANE_MIN_W) and (Ht >= SANE_MIN_H) then
  begin
    // Clamp all'area di lavoro (esclude taskbar Windows 11)
    if Wd > Screen.WorkAreaWidth  then Wd := Screen.WorkAreaWidth;
    if Ht > Screen.WorkAreaHeight then Ht := Screen.WorkAreaHeight;
    if L < Screen.WorkAreaLeft then L := Screen.WorkAreaLeft;
    if T < Screen.WorkAreaTop  then T := Screen.WorkAreaTop;
    if L + Wd > Screen.WorkAreaLeft + Screen.WorkAreaWidth then
      L := Max(Screen.WorkAreaLeft, Screen.WorkAreaLeft + Screen.WorkAreaWidth  - Wd);
    if T + Ht > Screen.WorkAreaTop  + Screen.WorkAreaHeight then
      T := Max(Screen.WorkAreaTop,  Screen.WorkAreaTop  + Screen.WorkAreaHeight - Ht);
    Position := poDesigned;
    Left   := L;
    Top    := T;
    Width  := Wd;
    Height := Ht;
  end
  else
  begin
    // Nessun valore valido in INI: applica default 80% x 70% WorkArea
    Width  := Screen.WorkAreaWidth  * 8 div 10;
    Height := Screen.WorkAreaHeight * 7 div 10;
    Left   := Screen.WorkAreaLeft + (Screen.WorkAreaWidth  - Width)  div 2;
    Top    := Screen.WorkAreaTop  + (Screen.WorkAreaHeight - Height) div 2;
  end;
end;

procedure TfrmSimply.SaveWindowSettings;
begin
  if not Assigned(FIniFile) then Exit;
  if WindowState = wsNormal then
  begin
    FIniFile.WriteInteger('SimplyWindow', 'Left',   Left);
    FIniFile.WriteInteger('SimplyWindow', 'Top',    Top);
    FIniFile.WriteInteger('SimplyWindow', 'Width',  Width);
    FIniFile.WriteInteger('SimplyWindow', 'Height', Height);
  end;
end;

{ ---------------------------------------------------------------------------- }
{ NOT / ONLY / ALWAYS preset management                                        }
{ ---------------------------------------------------------------------------- }

// Load saved presets from INI into a combobox (keeping 'NONE' as first item)
// Generic + button: ask user for a pattern string, add if not duplicate
procedure TfrmSimply.btnpiunotClick(Sender: TObject);
var
  Val: string;
begin
  Val := Trim(InputBox(S('simply_not_preset_title',  'NOT preset'),
                       S('simply_not_preset_prompt', 'Enter pattern(s) to add (e.g. *.tmp *.bak):'), ''));
  if Val = '' then Exit;
  if cmbnot.Items.IndexOf(Val) < 0 then
    cmbnot.Items.Add(Val);
  cmbnot.Text := Val;
  SaveFilterPresets(FIniFile, 'FilterNot', cmbnot);
end;

procedure TfrmSimply.btnmenonotClick(Sender: TObject);
var
  idx: Integer;
begin
  idx := cmbnot.Items.IndexOf(cmbnot.Text);
  if (idx > 0) then // never delete index 0 = 'NONE'
  begin
    cmbnot.Items.Delete(idx);
    cmbnot.ItemIndex := 0;
    SaveFilterPresets(FIniFile, 'FilterNot', cmbnot);
  end;
end;

procedure TfrmSimply.btnpiuonlyClick(Sender: TObject);
var
  Val: string;
begin
  Val := Trim(InputBox(S('simply_only_preset_title',  'ONLY preset'),
                       S('simply_only_preset_prompt', 'Enter pattern(s) to add (e.g. *.cpp *.h):'), ''));
  if Val = '' then Exit;
  if cmbonly.Items.IndexOf(Val) < 0 then
    cmbonly.Items.Add(Val);
  cmbonly.Text := Val;
  SaveFilterPresets(FIniFile, 'FilterOnly', cmbonly);
end;

procedure TfrmSimply.btnmenoonly1Click(Sender: TObject);
var
  idx: Integer;
begin
  idx := cmbonly.Items.IndexOf(cmbonly.Text);
  if (idx > 0) then
  begin
    cmbonly.Items.Delete(idx);
    cmbonly.ItemIndex := 0;
    SaveFilterPresets(FIniFile, 'FilterOnly', cmbonly);
  end;
end;

procedure TfrmSimply.btnpiualwaysClick(Sender: TObject);
var
  Val: string;
begin
  Val := Trim(InputBox(S('simply_always_preset_title',  'ALWAYS preset'),
                       S('simply_always_preset_prompt', 'Enter pattern(s) to add (e.g. *.doc *.xls):'), ''));
  if Val = '' then Exit;
  if cmbalways.Items.IndexOf(Val) < 0 then
    cmbalways.Items.Add(Val);
  cmbalways.Text := Val;
  SaveFilterPresets(FIniFile, 'FilterAlways', cmbalways);
end;

procedure TfrmSimply.btnmenoalways1Click(Sender: TObject);
var
  idx: Integer;
begin
  idx := cmbalways.Items.IndexOf(cmbalways.Text);
  if (idx > 0) then
  begin
    cmbalways.Items.Delete(idx);
    cmbalways.ItemIndex := 0;
    SaveFilterPresets(FIniFile, 'FilterAlways', cmbalways);
  end;
end;

procedure TfrmSimply.tbStandardResize(Sender: TObject);
begin
  edtcomment.width:=ttabsheet(sender).width-edtcomment.left-10;
end;

procedure TfrmSimply.SaveLogToFile(Sender: TObject);
begin
  FSaveLogDialog.FileName := 'catpaq_log.txt';
  if FSaveLogDialog.Execute then
    memLog.Lines.SaveToFile(FSaveLogDialog.FileName);
end;

procedure TfrmSimply.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // Se c'è un'operazione in corso, chiedi conferma prima di chiudere
  if Assigned(ZpaqBridgeMain) and ZpaqBridgeMain.Busy then
  begin
    if MessageDlg(S('simply_msg_op_in_progress',
                    'Operation in progress. Abort and close?'),
                  mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      CloseAction := caNone; // annulla la chiusura
      Exit;
    end;
    // L'utente ha confermato: interrompe l'operazione
    ZpaqBridgeMain.AbortCommand;
    // Piccola attesa per permettere al thread di terminare pulitamente
    Sleep(200);
    Application.ProcessMessages;
  end;

  SaveWindowSettings;
end;

end.
