
unit ufrmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Menus, Clipbrd, IniFiles, LCLType, LCLIntf, FileInfo, Process,
  {$IFDEF WINDOWS}
  Registry, Windows, ShellApi, dynlibs,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  laz.VirtualTrees,
  uzpaqbridge, ucatpaqtypes, ucatpaq_update, ucatpaq_sha256, ufrmsimply, ufrmextract,
  uglobals;

const
  MIN_FORM_WIDTH  = 600;
  MIN_FORM_HEIGHT = 400;
  ZOOM_MIN = 50;
  ZOOM_MAX = 250;
  ZOOM_DEFAULT = 100;

  // Altezze base di riferimento (a zoom 100%)
  BASE_H_ARCHIVE_INFO = 62;
  BASE_H_TRACKBAR     = 50;
  BASE_H_CERCA        = 94;
  BASE_H_BOTTONI      = 102;

  // SHA256 hash atteso dell'eseguibile - AGGIORNATO AUTOMATICAMENTE da aggiorna.exe

  // @@EXE_HASH_START@@
  EXPECTED_EXE_HASH = '4b71592f3bd17c9ddc7f8f1ad891ada0943b271ea236ebb15894bf4f33822c89';
  // @@EXE_HASH_END@@

  // @@XP_HASH_START@@
  EXPECTED_XP_HASH = '9507065bca616dcd6dfcc8985018b8b8b69ad874e29d44801f9e4f705cb4b046';
  // @@XP_HASH_END@@

var
  // Password da riga di comando (globali per uso CLI-style)
  password_aes: string = '';
  password_franzen: string = '';

type
  TTreeMode = (tmAllVersions, tmSingleVersion);

  PNodeData = ^TNodeData;
  TNodeData = record
    FileIndex: Integer;
    VersionIndex: Integer;
    IsParent: Boolean;
    IsHidden: Boolean;
  end;

  TFileExplorerItem = record
    Name: string;
    FullPath: string;
    IsDirectory: Boolean;
    Size: Int64;
    Modified: TDateTime;
    Created: TDateTime;
    Attributes: Integer;
  end;

  { TfrmMain }
  TfrmMain = class(TForm)
    btnExit2: TButton;
    btnHelp1: TButton;
    btnAssociate: TButton;
    btnBrowseBuild: TButton;
    btnChangeTreeFont: TButton;
    btnDisassociate: TButton;
    btnInternetUpdate: TButton;
    btnOpen: TButton;
    btnTimeMachine: TButton;
    cbLanguage: TComboBox;
    edtFilter: TEdit;
    FontDialog1: TFontDialog;
    gbFileAssoc: TGroupBox;
    gbFont: TGroupBox;
    gbLanguage: TGroupBox;
    gbLinks: TGroupBox;
    gbZoom: TGroupBox;
    Image1: TImage;
    lblLoadingETA: TLabel;
    lblAdminStatus: TLabel;
    lblArchiveInfo: TLabel;
    lblCurrentFont: TLabel;
    lblFileCount: TLabel;
    lblFilter: TLabel;
    lblFilterInfo: TLabel;
    lblLoadInfo: TLabel;
    lblZoomValue: TLabel;
    MemoLog: TMemo;
    memArchive: TMemo;
    pnlLoading: TPanel;
    pgrProgressLog: TProgressBar;
    itmLastversion: TMenuItem;
    itmAll: TMenuItem;
    mnuExtractFileGUI: TMenuItem;
    mnuExtractFileText: TMenuItem;
    mnuExtractFolderGUI: TMenuItem;
    mnuExtractFolderText: TMenuItem;
    mnuCopyFileName: TMenuItem;
    mnuCopyFullPath: TMenuItem;
    mnuExpandAll: TMenuItem;
    mnuCollapseAll: TMenuItem;
    mnuHideFolder: TMenuItem;
    mnuHideTree: TMenuItem;
    mnuShowAll: TMenuItem;
    mnuSep1: TMenuItem;
    mnuSep2: TMenuItem;
    mnuSep3: TMenuItem;
    mnuSep4: TMenuItem;
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    pnlCerca: TPanel;
    pnlBottoni: TPanel;
    PanelBottom: TPanel;
    pgrProgresso: TProgressBar;
    PopupMenu1: TPopupMenu;
    popTest: TPopupMenu;
    pgrLoading: TProgressBar;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    TabArchive: TTabSheet;
    TabLog: TTabSheet;
    TabSettings: TTabSheet;
    TabAdd: TTabSheet;
    tbInfo: TTabSheet;
    tbZoom: TTrackBar;
    TimerUpdate: TTimer;
    btnAbortLoading: TToggleBox;
    TrackBar1: TTrackBar;
    VST: TLazVirtualStringTree;

    // Tab Add components
    pnlAddToolbar: TPanel;
    pnlAddFilter: TPanel;
    pnlAddNav: TPanel;
    lvAddFiles: TLazVirtualStringTree;
    btnAddAdd: TButton;
    btnAddExtract: TButton;
    btnAddTest: TButton;
    lblAddFilter: TLabel;
    edtAddFilter: TEdit;
    lblAddPath: TLabel;
    edtAddPath: TEdit;
    btnAddUp: TButton;
    btnAddRefresh: TButton;
    cmbAddDrives: TComboBox;
    PopupMenuAdd: TPopupMenu;
    mnuAddFilesToZpaq: TMenuItem;
    mnuAddAllToZpaq: TMenuItem;
    mnuAddExtractToFolder: TMenuItem;
    mnuAddBrowseVersions: TMenuItem;
    mnuAddTestZpaq: TMenuItem;
    mnuAddTestAllZpaq: TMenuItem;
    mnuAddSep1b: TMenuItem;
    mnuAddSep1: TMenuItem;
    mnuAddOpen: TMenuItem;
    mnuAddOpenInExplorer: TMenuItem;
    mnuAddSep2: TMenuItem;
    mnuAddRename: TMenuItem;
    mnuAddDelete: TMenuItem;
    mnuAddCreateFolder: TMenuItem;
    mnuAddSep3: TMenuItem;
    mnuAddProperties: TMenuItem;
    mnuAddSep4: TMenuItem;
    mnuAddHash: TMenuItem;
    mnuHashCRC32: TMenuItem;
    mnuHashXXHash: TMenuItem;
    mnuHashSHA1: TMenuItem;
    mnuHashSHA256: TMenuItem;
    mnuHashXXH3: TMenuItem;
    mnuHashBLAKE3: TMenuItem;
    mnuHashSHA3: TMenuItem;
    mnuHashMD5: TMenuItem;
    mnuHashWhirlpool: TMenuItem;
    mnuHashHighway64: TMenuItem;
    mnuHashHighway128: TMenuItem;
    mnuHashHighway256: TMenuItem;
    mnuHashWyhash: TMenuItem;
    mnuHashNilsimsa: TMenuItem;
    mnuHashEntropy: TMenuItem;
    mnuHashQuick: TMenuItem;
    mnuHashZeta: TMenuItem;
    mnuHashFranzMulti: TMenuItem;
    mnuHashFranzSingle: TMenuItem;
    mnuExtractAll: TMenuItem;
    mnuSep5: TMenuItem;
    PopupMenuArchiveBrowse: TPopupMenu;
    mnuArchiveBack: TMenuItem;
    mnuArchiveSep1: TMenuItem;
    mnuArchiveExtract1: TMenuItem;   // Extract... (lista selezionati)
    mnuArchiveExtractAll: TMenuItem; // Extract all... (tutto l'archivio)
    mnuArchiveSep2: TMenuItem;
    mnuArchiveExtract2: TMenuItem;   // Test

    procedure btnAbortLoadingClick(Sender: TObject);
    procedure btnExit2Click(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure btnTimeMachineClick(Sender: TObject);
    procedure btnAssociateClick(Sender: TObject);
    procedure btnDisassociateClick(Sender: TObject);
    procedure btnChangeTreeFontClick(Sender: TObject);
    procedure btnBrowseBuildClick(Sender: TObject);
    procedure btnInternetUpdateClick(Sender: TObject);
    procedure cbLanguageChange(Sender: TObject);
    procedure edtFilterKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure OnTimerSave(Sender: TObject);
    procedure OnTimerRestore(Sender: TObject);
    procedure itmAllClick(Sender: TObject);
    procedure itmLastversionClick(Sender: TObject);
    procedure mnuExtractFileGUIClick(Sender: TObject);
    procedure mnuExtractFileTextClick(Sender: TObject);
    procedure mnuExtractFolderGUIClick(Sender: TObject);
    procedure mnuExtractFolderTextClick(Sender: TObject);
    procedure mnuExtractAllClick(Sender: TObject);
    procedure PopupMenuArchiveBrowsePopup(Sender: TObject);
    procedure mnuArchiveBackClick(Sender: TObject);
    procedure mnuArchiveExtract1Click(Sender: TObject);
    procedure mnuArchiveExtractAllClick(Sender: TObject);
    procedure mnuArchiveExtract2Click(Sender: TObject);
    procedure mnuCopyFileNameClick(Sender: TObject);
    procedure mnuCopyFullPathClick(Sender: TObject);
    procedure mnuExpandAllClick(Sender: TObject);
    procedure mnuCollapseAllClick(Sender: TObject);
    procedure mnuHideFolderClick(Sender: TObject);
    procedure mnuHideTreeClick(Sender: TObject);
    procedure mnuShowAllClick(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure PanelBottomResize(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure TimerUpdateTimer(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure tbZoomChange(Sender: TObject);
    procedure VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
    procedure VSTGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure VSTInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var ChildCount: Cardinal);
    procedure VSTInitNode(Sender: TBaseVirtualTree; ParentNode,
      Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
    procedure VSTBeforeCellPaint(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      CellPaintMode: TVTCellPaintMode; var CellRect: TRect; var ContentRect: TRect);
    procedure VSTPaintText(Sender: TBaseVirtualTree;
      const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType);
    procedure VSTMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure VSTKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure VSTHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);

    // Tab Add events
    procedure btnAddAddClick(Sender: TObject);
    procedure btnAddExtractClick(Sender: TObject);
    procedure btnAddTestClick(Sender: TObject);
    procedure edtAddFilterKeyPress(Sender: TObject; var Key: Char);
    procedure edtAddPathKeyPress(Sender: TObject; var Key: Char);
    procedure btnAddUpClick(Sender: TObject);
    procedure btnAddRefreshClick(Sender: TObject);
    procedure cmbAddDrivesChange(Sender: TObject);
    procedure lvAddFilesDblClick(Sender: TObject);
    procedure lvAddFilesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lvAddFilesMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    // VST handlers for lvAddFiles (replaces TListView handlers)
    procedure lvAddFilesGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
    procedure lvAddFilesInitNode(Sender: TBaseVirtualTree; ParentNode,
      Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
    procedure lvAddFilesPaintText(Sender: TBaseVirtualTree;
      const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType);
    procedure lvAddFilesHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
    procedure lvAddFilesFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex);
    procedure PopupMenuAddPopup(Sender: TObject);
    procedure mnuAddFilesToZpaqClick(Sender: TObject);
    procedure mnuAddAllToZpaqClick(Sender: TObject);
    procedure mnuAddExtractToFolderClick(Sender: TObject);
    procedure mnuAddBrowseVersionsClick(Sender: TObject);
    procedure mnuAddTestZpaqClick(Sender: TObject);
    procedure mnuAddTestAllZpaqClick(Sender: TObject);
    procedure mnuAddOpenClick(Sender: TObject);
    procedure mnuAddOpenInExplorerClick(Sender: TObject);
    procedure mnuAddRenameClick(Sender: TObject);
    procedure mnuAddDeleteClick(Sender: TObject);
    procedure mnuAddCreateFolderClick(Sender: TObject);
    procedure mnuAddPropertiesClick(Sender: TObject);
    procedure mnuHashClick(Sender: TObject);

    procedure OnTimerStartup(Sender: TObject);

    procedure chkAutoUpdateClick(Sender: TObject);

  private
    FArchivePath: string;
    FArchiveType: TArchiveType;
    FArchiveData: TArchiveData;
    FBridge: TZpaqBridge;
    FTreeMode: TTreeMode;
    FCurrentVersion: Integer;
    FFilterText: string;
    FFilteredFiles: array of Integer;
    FCommandLineFile: string;
    FPasswordKey: string;
    FPasswordFranzen: string;
    FIniPath: string;
    FHiddenPaths: TStringList;
    FHiddenTrees: TStringList;
    FLoadStartTime: TDateTime;
    FBaseFont: string;
    FBaseFontSize: Integer;
    FZoomPercent: Integer;
    FLang: TStringList;
    FLangName: string;

    FTimerStartup: TTimer;
    FApplyDefaultSize: Boolean; // True = nessun INI trovato, ridimensiona in FormShow
    FFormReady:        Boolean; // True dopo il restore iniziale: abilita salvataggio
    FTimerSave:        TTimer;  // polling 2s: salva se posizione/colonne cambiate
    FTimerRestore:     TTimer;  // one-shot 150ms: applica geometria INI dopo FormShow

    // --- Checkbox "Check for updates at startup" (creato a runtime) ---
    chkAutoUpdate: TCheckBox;
    FAutoUpdateCheck: Boolean; // True = controlla aggiornamenti all'avvio
    // Geometria finestra letta dall'INI, da applicare via FTimerRestore
    FRestoredLeft:   Integer;
    FRestoredTop:    Integer;
    FRestoredWidth:  Integer;
    FRestoredHeight: Integer;
    // Snapshot dell'ultimo stato salvato (per rilevare cambiamenti)
    FLastSavedLeft:   Integer;
    FLastSavedTop:    Integer;
    FLastSavedWidth:  Integer;
    FLastSavedHeight: Integer;
    // Snapshot larghezze colonne per rilevare cambiamenti
    FLastColWidthsLv:  array[0..7] of Integer;
    FLastColWidthsVst: array[0..7] of Integer;
    // Larghezze lette dall'INI: riapplicate in OnTimerRestore dopo SetBounds
    // (LCL le riscala quando la form si ridimensiona, quindi vanno riapplicate dopo)
    FSavedColWidthsLv:  array[0..7] of Integer;
    FSavedColWidthsVst: array[0..7] of Integer;

    // --- State Management ---
    FBridgeOp: string; // 'LIST' or 'HASH' or 'TEST'
    FHashFileCount: Integer;
    FTestProgressLineIndex: Integer; // index of the in-place progress line in MemoLog (-1 = not yet added)
    FLoadingArchive: Boolean; // True = caricamento archivio in corso → ignora ulteriori doppi click
    FLogProgressLineIndex: Integer; // index of the in-place Scan progress line in MemoLog (-1 = not yet added)
    FFileListAbortRequested: Boolean; // True = utente ha premuto Abort durante listing file temporaneo
    FTempListFile: string; // Path del file temporaneo generato dal listing
    FKeepTempFiles: Boolean; // True = non cancellare i file temporanei (debug)
    FLoadFromBrowseTab: Boolean; // True = caricamento avviato dalla tab Browse (mostra pnlLoading)

    // --- Pannello Abort nella TabLog (creato a runtime) ---
    pnlLogToolbar: TPanel;
    btnAbortLoad:  TButton;
    lblLogStatus:  TLabel;

    // --- Componenti generati a runtime per evitare EReadError ---
    pmLog: TPopupMenu;       // Popup per MemoLog (dati sistema)
    mnuSaveLog: TMenuItem;
    mnuLogBack: TMenuItem;
    mnuLogClear: TMenuItem;
    pmArchive: TPopupMenu;   // Popup per memArchive (dati archivio)
    mnuSaveArchive: TMenuItem;
    mnuArchiveLogBack: TMenuItem;
    mnuClearArchive: TMenuItem;
    SaveDialogLog: TSaveDialog;
    mnuHashSep: TMenuItem;
    mnuHashSSD: TMenuItem;

    // Tab Add private fields
    FCurrentAddPath: string;

    // --- Modalità browse archivio nel file selector ---
    FArchiveBrowseMode: Boolean;     // True = stiamo mostrando contenuto archivio
    FArchiveBrowsePath: string;      // Path dell'archivio aperto in browse
    FAddFilesList: array of TFileExplorerItem;

    // --- Sort state per lvAddFiles ---
    FLvSortColumn: Integer;      // indice colonna corrente (-1 = nessuna)
    FLvSortAscending: Boolean;

    // --- Sort state per VST (file list archivio) ---
    FVstSortColumn: Integer;     // indice colonna corrente (-1 = nessuna)
    FVstSortAscending: Boolean;

    procedure CleanLogBuffer(ABuffer: TStringList);
    procedure mnuSaveLogClick(Sender: TObject);
    procedure mnuLogBackClick(Sender: TObject);
    procedure mnuLogClearClick(Sender: TObject);
    procedure mnuSaveArchiveClick(Sender: TObject);
    procedure mnuArchiveLogBackClick(Sender: TObject);
    procedure mnuClearArchiveClick(Sender: TObject);
    procedure MemoLogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnAbortLoadClick(Sender: TObject);
    procedure SetLoadingState(ALoading: Boolean);
    procedure OnFileListComplete(Data: PtrInt);
    procedure FileListGuiUpdate(Data: PtrInt);
    procedure DoLoadArchive(const AFileName: string);
    procedure ShowArchiveBrowse(const AArchivePath: string; const AData: TArchiveData);
    procedure AddArchiveLog(const AMsg: string);  { scrive nel memArchive }
    procedure ExitArchiveBrowseMode;
    procedure AskPasswords;
    procedure RunPakkaList;
    procedure OnBridgeComplete(Sender: TObject; ExitCode: Integer);
    procedure OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
    procedure BuildFilteredList;
    procedure RebuildTree;
    procedure SetupTrackBar;
    procedure UpdateTimeMachineCaption;
    procedure AddLog(const AMsg: string);
    procedure HandleDownloadProgress(Downloaded, Total: Int64);
    function GetFileDisplayIndex(TreeIndex: Integer): Integer;
    function BuildCommandString: string;
    function SplitDateTime(const FullDate: string; WantTime: Boolean): string;
    function FormatChildLine(const FV: TFileVersion): string;
    function FormatFileSize(const ABytes: Int64): string;
    function FormatETA(ATotalSeconds: Int64): string;
    function GetFocusedVersion(out FE: TArchiveFileEntry; out FV: TFileVersion): Boolean;
    function IsFocusedNodeFolder: Boolean;
    procedure DoExtractTo(const DestFolder: string);
    function IsPathHidden(const APath: string): Boolean;
    procedure HideFolderOnly(const APath: string);
    procedure HideTree(const APath: string);
    procedure ShowAllHidden;
    procedure LoadSettingsFromIni;
    procedure SaveSettingsToIni;
    procedure UpdateFontLabel;
    function IsRunningAsAdmin: Boolean;
    procedure ApplyZoom(APercent: Integer);
    procedure UpdateZoomLabel;
    procedure UpdateTreeRowHeight;
    function S(const AKey, ADefault: string): string;
    procedure LoadLanguage(const ALangName: string);
    procedure ScanLanguages;
    procedure ApplyLanguage;
    procedure DoStartupUpdateCheck;   { controlla aggiornamenti all'avvio }

    function IsZpaqFile(const AFileName: string): Boolean;
    procedure UpdateZpaqButtons;
    function GetSelectedZpaqPath: string;
    function TryDownloadExternal: Boolean;
    function ExecuteStartupChecks: Boolean; // True = OK, False = errore/avviso
    function ValidateEXE: Boolean;
    function ValidateXP: Boolean;
    procedure SortLvAddFiles(AColumn: Integer; AAscending: Boolean);
    procedure SortFilteredFiles(AColumn: Integer; AAscending: Boolean);

    // Tab Add private methods
    procedure InitAddTab;
    procedure PopulateAddDrives;
    procedure NavigateToPath(const APath: string);
    procedure RefreshAddFilesList;
    procedure ApplyAddFilter(const AFilter: string);
    function BuildSelectedFilesString: string;
    function BuildAllFilesString: string;
    function HasOnlyFoldersSelected: Boolean;
    function IsCaseSensitiveFS: Boolean;
    procedure OpenSelectedFile;
    procedure OpenInExplorer;
    procedure OpenZpaqFile(const AFilePath: string);
    procedure ShowAddDialog(AFilesList: TStringList);
    procedure ShowExtractDialog;
    procedure ShowExtractAllDialog;
    procedure ShowTestDialog(const AArchivePath: string);

  public
    procedure LoadArchiveFromCommandLine(const AFileName: string);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}
{ === LISTING TRAMITE FILE TEMPORANEO SU DISCO (via -out di zpaqfranz) ===
  zpaqfranz scrive i dati direttamente sul file temporaneo tramite -out.
  Le righe di progresso vanno su stderr (il pipe), il thread le intercetta.
  Metodo predefinito su tutte le piattaforme. }

{ Helper per dimensione file senza dipendenze extra }
function FileSizeByName(const AFileName: string): Int64;
var SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin Result := SR.Size; SysUtils.FindClose(SR); end;
end;

{ === Helper: restituisce l'indice in FAddFilesList del nodo focused, o -1 === }
function LvGetFocusedIndex(ATree: TLazVirtualStringTree): Integer;
var N: PVirtualNode;
begin
  Result := -1;
  N := ATree.FocusedNode;
  if N = nil then Exit;
  Result := N^.Index;
end;

{ === Helper: restituisce il Name dell'item focused, o '' === }
function LvGetFocusedName(ATree: TLazVirtualStringTree; const AList: array of TFileExplorerItem): string;
var Idx: Integer;
begin
  Result := '';
  Idx := LvGetFocusedIndex(ATree);
  if (Idx >= 0) and (Idx < Length(AList)) then
    Result := AList[Idx].Name;
end;

{ === Helper: conta i nodi selezionati === }
function LvSelectedCount(ATree: TLazVirtualStringTree): Integer;
var N: PVirtualNode;
begin
  Result := 0;
  N := ATree.GetFirstSelected;
  while N <> nil do
  begin
    Inc(Result);
    N := ATree.GetNextSelected(N);
  end;
end;

type
  { Thread che esegue zpaqfranz con -out in background, leggendo stderr
    per le righe di progresso e notificando la GUI in tempo reale. }
  TFileListThread = class(TThread)
  private
    FBridge:     TZpaqBridge;
    FCommand:    string;
    FTempFile:   string;
    FSuccess:    Boolean;
    FExitCode:   Integer;
    FStderrLog:  TStringList;   { accumula le righe stderr per il log }
  protected
    procedure Execute; override;
  public
    constructor Create(ABridge: TZpaqBridge; const ACommand, ATempFile: string);
    destructor Destroy; override;
    property TempFile:  string      read FTempFile;
    property Success:   Boolean     read FSuccess;
    property ExitCode:  Integer     read FExitCode;
    property StderrLog: TStringList read FStderrLog;
  end;

var
  FileListThread: TFileListThread = nil;

{ === DEBUG: file di log per il listing via file temporaneo === }
var
  FileListDbgFile: string = '';

procedure FileListDbgWrite(const ALine: string);
var F: TextFile;
begin
  { Scrive SEMPRE, non solo in DebugMode — è debug temporaneo }
  if FileListDbgFile = '' then
    FileListDbgFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
                        'catpaq_filelist_debug.txt';
  AssignFile(F, FileListDbgFile);
  {$I-}
  if FileExists(FileListDbgFile) then Append(F) else Rewrite(F);
  if IOResult = 0 then begin Writeln(F, FormatDateTime('hh:nn:ss.zzz', Now) + ' ' + ALine); Flush(F); CloseFile(F); end;
  {$I+}
end;
{ === FINE HELPERS DEBUG === }

{ === TFileListThread === }

constructor TFileListThread.Create(ABridge: TZpaqBridge; const ACommand, ATempFile: string);
begin
  inherited Create(True); // CreateSuspended
  FBridge     := ABridge;
  FCommand    := ACommand;
  FTempFile   := ATempFile;
  FSuccess    := False;
  FExitCode   := -1;
  FStderrLog  := TStringList.Create;
  FreeOnTerminate := False;
end;

destructor TFileListThread.Destroy;
begin
  FreeAndNil(FStderrLog);
  inherited;
end;

procedure TFileListThread.Execute;
const
  BufSize = 4096;
var
  Proc: TProcess;
  Buffer: array[0..BufSize - 1] of Byte;
  BytesRead, I: Integer;
  LineAccum: string;
  Ch: Char;
  S, PercStr: string;
  Percent, LastPercent, WPos: Integer;
  SPKParts: TStringArray;
begin
  FileListDbgWrite('TFileListThread.Execute: START');
  FileListDbgWrite('  Command=' + FCommand);
  FileListDbgWrite('  TempFile=' + FTempFile);
  FileListDbgWrite('  ExePath=' + FBridge.ExternalPath);

  LastPercent := -1;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := FBridge.ExternalPath;

    { Costruisci la command line: comando originale + -out tempfile }
    {$IFDEF WINDOWS}
    Proc.Parameters.AddText(FCommand + ' -out "' + FTempFile + '"');
    Proc.Options := [poUsePipes, poNoConsole, poStderrToOutPut];
    {$ELSE}
    SplitCmdToParams(FCommand + ' -out "' + FTempFile + '"', Proc.Parameters);
    Proc.Options := [poUsePipes, poStderrToOutPut];
    {$ENDIF}

    FileListDbgWrite('  Full command line: ' + FCommand + ' -out "' + FTempFile + '"');

    try
      Proc.Execute;
      FileListDbgWrite('  Process started. PID=' + IntToStr(Proc.ProcessID));

      { Legge stderr (che arriva via il pipe stdout+stderr merged).
        zpaqfranz con -out scrive i dati nel file e il progresso sul pipe.
        Intercettiamo le righe "W NNN%" per aggiornare la progress bar.
        Tutte le righe vengono accumulate in FStderrLog per il log. }
      LineAccum := '';

      repeat
        if Terminated then Break;

        BytesRead := 0;
        try
          if Proc.Output.NumBytesAvailable > 0 then
            BytesRead := Proc.Output.Read(Buffer, BufSize)
          else if Proc.Running then
            Sleep(10)
          else
          begin
            { Processo terminato: svuota gli ultimi byte rimasti nel pipe }
            BytesRead := Proc.Output.Read(Buffer, BufSize);
            if BytesRead <= 0 then Break;
          end;
        except
          Break;
        end;

        { Processa byte per byte per estrarre le righe }
        for I := 0 to BytesRead - 1 do
        begin
          Ch := Char(Buffer[I]);
          if Ch = #10 then
          begin
            { Strip trailing CR }
            if (Length(LineAccum) > 0) and (LineAccum[Length(LineAccum)] = #13) then
              SetLength(LineAccum, Length(LineAccum) - 1);

            S := LineAccum;
            LineAccum := '';

            if S = '' then Continue;

            FileListDbgWrite('  PIPE: [' + S + ']');

            { Accumula per il log della GUI (ma NON le righe @SPK@ di telemetria) }
            if Pos('@SPK@', S) <> 1 then
              FStderrLog.Add(S);

            { === Intercetta telemetria @SPK@DEC@ (fase decompressione/scansione) ===
              Formato: @SPK@DEC@percentuale@lavorati@totali@eta
              Esempio: @SPK@DEC@42@3242754984@7649478326@1
              Emesso durante la lettura dell'archivio, prima della fase di output W. }
            if Pos('@SPK@DEC@', S) = 1 then
            begin
              SPKParts := S.Split(['@']);
              { Parts: [0]='' [1]='' [2]='' [3]=perc [4]=lavorati [5]=totali [6]=eta }
              if Length(SPKParts) >= 4 then
              begin
                Percent := StrToIntDef(Trim(SPKParts[3]), -1);
                if (Percent >= 0) and (Percent <> LastPercent) then
                begin
                  LastPercent := Percent;
                  FileListDbgWrite('  --> @SPK@DEC@ Progress: ' + IntToStr(Percent) + '%');
                  Application.QueueAsyncCall(@frmMain.FileListGuiUpdate, PtrInt(Percent));
                end;
              end;
            end
            else
            { === Intercetta righe di progresso W (fase di scrittura output) ===
              Formato reale dal pipe: "DD/MM/YYYY HH:NN:SS W NNN% NNNNNNNN/NNNNNNNN"
              Esempio: "07/04/2026 10:03:45 W 010% 00096257/00962563" }
            begin
              WPos := Pos(' W ', S);
              if (WPos > 0) and (Length(S) >= WPos + 6) and (S[WPos + 5] = '%') then
              begin
                PercStr := Trim(Copy(S, WPos + 3, 3));
                Percent := StrToIntDef(PercStr, -1);
                if (Percent >= 0) and (Percent <> LastPercent) then
                begin
                  LastPercent := Percent;
                  FileListDbgWrite('  --> W Progress: ' + IntToStr(Percent) + '%');
                  Application.QueueAsyncCall(@frmMain.FileListGuiUpdate, PtrInt(Percent));
                end;
              end;
            end;

            { Intercetta anche la riga "OUTPUT..." che dà info su versioni e file }
            if Pos('OUTPUT...', S) > 0 then
              FileListDbgWrite('  --> OUTPUT info: ' + S);

            { Intercetta la riga "Output NNN bytes / NNN lines in NNN s" }
            if Pos('Output ', S) > 0 then
              FileListDbgWrite('  --> Output summary: ' + S);
          end
          else if Ch <> #13 then
            LineAccum := LineAccum + Ch;
        end;
      until False;

      { Ultima riga senza newline }
      if LineAccum <> '' then
      begin
        FStderrLog.Add(LineAccum);
        FileListDbgWrite('  PIPE (last): [' + LineAccum + ']');
      end;

      { Se abort richiesto, termina forzatamente il processo }
      if Terminated and Proc.Running then
      begin
        FileListDbgWrite('  Thread terminated: killing process...');
        Proc.Terminate(1);
      end;

      { Attendi la fine del processo (max 3 secondi se abort) }
      if Terminated then
      begin
        I := 0;
        while Proc.Running and (I < 300) do begin Sleep(10); Inc(I); end;
        if Proc.Running then
        begin
          FileListDbgWrite('  Wait timeout: force-killing process');
          Proc.Terminate(1);
        end;
      end
      else
        while Proc.Running do Sleep(5);
      FExitCode := Proc.ExitStatus;

      FileListDbgWrite('  Process finished. ExitCode=' + IntToStr(FExitCode));
      FSuccess := True;

    except
      on E: Exception do
      begin
        FileListDbgWrite('  EXCEPTION: ' + E.ClassName + ': ' + E.Message);
        FSuccess := False;
      end;
    end;

  finally
    Proc.Free;
  end;

  { Verifica file output }
  FileListDbgWrite('  TempFile exists=' + BoolToStr(FileExists(FTempFile), 'YES', 'NO'));
  if FileExists(FTempFile) then
  begin
    FileListDbgWrite('  TempFile size=' + IntToStr(FileSizeByName(FTempFile)) + ' bytes');
  end;

  FileListDbgWrite('TFileListThread.Execute: END — notifying main thread');
  Application.QueueAsyncCall(@frmMain.OnFileListComplete, 0);
end;

{ === Helpers === }

function TfrmMain.FormatFileSize(const ABytes: Int64): string;
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

function TfrmMain.FormatETA(ATotalSeconds: Int64): string;
var
  H, M, sS: Integer;

  function PadTwo(N: Integer): string;
  begin
    Result := IntToStr(N);
    if Length(Result) < 2 then Result := '0' + Result;
  end;

begin
  if ATotalSeconds < 0 then ATotalSeconds := 0;
  H := ATotalSeconds div 3600;
  M := (ATotalSeconds mod 3600) div 60;
  Ss := ATotalSeconds mod 60;
  Result := PadTwo(H) + ':' + PadTwo(M) + ':' + PadTwo(Ss);
end;

procedure TfrmMain.CleanLogBuffer(ABuffer: TStringList);
var
  I: Integer;
  Ss: string;
begin
  if ABuffer = nil then Exit;
  for I := ABuffer.Count - 1 downto 0 do
  begin
    Ss := ABuffer[I];
    // Rimuove ritorni a capo fantasma (es. \r che TMemo converte in righe vuote extra)
    Ss := StringReplace(Ss, #13, '', [rfReplaceAll]);
    Ss := StringReplace(Ss, #10, '', [rfReplaceAll]);
    Ss := Trim(Ss);
    // Filtra le righe di progresso interno zpaqfranz (@DEC@...) che non devono
    // apparire nel log: sono già consumate da OnBridgeProgress per aggiornare
    // la progress bar, ma talvolta finiscono anche nel buffer finale
    if (Ss = '') or (Copy(Ss, 1, 5) = '@DEC@') then
      ABuffer.Delete(I)
    else
      ABuffer[I] := Ss;
  end;
end;

{ === Form Create/Destroy/Show === }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  FileVerInfo: TFileVersionInfo;
  BuildNum: Integer;
  VerStr: string;
  mnuLogSep: TMenuItem;
begin
    PageControl1.OnChange := nil; // <--- DISABILITA
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.FileName := ParamStr(0);
    FileVerInfo.ReadFileInfo;
    VerStr := FileVerInfo.VersionStrings.Values['FileVersion'];
    if VerStr <> '' then
    begin
      BuildNum := StrToIntDef(Copy(VerStr, LastDelimiter('.', VerStr) + 1, Length(VerStr)), 0);
      {$IFDEF CPU32}
      Caption := Format('Catpaq V1.0.0 build %d [32-bit]', [BuildNum]);
      {$ELSE}
      Caption := Format('Catpaq V1.0.0 build %d [64-bit]', [BuildNum]);
      {$ENDIF}
    end
    else
      {$IFDEF CPU32}
      Caption := 'Catpaq V1.0.0 build 0 [32-bit]';
      {$ELSE}
      Caption := 'Catpaq V1.0.0 build 0 [64-bit]';
      {$ENDIF}
  finally
    FileVerInfo.Free;
  end;

  FBridgeOp := 'LIST';
  FTreeMode := tmAllVersions;
  FCurrentVersion := 0;
  FFilterText := '';
  FCommandLineFile := '';
  FPasswordKey := '';
  FPasswordFranzen := '';
  FArchiveBrowseMode := False;
  FLoadingArchive := False;
  FLogProgressLineIndex := -1;
  FFileListAbortRequested := False;
  FTempListFile := '';
  FArchiveBrowsePath := '';
  FLoadFromBrowseTab := False;
  FLvSortColumn := -1;
  FLvSortAscending := True;
  FVstSortColumn := -1;
  FVstSortAscending := True;
  FApplyDefaultSize := False;
  FIniPath := GetCatpaqIniPath;
  AddLog('INI path: ' + FIniPath);
  FZoomPercent := ZOOM_DEFAULT;
  FLang := TStringList.Create;
  FLangName := 'english';
  FTestProgressLineIndex := -1;

  SetLength(FArchiveData.GlobalVersions, 0);
  SetLength(FArchiveData.Files, 0);
  SetLength(FFilteredFiles, 0);

  FHiddenPaths := TStringList.Create;
  FHiddenPaths.Sorted := True;
  FHiddenPaths.Duplicates := dupIgnore;
  FHiddenTrees := TStringList.Create;
  FHiddenTrees.Sorted := True;
  FHiddenTrees.Duplicates := dupIgnore;

  VST.NodeDataSize := SizeOf(TNodeData);
  VST.OnHeaderClick := @VSTHeaderClick;

  edtFilter.AutoSize := False;
  edtFilter.ParentFont := False;
  edtFilter.Anchors := [akLeft, akTop, akRight];

  tbZoom.Frequency := 10;
  tbZoom.PageSize := 10;
  tbZoom.LineSize := 10;

  // --- CREAZIONE DINAMICA COMPONENTI HASHING/LOG (Previene EReadError) ---
  pmLog := TPopupMenu.Create(Self);
  mnuSaveLog := TMenuItem.Create(pmLog);
  mnuSaveLog.Caption := 'Save system log to file...';
  mnuSaveLog.OnClick := @mnuSaveLogClick;
  pmLog.Items.Add(mnuSaveLog);
  mnuLogSep := TMenuItem.Create(pmLog);
  mnuLogSep.Caption := '-';
  pmLog.Items.Add(mnuLogSep);
  mnuLogBack := TMenuItem.Create(pmLog);
  mnuLogBack.Caption := '<= Back to Browse';
  mnuLogBack.OnClick := @mnuLogBackClick;
  pmLog.Items.Add(mnuLogBack);
  mnuLogClear := TMenuItem.Create(pmLog);
  mnuLogClear.Caption := 'Clear system log';
  mnuLogClear.OnClick := @mnuLogClearClick;
  pmLog.Items.Add(mnuLogClear);
  MemoLog.PopupMenu := pmLog;
  MemoLog.OnKeyDown := @MemoLogKeyDown;

  // --- Popup per memArchive (dati archivio) ---
  pmArchive := TPopupMenu.Create(Self);
  mnuSaveArchive := TMenuItem.Create(pmArchive);
  mnuSaveArchive.Caption := 'Save archive log to file...';
  mnuSaveArchive.OnClick := @mnuSaveArchiveClick;
  pmArchive.Items.Add(mnuSaveArchive);
  mnuLogSep := TMenuItem.Create(pmArchive);
  mnuLogSep.Caption := '-';
  pmArchive.Items.Add(mnuLogSep);
  mnuArchiveLogBack := TMenuItem.Create(pmArchive);
  mnuArchiveLogBack.Caption := '<= Back to Browse';
  mnuArchiveLogBack.OnClick := @mnuArchiveLogBackClick;
  pmArchive.Items.Add(mnuArchiveLogBack);
  mnuClearArchive := TMenuItem.Create(pmArchive);
  mnuClearArchive.Caption := 'Clear archive log';
  mnuClearArchive.OnClick := @mnuClearArchiveClick;
  pmArchive.Items.Add(mnuClearArchive);
  memArchive.PopupMenu := pmArchive;
  memArchive.OnKeyDown := @MemoLogKeyDown;

  // --- Pannello Abort nella TabLog (nascosto finché non carica) ---
  pnlLogToolbar := TPanel.Create(Self);
  pnlLogToolbar.Parent := TabLog;
  pnlLogToolbar.Align := alTop;
  pnlLogToolbar.Height := 48;
  pnlLogToolbar.BevelOuter := bvNone;
  pnlLogToolbar.Color := $002080FF; // arancione scuro per attirare l'attenzione
  pnlLogToolbar.Visible := False;

  btnAbortLoad := TButton.Create(Self);
  btnAbortLoad.Parent := pnlLogToolbar;
  btnAbortLoad.Caption := 'ABORT';
  btnAbortLoad.Height := 40;
  btnAbortLoad.Width := 120;
  btnAbortLoad.Left := 8;
  btnAbortLoad.Top := 4;
  btnAbortLoad.Font.Style := [fsBold];
  btnAbortLoad.OnClick := @btnAbortLoadClick;

  lblLogStatus := TLabel.Create(Self);
  lblLogStatus.Parent := pnlLogToolbar;
  lblLogStatus.Left := 140;
  lblLogStatus.Top := 14;
  lblLogStatus.Caption := 'Loading archive...';
  lblLogStatus.Font.Color := clWhite;
  lblLogStatus.Font.Style := [fsBold];
  lblLogStatus.ParentFont := False;
  // -----------------------------------------------------------------------

  SaveDialogLog := TSaveDialog.Create(Self);
  SaveDialogLog.Filter := 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*';
  SaveDialogLog.DefaultExt := 'txt';

  // Creazione check "Hash SSD" nel menu
  mnuHashSep := TMenuItem.Create(Self);
  mnuHashSep.Caption := '-';
  mnuAddHash.Add(mnuHashSep);

  mnuHashSSD := TMenuItem.Create(Self);
  mnuHashSSD.Caption := 'Hash SSD (Multithread)';
  mnuHashSSD.AutoCheck := True;
  mnuHashSSD.Checked := False;
  mnuHashSSD.OnClick := @mnuHashClick;
  mnuAddHash.Add(mnuHashSSD);
  // -----------------------------------------------------------------------

  // --- Checkbox "Check for updates at startup" (creato a runtime in gbLinks) ---
  chkAutoUpdate := TCheckBox.Create(Self);
  chkAutoUpdate.Parent  := gbLinks;
  chkAutoUpdate.Caption := S('chk_auto_update', 'Check for updates at startup');
  chkAutoUpdate.Checked := False;
  chkAutoUpdate.OnClick := @chkAutoUpdateClick;
  FAutoUpdateCheck := False;
  // -----------------------------------------------------------------------


  FBridge := TZpaqBridge.Create;
  ZpaqBridge := FBridge;
  FBridge.OnComplete := @OnBridgeComplete;
  FBridge.OnProgress := @OnBridgeProgress;

  Constraints.MinWidth := MIN_FORM_WIDTH;
  Constraints.MinHeight := MIN_FORM_HEIGHT;

  // Inizializza tutti i campi e timer PRIMA di LoadSettingsFromIni
  // (LoadSettings popola FRestoredWidth/Height/Left/Top che il timer usa)
  FFormReady      := False;
  FRestoredLeft   := -1;
  FRestoredTop    := -1;
  FRestoredWidth  := 0;
  FRestoredHeight := 0;
  FLastSavedLeft   := -1;
  FLastSavedTop    := -1;
  FLastSavedWidth  := 0;
  FLastSavedHeight := 0;
  FillChar(FLastColWidthsLv,  SizeOf(FLastColWidthsLv),  0);
  FillChar(FLastColWidthsVst, SizeOf(FLastColWidthsVst), 0);
  FillChar(FSavedColWidthsLv,  SizeOf(FSavedColWidthsLv),  0);
  FillChar(FSavedColWidthsVst, SizeOf(FSavedColWidthsVst), 0);

  FTimerStartup := TTimer.Create(Self);
  FTimerStartup.Interval := 250;
  FTimerStartup.Enabled := False;
  FTimerStartup.OnTimer := @OnTimerStartup;

  FTimerSave := TTimer.Create(Self);
  FTimerSave.Interval := 2000;
  FTimerSave.Enabled := False;
  FTimerSave.OnTimer := @OnTimerSave;

  // 800ms: abbastanza lungo da aspettare che LCL finisca di
  // ridimensionare i controlli dopo che la form diventa visibile
  FTimerRestore := TTimer.Create(Self);
  FTimerRestore.Interval := 1;
  FTimerRestore.Enabled := False;
  FTimerRestore.OnTimer := @OnTimerRestore;

  LoadSettingsFromIni;
  Visible := False; // nascosta finché OnTimerRestore non applica geometria
  ScanLanguages;

  if IsRunningAsAdmin then
  begin

    lblAdminStatus.Caption := S('lbl_admin_yes', 'Running as Administrator');
    lblAdminStatus.Font.Color := clGreen;
  end
  else
  begin
    lblAdminStatus.Caption := S('lbl_admin_no', 'Not admin (elevated rights required)');
    lblAdminStatus.Font.Color := clRed;
  end;

  InitAddTab;

  // pnlLoading è nel form (tab Browse): nascosto all'avvio, mostrato solo durante caricamento
  pnlLoading.Visible := False;

  TabAdd.PageIndex := 0;
  TabArchive.PageIndex := 1;
  TabLog.PageIndex := 2;
  TabSettings.PageIndex := 3;


  PageControl1.ActivePage := TabAdd;
  PageControl1.OnChange := @PageControl1Change; // <--- RIABILITA

end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveSettingsToIni;
  // Cleanup del thread file listing se ancora in esecuzione
  if Assigned(FileListThread) then
  begin
    FileListThread.WaitFor;
    FreeAndNil(FileListThread);
  end;
  ZpaqBridge := nil;
  FreeAndNil(FBridge);
  FreeAndNil(FHiddenPaths);
  FreeAndNil(FHiddenTrees);
  FreeAndNil(FLang);
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  if Assigned(FTimerStartup) then
    FTimerStartup.Enabled := True;

  // Timer one-shot (150ms): applica geometria INI o default dopo che
  // il window manager ha stabilizzato la finestra
  FTimerRestore.Enabled := True;
  OnResize       := @FormResize;
  OnChangeBounds := @FormResize;
end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  // Ignorato prima che FFormReady sia True (durante init/restore iniziale)
  if not FFormReady then Exit;
  // Nessun debounce: il polling di FTimerSave rileverà il cambiamento al prossimo tick
end;

procedure TfrmMain.Image1Click(Sender: TObject);
begin

end;

procedure TfrmMain.OnTimerRestore(Sender: TObject);
var
  Wd, Ht, L, T, I: Integer;
begin
  FTimerRestore.Enabled := False; // one-shot

  if FApplyDefaultSize then
  begin
    FApplyDefaultSize := False;
    Width  := Screen.WorkAreaWidth  * 8 div 10;
    Height := Screen.WorkAreaHeight * 8 div 10;
    Left   := Screen.WorkAreaLeft + (Screen.WorkAreaWidth  - Width)  div 2;
    Top    := Screen.WorkAreaTop  + (Screen.WorkAreaHeight - Height) div 2;
    AddLog('OnTimerRestore: applico dimensione default → L=' + IntToStr(Left) +
           ' T=' + IntToStr(Top) + ' W=' + IntToStr(Width) + ' H=' + IntToStr(Height));
    if lvAddFiles.Header.Columns.Count >= 6 then
    begin
      lvAddFiles.Header.Columns[0].Width := lvAddFiles.Width * 40 div 100;
      lvAddFiles.Header.Columns[1].Width := lvAddFiles.Width * 12 div 100;
      lvAddFiles.Header.Columns[2].Width := lvAddFiles.Width * 18 div 100;
      lvAddFiles.Header.Columns[3].Width := lvAddFiles.Width * 18 div 100;
      lvAddFiles.Header.Columns[4].Width := lvAddFiles.Width *  6 div 100;
      lvAddFiles.Header.Columns[5].Width := lvAddFiles.Width *  6 div 100;
    end;
    AddLog('OnTimerRestore: applico dimensione lista (proporzionale)');
    AddLog('Settings: first run, default layout applied.');
  end
  else if FRestoredWidth > 0 then
  begin
    Wd := FRestoredWidth;
    Ht := FRestoredHeight;
    L  := FRestoredLeft;
    T  := FRestoredTop;
    if Wd > Screen.WorkAreaWidth  then Wd := Screen.WorkAreaWidth;
    if Ht > Screen.WorkAreaHeight then Ht := Screen.WorkAreaHeight;
    if L < Screen.WorkAreaLeft then L := Screen.WorkAreaLeft;
    if T < Screen.WorkAreaTop  then T := Screen.WorkAreaTop;
    if L + Wd > Screen.WorkAreaLeft + Screen.WorkAreaWidth  then
      L := Max(Screen.WorkAreaLeft, Screen.WorkAreaLeft + Screen.WorkAreaWidth  - Wd);
    if T + Ht > Screen.WorkAreaTop  + Screen.WorkAreaHeight then
      T := Max(Screen.WorkAreaTop, Screen.WorkAreaTop + Screen.WorkAreaHeight - Ht);
    AddLog('OnTimerRestore: applico dimensione/posizione form → SetBounds(' +
           IntToStr(L) + ',' + IntToStr(T) + ',' + IntToStr(Wd) + ',' + IntToStr(Ht) + ')');
    SetBounds(L, T, Wd, Ht);
    AddLog('OnTimerRestore: dopo SetBounds → L=' + IntToStr(Left) +
           ' T=' + IntToStr(Top) + ' W=' + IntToStr(Width) + ' H=' + IntToStr(Height));

    // Riapplica le larghezze colonne DOPO SetBounds usando i per-mille salvati:
    // converte per-mille → pixel con la ClientWidth attuale (post-resize)
    AddLog('OnTimerRestore: riapplico larghezze colonne lista (ClientWidth=' +
           IntToStr(lvAddFiles.Width) + ')');
    for I := 0 to Min(High(FSavedColWidthsLv), lvAddFiles.Header.Columns.Count - 1) do
      if FSavedColWidthsLv[I] > 0 then
      begin
        lvAddFiles.Header.Columns[I].Width := FSavedColWidthsLv[I] * lvAddFiles.Width div 1000;
        AddLog('  lista col[' + IntToStr(I) + '] ' + IntToStr(FSavedColWidthsLv[I]) +
               'o/oo → ' + IntToStr(lvAddFiles.Header.Columns[I].Width) + 'px');
      end;
    AddLog('OnTimerRestore: riapplico larghezze colonne VST');
    for I := 0 to Min(High(FSavedColWidthsVst), VST.Header.Columns.Count - 1) do
      if FSavedColWidthsVst[I] > 0 then
        VST.Header.Columns[I].Width := FSavedColWidthsVst[I];
  end
  else
    AddLog('OnTimerRestore: nessuna geometria da applicare (FRestoredWidth=0)');

  // Scatta snapshot iniziale (base per rilevare cambiamenti futuri)
  FLastSavedLeft   := Left;
  FLastSavedTop    := Top;
  FLastSavedWidth  := Width;
  FLastSavedHeight := Height;
  for I := 0 to Min(High(FLastColWidthsLv),  lvAddFiles.Header.Columns.Count - 1) do
    FLastColWidthsLv[I]  := lvAddFiles.Header.Columns[I].Width;
  for I := 0 to Min(High(FLastColWidthsVst), VST.Header.Columns.Count - 1) do
    FLastColWidthsVst[I] := VST.Header.Columns[I].Width;

  AddLog('OnTimerRestore: snapshot iniziale L=' + IntToStr(Left) +
         ' T=' + IntToStr(Top) + ' W=' + IntToStr(Width) + ' H=' + IntToStr(Height));
  for I := 0 to lvAddFiles.Header.Columns.Count - 1 do
    AddLog('  lista col[' + IntToStr(I) + ']=' + IntToStr(lvAddFiles.Header.Columns[I].Width));

  if not Visible then
  begin
    Visible := True;
    BringToFront;
  end;
  FFormReady := True;
  FTimerSave.Enabled := True;
  AddLog('OnTimerRestore: done. Polling attivo.');
end;

procedure TfrmMain.OnTimerSave(Sender: TObject);
var
  I: Integer;
  NeedSave: Boolean;
begin
  if not FFormReady then Exit;

  NeedSave := False;

  // Posizione e dimensione finestra
  if WindowState = wsNormal then
    if (Left <> FLastSavedLeft) or (Top <> FLastSavedTop) or
       (Width <> FLastSavedWidth) or (Height <> FLastSavedHeight) then
      NeedSave := True;

  // Larghezze colonne lvAddFiles
  if not NeedSave then
    for I := 0 to Min(High(FLastColWidthsLv), lvAddFiles.Header.Columns.Count - 1) do
      if lvAddFiles.Header.Columns[I].Width <> FLastColWidthsLv[I] then
      begin
        NeedSave := True;
        Break;
      end;

  // Larghezze colonne VST
  if not NeedSave then
    for I := 0 to Min(High(FLastColWidthsVst), VST.Header.Columns.Count - 1) do
      if VST.Header.Columns[I].Width <> FLastColWidthsVst[I] then
      begin
        NeedSave := True;
        Break;
      end;

  if NeedSave then
  begin
    // Aggiorna snapshot
    FLastSavedLeft   := Left;
    FLastSavedTop    := Top;
    FLastSavedWidth  := Width;
    FLastSavedHeight := Height;
    for I := 0 to Min(High(FLastColWidthsLv),  lvAddFiles.Header.Columns.Count - 1) do
      FLastColWidthsLv[I]  := lvAddFiles.Header.Columns[I].Width;
    for I := 0 to Min(High(FLastColWidthsVst), VST.Header.Columns.Count - 1) do
      FLastColWidthsVst[I] := VST.Header.Columns[I].Width;

    SaveSettingsToIni;
    AddLog('Settings saved (position/size/columns).');
  end;
end;


procedure TfrmMain.mnuLogBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabAdd;
end;

procedure TfrmMain.mnuLogClearClick(Sender: TObject);
begin
  MemoLog.Clear;
end;

procedure TfrmMain.MemoLogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_BACK) and (Shift = []) then
  begin
    Key := 0;
    PageControl1.ActivePage := TabAdd;
  end;
end;

procedure TfrmMain.mnuSaveLogClick(Sender: TObject);
begin
  if SaveDialogLog.Execute then
  begin
    MemoLog.Lines.SaveToFile(SaveDialogLog.FileName);
    ShowMessage('Log saved successfully to:'#13#10 + SaveDialogLog.FileName);
  end;
end;

procedure TfrmMain.mnuSaveArchiveClick(Sender: TObject);
begin
  if SaveDialogLog.Execute then
  begin
    memArchive.Lines.SaveToFile(SaveDialogLog.FileName);
    ShowMessage('Archive log saved successfully to:'#13#10 + SaveDialogLog.FileName);
  end;
end;

procedure TfrmMain.mnuArchiveLogBackClick(Sender: TObject);
begin
  PageControl1.ActivePage := TabAdd;
end;

procedure TfrmMain.mnuClearArchiveClick(Sender: TObject);
begin
  memArchive.Clear;
end;

procedure TfrmMain.AddArchiveLog(const AMsg: string);
begin
  memArchive.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + AMsg);
  memArchive.SelStart := Length(memArchive.Text);
end;


procedure TfrmMain.OnTimerStartup(Sender: TObject);
var
  StartupOK: Boolean;
begin
  FTimerStartup.Enabled := False;
  PageControl1.OnChange := nil;  // impedisce auto-caricamenti durante il cambio tab

  StartupOK := ExecuteStartupChecks;

  if FCommandLineFile <> '' then
  begin
    // Avviato con file da riga di comando → vai direttamente all'archivio (tutte le versioni)
    FArchiveBrowsePath := '';  { vuoto → BuildCommandString aggiunge -all }
    PageControl1.ActivePage := TabArchive;
    PageControl1.OnChange := @PageControl1Change;
    DoLoadArchive(FCommandLineFile);
    FCommandLineFile := '';
  end
  else if StartupOK then
  begin
    // Tutto OK: vai direttamente al filesystem, nessun flicker sul Log
    PageControl1.ActivePage := TabAdd;
    PageControl1.OnChange := @PageControl1Change;
    { Controllo aggiornamenti all'avvio (solo se abilitato nelle impostazioni) }
    if FAutoUpdateCheck then
      DoStartupUpdateCheck;
  end
  else
  begin
    // Errori al check iniziale: mostra il log e fermati lì
    PageControl1.ActivePage := TabLog;
    PageControl1.OnChange := @PageControl1Change;
  end;
end;

function TfrmMain.ExecuteStartupChecks: Boolean;
var
  ExeFound: Boolean;
  ExePath: string;
begin
  Result := False; // pessimistico: True solo se tutto OK alla fine

  // I log vengono scritti senza cambiare tab: è OnTimerStartup che
  // sceglie il tab da mostrare in base al valore restituito.
  AddLog('--- System Startup Check ---');
  Application.ProcessMessages;

  ExeFound := False;

  // --- Determina i path attesi (platform-specific) ---
  {$IFDEF WINDOWS}
  {$IFDEF CPU32}
  // 32-bit: usa zpaqfranzxp.exe direttamente
  ExePath  := ExtractFilePath(ParamStr(0)) + 'zpaqfranzxp.exe';
  {$ELSE}
  // 64-bit: usa zpaqfranz.exe
  ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';
  {$ENDIF}
  {$ELSE}
  // macOS e Linux: solo l'eseguibile zpaqfranz è richiesto
  ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz';
  {$ENDIF}

  // --- Controlla presenza fisica dei file ---
  ExeFound := FileExists(ExePath);
  AddLog('EXE present: ' + BoolToStr(ExeFound, 'YES', 'NO') + '  [' + ExePath + ']');

  {$IFDEF WINDOWS}
  {$IFDEF CPU32}
  // 32-bit: solo zpaqfranzxp.exe richiesto
  if not ExeFound then
  begin
    AddLog('WARNING: zpaqfranzxp.exe is missing.');
    MessageDlg('Missing file',
      'zpaqfranzxp.exe is missing.' + sLineBreak +
      'The 32-bit version requires zpaqfranzxp.exe.' + sLineBreak + sLineBreak +
      'Expected location: ' + ExePath + sLineBreak +
      'The application will try to download it.',
      mtWarning, [mbOK], 0);
    AddLog('Missing zpaqfranzxp.exe. Offering download...');
    Application.ProcessMessages;
    if TryDownloadExternal then  // TryDownloadExternal scarica anche l'exe in modalità 32-bit
    begin
      ExeFound := FileExists(ExePath);
      if not ExeFound then
      begin
        AddLog('ERROR: Download incomplete. Open disabled.');
        btnOpen.Enabled := False;
        Exit;
      end;
    end
    else
    begin
      AddLog('Download cancelled or failed. Open disabled.');
      btnOpen.Enabled := False;
      Exit;
    end;
  end;
  // Valida solo l'exe (hash di zpaqfranzxp.exe)
  if not ValidateXP then
  begin
    AddLog('FATAL: zpaqfranzxp.exe hash validation failed. Blocking open.');
    btnOpen.Enabled := False;
    Exit;
  end;
  // In modalità 32-bit il bridge
  AddLog('32-bit mode: using zpaqfranzxp.exe directly.');
  // Configura il bridge con il path di zpaqfranzxp.exe
  FBridge.LoadExternal(ExtractFilePath(ParamStr(0)) + 'zpaqfranzxp.exe');
  btnOpen.Enabled := True;
  Result := True;
  {$ELSE}
  // 64-bit

  // Su Windows ENTRAMBI i file sono obbligatori
  if not ExeFound then
  begin

      AddLog('WARNING: zpaqfranz.exe is missing.');
      MessageDlg('Missing file',
        'zpaqfranz.exe is missing.' + sLineBreak +
        'Expected location: ' + ExePath + sLineBreak +
        'The application will try to download it.',
        mtWarning, [mbOK], 0);


    // Offri download automatico
    AddLog('Missing files. Offering download...');
    Application.ProcessMessages;

    if TryDownloadExternal then
    begin
      ExeFound := FileExists(ExePath);
      AddLog('After download - EXE: ' + BoolToStr(ExeFound, 'YES', 'NO'));

      if not ExeFound then
      begin
        AddLog('ERROR: Download incomplete. Open disabled.');
        btnOpen.Enabled := False;
        Exit;
      end;
      if not ValidateEXE then
      begin
        AddLog('FATAL: Downloaded EXE validation failed.');
        btnOpen.Enabled := False;
        Exit;
      end;
    end
    else
    begin
      AddLog('Download cancelled or failed. Open disabled.');
      btnOpen.Enabled := False;
      Exit;
    end;
  end
  else
  begin
    // Entrambi presenti su Windows: valida hash
    if not ValidateEXE then
    begin
      AddLog('FATAL: EXE hash validation failed. Blocking open.');
      btnOpen.Enabled := False;
      Exit;
    end;
  end;

  // --- Windows 64-bit: carica il bridge (richiede ENTRAMBI i file) ---
  if FBridge.LoadExternal then
  begin
    AddLog('Bridge loaded: ' + FBridge.ExternalPath);
    btnOpen.Enabled := True;
    Result := True;
  end
  else
  begin
    AddLog('ERROR: Could not load bridge Open disabled.');
    AddLog('Make sure zpaqfranz.exe is : ' +
           ExtractFilePath(ParamStr(0)));
    btnOpen.Enabled := False;
  end;
  {$ENDIF} // CPU32

  {$ELSE}
  // --- macOS / Linux: solo zpaqfranz è necessario ---
  if not ExeFound then
  begin
    AddLog('WARNING: zpaqfranz executable not found.');
    MessageDlg('Missing file',
      'zpaqfranz is missing.' + sLineBreak +
      'The application requires the zpaqfranz executable.' + sLineBreak + sLineBreak +
      'Expected location: ' + ExePath + sLineBreak + sLineBreak +
      'Please download zpaqfranz for your platform and place it' + sLineBreak +
      'in the same folder as catpaq.',
      mtWarning, [mbOK], 0);
    btnOpen.Enabled := False;
    Exit;
  end;

  // EXE trovato: carica il bridge (solo EXE)
  // NOTA: la validazione SHA256 di zpaqfranz è disabilitata su macOS/Linux
  // (l'utente procura l'eseguibile autonomamente per la propria piattaforma)
  if FBridge.LoadExternal then
  begin
    AddLog('Bridge loaded (EXE mode): ' + FBridge.ExternalPath);
    btnOpen.Enabled := True;
    Result := True;
  end
  else
  begin
    AddLog('ERROR: Could not load zpaqfranz executable. Open disabled.');
    AddLog('Make sure zpaqfranz is in: ' + ExtractFilePath(ParamStr(0)));
    btnOpen.Enabled := False;
  end;
  {$ENDIF}
end;

function TfrmMain.ValidateEXE: Boolean;
{$IFDEF WINDOWS}
var
  ExePath, ActualHash: string;
{$ENDIF}
begin
  Result := True;

  {$IFDEF WINDOWS}
  // Modalità sviluppo: hash placeholder → skip
  if EXPECTED_EXE_HASH = '0000000000000000000000000000000000000000000000000000000000000000' then
  begin
    AddLog('EXE validation: SKIPPED (development mode)');
    Exit;
  end;

  ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';

  // File assente: non è compito di questo metodo segnalarlo (lo fa ExecuteStartupChecks)
  if not FileExists(ExePath) then Exit;

  AddLog('EXE validation: Computing SHA256...');
  ActualHash := SHA256File(ExePath);

  if ActualHash = '' then
  begin
    AddLog('EXE validation: ERROR - Could not compute hash');
    Result := False;
    MessageDlg(S('dlg_exe_validation_error', 'Validation Error'),
      S('msg_exe_hash_compute_fail', 'Cannot compute hash of zpaqfranz.exe.'),
      mtError, [mbOK], 0);
    Exit;
  end;

  AddLog('EXE Expected: ' + EXPECTED_EXE_HASH);
  AddLog('EXE Actual:   ' + ActualHash);

  if LowerCase(ActualHash) <> LowerCase(EXPECTED_EXE_HASH) then
  begin
    AddLog('EXE validation: FAILED - Hash mismatch!');
    Result := False;
    MessageDlg(S('dlg_exe_validation_error', 'Validation Error'),
      S('msg_exe_hash_mismatch', 'Security check failed for zpaqfranz.exe!' + sLineBreak +
        'The file does not match the expected version.' + sLineBreak +
        'It may be corrupted or tampered with.'),
      mtError, [mbOK], 0);
  end
  else
    AddLog('EXE validation: PASSED');
  {$ELSE}
  // macOS / Linux: nessuna validazione hash sull'eseguibile zpaqfranz
  // (l'utente lo procura autonomamente per la propria piattaforma)
  AddLog('EXE validation: SKIPPED (not required on this platform)');
  {$ENDIF}
end;

function TfrmMain.ValidateXP: Boolean;
{$IFDEF CPU32}
var
  XPPath, ActualHash: string;
{$ENDIF}
begin
  Result := True;
  {$IFDEF CPU32}
  if EXPECTED_XP_HASH = '0000000000000000000000000000000000000000000000000000000000000000' then
  begin
    AddLog('XP validation: SKIPPED (development mode)');
    Exit;
  end;
  XPPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranzxp.exe';
  if not FileExists(XPPath) then Exit;
  AddLog('XP validation: Computing SHA256...');
  ActualHash := SHA256File(XPPath);
  if ActualHash = '' then
  begin
    AddLog('XP validation: ERROR - Could not compute hash');
    Result := False;
    Exit;
  end;
  AddLog('XP Expected: ' + EXPECTED_XP_HASH);
  AddLog('XP Actual:   ' + ActualHash);
  if LowerCase(ActualHash) <> LowerCase(EXPECTED_XP_HASH) then
  begin
    AddLog('XP validation: FAILED - Hash mismatch!');
    Result := False;
    MessageDlg('Validation Error',
      'Security check failed for zpaqfranzxp.exe!' + sLineBreak +
      'The file does not match the expected version.' + sLineBreak +
      'The file may be corrupted or tampered with.',
      mtError, [mbOK], 0);
  end
  else
    AddLog('XP validation: PASSED');
  {$ELSE}
  AddLog('XP validation: SKIPPED (64-bit build)');
  {$ENDIF}
end;

function TfrmMain.TryDownloadExternal: Boolean;
{$IFDEF WINDOWS}
var
  Checker:          TUpdateChecker;
  UpdateInfo:       TUpdateInfo;
  ExeData: TBytes;
  ExeHash:string;
  ExePath:string;
  FS: TFileStream;
begin
  Result := False;
  AddLog('--- TryDownloadExternal: START ---');
  AddLog('App path: ' + ExtractFilePath(ParamStr(0)));

  {$IFDEF CPU32}
  // === 32-bit: scarica solo zpaqfranzxp.exe ===
  if MessageDlg('File Missing',
    'zpaqfranzxp.exe is required but not found.' + sLineBreak +
    'Do you want to download it now?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
  begin
    AddLog('TryDownloadExternal: user cancelled.');
    Exit;
  end;

  PageControl1.ActivePage := TabLog;
  pgrProgresso.Max      := 100;
  pgrProgresso.Position := 0;
  pgrProgresso.Visible  := True;
  Application.ProcessMessages;

  Checker := TUpdateChecker.Create;
  Checker.OnLog      := @AddLog;
  Checker.OnProgress := @HandleDownloadProgress;
  try
    if not Checker.CheckForUpdate(0, UpdateInfo) then
    begin
      if not UpdateInfo.Valid then
      begin
        ShowMessage('Failed to connect to update server.' + sLineBreak +
          'Check the Log tab for details.');
        Exit;
      end;
    end;
    Application.ProcessMessages;

    AddLog('Downloading zpaqfranzxp.exe (' +
           IntToStr(UpdateInfo.EXEInfo.FileSize div 1024) + ' KB)...');
    if not Checker.DownloadFile_Public(ExeData) then
    begin
      ShowMessage('Failed to download zpaqfranzxp.exe.' + sLineBreak +
        'Check the Log tab for details.');
      Exit;
    end;

    ExeHash := Checker.CalculateSHA256FromBytes_Public(ExeData);
    AddLog('XP EXE hash computed:  ' + ExeHash);
    AddLog('XP EXE hash expected:  ' + UpdateInfo.EXEInfo.SHA256Hash);
    if ExeHash <> UpdateInfo.EXEInfo.SHA256Hash then
    begin
      AddLog('TryDownloadExternal: zpaqfranzxp.exe HASH MISMATCH');
      ShowMessage('Security check failed on zpaqfranzxp.exe.');
      Exit;
    end;

    ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranzxp.exe';
    try
      AddLog('Saving zpaqfranzxp.exe to ' + ExePath);
      FS := TFileStream.Create(ExePath, fmCreate);
      try
        if Length(ExeData) > 0 then FS.Write(ExeData[0], Length(ExeData));
      finally FS.Free; end;
      AddLog('zpaqfranzxp.exe saved successfully.');
      Result := True;
    except
      on E: Exception do
      begin
        AddLog('TryDownloadExternal: save FAILED - ' + E.ClassName + ': ' + E.Message);
        ShowMessage('Cannot save file. Check folder permissions.');
      end;
    end;
  finally
    Checker.Free;
    AddLog('--- TryDownloadExternal: END result=' + BoolToStr(Result, 'TRUE', 'FALSE') + ' ---');
    pgrProgressLog.Position := 0;
    pgrProgressLog.Visible  := False;
    pgrProgresso.Position   := 0;
    pgrProgresso.Visible    := False;
  end;
  {$ELSE}
  // === 64-bit: scarica zpaqfranz.exe  ===
  if MessageDlg(S('dlg_external_missing_title', 'Files Missing'),
    S('dlg_external_missing_msg',
      'zpaqfranz.exe is required but not found.' + sLineBreak +
      'Do you want to download now?'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
  begin
    Exit;
  end;

  // Mostra il tab Log subito, così l'utente vede i messaggi durante il download
  PageControl1.ActivePage := TabLog;
  pgrProgresso.Max      := 100;
  pgrProgresso.Position := 0;
  pgrProgresso.Visible  := True;
  Application.ProcessMessages;

  Checker := TUpdateChecker.Create;
  Checker.OnLog      := @AddLog;
  Checker.OnProgress := @HandleDownloadProgress;
  try
    // --- Recupera version.txt ---
    if not Checker.CheckForUpdate(0, UpdateInfo) then
    begin
      if not UpdateInfo.Valid then
      begin
        ShowMessage(S('dlg_external_download_fail',
          'Failed to connect to update server.') + sLineBreak +
          'Check the Log tab for details.');
        Exit;
      end;
    end;

    Application.ProcessMessages;

    // --- Scarica zpaqfranz.exe ---
    AddLog('Downloading zpaqfranz.exe (' +
           IntToStr(UpdateInfo.EXEInfo.FileSize div 1024) + ' KB)...');
    if not Checker.DownloadFile_Public(ExeData) then
    begin
      ShowMessage(S('dlg_external_download_fail',
        'Failed to download zpaqfranz.exe.') + sLineBreak +
        'Check the Log tab for details.');
      Exit;
    end;

    ExeHash := Checker.CalculateSHA256FromBytes_Public(ExeData);
    AddLog('EXE hash computed:  ' + ExeHash);
    AddLog('EXE hash expected:  ' + UpdateInfo.EXEInfo.SHA256Hash);
    if ExeHash <> UpdateInfo.EXEInfo.SHA256Hash then
    begin
      AddLog('TryDownloadExternal: EXE HASH MISMATCH');
      ShowMessage(S('dlg_external_hash_fail', 'Security check failed on zpaqfranz.exe.'));
      Exit;
    end;



    // --- Salva entrambi su disco ---
    ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';

    try
      AddLog('Saving zpaqfranz.exe to ' + ExePath);
      FS := TFileStream.Create(ExePath, fmCreate);
      try
        if Length(ExeData) > 0 then FS.Write(ExeData[0], Length(ExeData));
      finally FS.Free; end;


      AddLog('Both files saved successfully.');
      Result := True;
    except
      on E: Exception do
      begin
        AddLog('TryDownloadExternal: save FAILED - ' + E.ClassName + ': ' + E.Message);
        ShowMessage(S('dlg_external0_save_fail', 'Cannot save files. Check folder permissions.'));
      end;
    end;

  finally
    Checker.Free;
    AddLog('--- TryDownloadExternal: END result=' + BoolToStr(Result, 'TRUE', 'FALSE') + ' ---');
    pgrProgressLog.Position := 0;
    pgrProgressLog.Visible  := False;
    pgrProgresso.Position   := 0;
    pgrProgresso.Visible    := False;
  end;
  {$ENDIF} // CPU32
end;
{$ELSE}
// Su macOS e Linux il download automatico non è disponibile.
// L'utente deve procurarsi zpaqfranz per la propria piattaforma manualmente.
begin
  Result := False;
  AddLog('TryDownloadExternal: automatic download not available on this platform.');
  MessageDlg('zpaqfranz not found',
    'The zpaqfranz executable is required but was not found.' + sLineBreak + sLineBreak +
    'Please download zpaqfranz for your platform from:' + sLineBreak +
    'https://github.com/fcorbelli/zpaqfranz' + sLineBreak + sLineBreak +
    'Place the zpaqfranz executable in the same folder as catpaq:' + sLineBreak +
    ExtractFilePath(ParamStr(0)) + sLineBreak + sLineBreak +
    'Make sure it is executable (chmod +x zpaqfranz).',
    mtInformation, [mbOK], 0);
end;
{$ENDIF}

procedure TfrmMain.LoadArchiveFromCommandLine(const AFileName: string);
begin
  FCommandLineFile := AFileName;
end;

{ === INI Settings === }

procedure TfrmMain.LoadSettingsFromIni;
const
  SANE_MIN_W = 400;
  SANE_MIN_H = 300;
var
  Ini: TIniFile;
  FontName, LN: string;
  FontSize, I, W, L, T, Wd, Ht, Zoom: Integer;
begin
  FBaseFont     := VST.Font.Name;
  FBaseFontSize := VST.Font.Size;
  FApplyDefaultSize := False;

  AddLog('--- LoadSettings: INI=' + FIniPath);

  if not FileExists(FIniPath) then
  begin
    AddLog('LoadSettings: file not found → first run, default layout');
    FApplyDefaultSize := True;
    Position := poScreenCenter;
    UpdateFontLabel;
    UpdateZoomLabel;
    Exit;
  end;

  Ini := TIniFile.Create(FIniPath);
  try
    // --- Font VST ---
    FontName := Ini.ReadString('TreeFont', 'Name', '');
    FontSize := Ini.ReadInteger('TreeFont', 'Size', 0);
    AddLog('LoadSettings: TreeFont=' + FontName + ' size=' + IntToStr(FontSize));
    if (FontName <> '') and (FontSize > 0) then
    begin
      VST.Font.Name        := FontName;
      VST.Font.Size        := FontSize;
      VST.Header.Font.Name := FontName;
      VST.Header.Font.Size := FontSize;
      FBaseFont     := FontName;
      FBaseFontSize := FontSize;
    end;

    // --- Colonne VST ---
    for I := 0 to VST.Header.Columns.Count - 1 do
    begin
      W := Ini.ReadInteger('Columns', 'Width' + IntToStr(I), -1);
      if W > 0 then
      begin
        VST.Header.Columns[I].Width := W;
        if I <= High(FSavedColWidthsVst) then FSavedColWidthsVst[I] := W;
      end;
    end;
    AddLog('LoadSettings: carico dati form (VST columns done)');

    // --- Font lvAddFiles ---
    FontName := Ini.ReadString('ListFont', 'Name', '');
    FontSize := Ini.ReadInteger('ListFont', 'Size', 0);
    AddLog('LoadSettings: ListFont=' + FontName + ' size=' + IntToStr(FontSize));
    if (FontName <> '') and (FontSize > 0) then
    begin
      lvAddFiles.Font.Name := FontName;
      lvAddFiles.Font.Size := FontSize;
    end;

    // --- Colonne lvAddFiles ---
    // I valori in INI sono per-mille della ClientWidth (salvati così per essere
    // immuni a DPI/scaling). Vengono applicati in pixel in OnTimerRestore,
    // quando la form ha già la sua dimensione definitiva.
    for I := 0 to lvAddFiles.Header.Columns.Count - 1 do
    begin
      W := Ini.ReadInteger('ListColumns', 'Width' + IntToStr(I), -1);
      AddLog('LoadSettings: carico dati lista col[' + IntToStr(I) + ']=' + IntToStr(W) + 'o/oo');
      if (W > 0) and (I <= High(FSavedColWidthsLv)) then
        FSavedColWidthsLv[I] := W;  // per-mille, applicato dopo in OnTimerRestore
    end;

    // --- Geometria finestra ---
    L  := Ini.ReadInteger('Window', 'Left',   -1);
    T  := Ini.ReadInteger('Window', 'Top',    -1);
    Wd := Ini.ReadInteger('Window', 'Width',   0);
    Ht := Ini.ReadInteger('Window', 'Height',  0);
    AddLog('LoadSettings: raw Window L=' + IntToStr(L) + ' T=' + IntToStr(T) +
           ' W=' + IntToStr(Wd) + ' H=' + IntToStr(Ht));

    if (Wd >= SANE_MIN_W) and (Ht >= SANE_MIN_H) then
    begin
      FRestoredLeft   := L;
      FRestoredTop    := T;
      FRestoredWidth  := Wd;
      FRestoredHeight := Ht;
      AddLog('LoadSettings: geometria valida → sarà applicata in OnTimerRestore');
    end
    else
    begin
      AddLog('LoadSettings: geometria NON valida (W=' + IntToStr(Wd) +
             ' H=' + IntToStr(Ht) + ') → default layout');
      FApplyDefaultSize := True;
      Position := poScreenCenter;
    end;

    Zoom := Ini.ReadInteger('Zoom', 'Percent', ZOOM_DEFAULT);
    if (Zoom < ZOOM_MIN) or (Zoom > ZOOM_MAX) then Zoom := ZOOM_DEFAULT;
    FZoomPercent    := Zoom;
    tbZoom.Position := Zoom;
    ApplyZoom(Zoom);
    LN := Ini.ReadString('Language', 'Name', 'english');
    LoadLanguage(LN);
    FAutoUpdateCheck := Ini.ReadBool('Updates', 'CheckOnStartup', False);
    if Assigned(chkAutoUpdate) then
      chkAutoUpdate.Checked := FAutoUpdateCheck;
    FKeepTempFiles := Ini.ReadBool('Debug', 'KeepTempFiles', False);
  finally
    Ini.Free;
  end;
  UpdateFontLabel;
  UpdateZoomLabel;
  AddLog('LoadSettings: done');
end;

procedure TfrmMain.SaveSettingsToIni;
var
  Ini: TIniFile;
  I: Integer;
begin
  try
    AddLog('SaveSettings → ' + FIniPath);
    Ini := TIniFile.Create(FIniPath);
    try
      Ini.WriteString('TreeFont', 'Name', FBaseFont);
      Ini.WriteInteger('TreeFont', 'Size', FBaseFontSize);
      // --- Font del file list ---
      Ini.WriteString('ListFont', 'Name', lvAddFiles.Font.Name);
      Ini.WriteInteger('ListFont', 'Size', lvAddFiles.Font.Size);
      // --- Larghezze colonne lvAddFiles ---
      // Salviamo come per-mille della ClientWidth: immune a DPI/scaling macOS.
      // Al caricamento verranno riconvertite in pixel con la ClientWidth del momento.
      if lvAddFiles.Width > 0 then
        for I := 0 to lvAddFiles.Header.Columns.Count - 1 do
          Ini.WriteInteger('ListColumns', 'Width' + IntToStr(I),
            lvAddFiles.Header.Columns[I].Width * 1000 div lvAddFiles.Width)
      else
        for I := 0 to lvAddFiles.Header.Columns.Count - 1 do
          Ini.WriteInteger('ListColumns', 'Width' + IntToStr(I), lvAddFiles.Header.Columns[I].Width);
      // --- Larghezze colonne VST (pixel assoluti, applicate dopo SetBounds) ---
      for I := 0 to VST.Header.Columns.Count - 1 do
        Ini.WriteInteger('Columns', 'Width' + IntToStr(I), VST.Header.Columns[I].Width);
      if WindowState = wsNormal then
      begin
        Ini.WriteInteger('Window', 'Left', Left);
        Ini.WriteInteger('Window', 'Top', Top);
        Ini.WriteInteger('Window', 'Width', Width);
        Ini.WriteInteger('Window', 'Height', Height);
      end;
      Ini.WriteInteger('Zoom', 'Percent', FZoomPercent);
      Ini.WriteString('Language', 'Name', FLangName);
      if Assigned(chkAutoUpdate) then
        FAutoUpdateCheck := chkAutoUpdate.Checked;
      Ini.WriteBool('Updates', 'CheckOnStartup', FAutoUpdateCheck);
      Ini.WriteBool('Debug', 'KeepTempFiles', FKeepTempFiles);
    finally
      Ini.Free;
    end;
  except
  end;
end;

procedure TfrmMain.UpdateFontLabel;
begin
  lblCurrentFont.Caption := Format('%s: %s, %d pt', [S('lbl_current_font', 'Current'), FBaseFont, FBaseFontSize]);
end;

{ === Zoom & Layout === }

procedure TfrmMain.UpdateTreeRowHeight;
begin
  VST.BeginUpdate;
  try
    VST.DefaultNodeHeight := Abs(VST.Canvas.TextHeight('Wg')) + 8;
    VST.ReinitNode(nil, True);
  finally
    VST.EndUpdate;
  end;
end;

procedure TfrmMain.ApplyZoom(APercent: Integer);
var
  ScaleFactor: Double;
  ScaledFontSize, TabFontSize: Integer;
  NewHArchive, NewHTrack, NewHCerca, NewHBottoni, TotalPanelH: Integer;
  Margin, EditRequiredH: Integer;
  SetMargin, SetGap, SetBtnH, CurrentY: Integer;
begin
  if APercent < ZOOM_MIN then APercent := ZOOM_MIN;
  if APercent > ZOOM_MAX then APercent := ZOOM_MAX;
  FZoomPercent := APercent;
  ScaleFactor := APercent / 100.0;
  Margin := Round(32 * ScaleFactor);

  ScaledFontSize := Max(6, Round(FBaseFontSize * ScaleFactor));
  TabFontSize := Max(8, Round(10 * ScaleFactor));

  VST.Font.Name := FBaseFont;
  VST.Font.Size := ScaledFontSize;
  VST.Header.Font.Name := FBaseFont;
  VST.Header.Font.Size := ScaledFontSize;
  UpdateTreeRowHeight;

  PageControl1.Font.Size := TabFontSize;
  MemoLog.Font.Size := Max(8, Round(11 * ScaleFactor));
  Self.Font.Size := TabFontSize;

  NewHArchive := Max(30, Round(BASE_H_ARCHIVE_INFO * ScaleFactor));
  NewHTrack   := Max(25, Round(BASE_H_TRACKBAR * ScaleFactor));
  NewHBottoni := Max(50, Round(BASE_H_BOTTONI * ScaleFactor));

  edtFilter.ParentFont := False;
  edtFilter.Font.Size := TabFontSize;
  Self.Canvas.Font.Name := edtFilter.Font.Name;
  Self.Canvas.Font.Size := TabFontSize;
  EditRequiredH := Self.Canvas.TextHeight('Wg') + Round(20 * ScaleFactor);
  edtFilter.Height := EditRequiredH;

  NewHCerca := Max(Round(BASE_H_CERCA * ScaleFactor), EditRequiredH + Round(24 * ScaleFactor));

  lblArchiveInfo.Height := NewHArchive;
  TrackBar1.Height := NewHTrack;
  pnlCerca.Height := NewHCerca;
  pnlBottoni.Height := NewHBottoni;

  TotalPanelH := NewHArchive + NewHTrack + NewHCerca + NewHBottoni + Max(35, Round(35 * ScaleFactor));
  PanelBottom.Height := TotalPanelH;
  PanelBottom.Font.Size := Max(8, Round(12 * ScaleFactor));

  lblFilter.ParentFont := False;
  lblFilter.Font.Size := TabFontSize;
  lblFilter.Left := Margin;
  lblFilter.Top := (NewHCerca - lblFilter.Height) div 2;

  edtFilter.Top := (NewHCerca - edtFilter.Height) div 2;
  edtFilter.Left := lblFilter.Left + lblFilter.Width + Round(16 * ScaleFactor);
  edtFilter.Width := pnlCerca.ClientWidth - edtFilter.Left - Margin;

  pnlBottoni.Font.Size := TabFontSize;
  btnOpen.Height := Round(75 * ScaleFactor);
  btnTimeMachine.Height := Round(75 * ScaleFactor);

  SetMargin := Round(20 * ScaleFactor);
  SetGap    := Round(10 * ScaleFactor);
  SetBtnH   := Round(40 * ScaleFactor);

  gbFileAssoc.Font.Size := TabFontSize;
  gbFont.Font.Size      := TabFontSize;
  gbLinks.Font.Size     := TabFontSize;
  gbZoom.Font.Size      := TabFontSize;
  gbLanguage.Font.Size  := TabFontSize;

  CurrentY := SetMargin;

  gbFileAssoc.Top := CurrentY; gbFileAssoc.Left := SetMargin;
 /// gbFileAssoc.Width := tabsettings.width;
    btnAssociate.Top := SetGap; btnAssociate.Left := SetGap; btnAssociate.Height := SetBtnH; btnAssociate.Width := gbFileAssoc.ClientWidth - (SetGap * 2);
    btnDisassociate.Top := btnAssociate.Top + SetBtnH + SetGap; btnDisassociate.Left := SetGap; btnDisassociate.Height := SetBtnH; btnDisassociate.Width := btnAssociate.Width;
    lblAdminStatus.Top := btnDisassociate.Top + SetBtnH + SetGap; lblAdminStatus.Left := SetGap;
    gbFileAssoc.ClientHeight := lblAdminStatus.Top + lblAdminStatus.Height + SetGap;
  CurrentY := CurrentY + gbFileAssoc.Height + SetMargin;

  gbFont.Top := CurrentY; gbFont.Left := SetMargin; gbFont.Width := gbFileAssoc.Width;
    btnChangeTreeFont.Top := SetGap; btnChangeTreeFont.Left := SetGap; btnChangeTreeFont.Height := SetBtnH; btnChangeTreeFont.Width := gbFont.ClientWidth - (SetGap * 2);
    lblCurrentFont.Top := btnChangeTreeFont.Top + SetBtnH + SetGap; lblCurrentFont.Left := SetGap;
    gbFont.ClientHeight := lblCurrentFont.Top + lblCurrentFont.Height + SetGap;
  CurrentY := CurrentY + gbFont.Height + SetMargin;

  gbLinks.Top := CurrentY; gbLinks.Left := SetMargin; gbLinks.Width := gbFileAssoc.Width;
    btnBrowseBuild.Top := SetGap; btnBrowseBuild.Left := SetGap; btnBrowseBuild.Height := SetBtnH; btnBrowseBuild.Width := gbLinks.ClientWidth - (SetGap * 2);
    btnInternetUpdate.Top := btnBrowseBuild.Top + SetBtnH + SetGap; btnInternetUpdate.Left := SetGap; btnInternetUpdate.Height := SetBtnH; btnInternetUpdate.Width := btnBrowseBuild.Width;
    if Assigned(chkAutoUpdate) then
    begin
      chkAutoUpdate.Top    := btnInternetUpdate.Top + SetBtnH + SetGap;
      chkAutoUpdate.Left   := SetGap;
      chkAutoUpdate.Height := SetBtnH;
      chkAutoUpdate.Width  := btnInternetUpdate.Width;
      chkAutoUpdate.Font.Size := TabFontSize;
      gbLinks.ClientHeight := chkAutoUpdate.Top + SetBtnH + SetGap;
    end
    else
      gbLinks.ClientHeight := btnInternetUpdate.Top + SetBtnH + SetGap;
  CurrentY := CurrentY + gbLinks.Height + SetMargin;

  gbZoom.Top := CurrentY; gbZoom.Left := SetMargin; gbZoom.Width := gbFileAssoc.Width;
    tbZoom.Top := SetGap; tbZoom.Left := SetGap; tbZoom.Height := SetBtnH; tbZoom.Width := Round(gbZoom.ClientWidth * 0.60);
    lblZoomValue.Top := SetGap + ((SetBtnH - lblZoomValue.Height) div 2); lblZoomValue.Left := tbZoom.Left + tbZoom.Width + SetGap;
    gbZoom.ClientHeight := tbZoom.Top + SetBtnH + SetGap;
  CurrentY := CurrentY + gbZoom.Height + SetMargin;

  gbLanguage.Top := CurrentY; gbLanguage.Left := SetMargin; gbLanguage.Width := gbFileAssoc.Width;
    cbLanguage.Top := SetGap; cbLanguage.Left := SetGap; cbLanguage.Width := gbLanguage.ClientWidth - (SetGap * 2);
    gbLanguage.ClientHeight := cbLanguage.Top + cbLanguage.Height + SetGap + SetGap;

  UpdateZoomLabel;
end;

procedure TfrmMain.UpdateZoomLabel;
begin
  lblZoomValue.Caption := Format('%s: %d%%', [S('lbl_zoom', 'Zoom'), FZoomPercent]);
end;

procedure TfrmMain.tbZoomChange(Sender: TObject);
var SnappedValue: Integer;
begin
  SnappedValue := Round(tbZoom.Position / 10) * 10;
  if tbZoom.Position <> SnappedValue then
  begin
    tbZoom.Position := SnappedValue;
    Exit;
  end;
  ApplyZoom(tbZoom.Position);
  SaveSettingsToIni;
end;

{ === Eventi VST === }

procedure TfrmMain.VSTMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  NewSize: Integer;
begin
  if not (ssCtrl in Shift) then Exit;
  Handled := True;

  // Leggiamo la variabile base invece della dimensione già scalata
  NewSize := FBaseFontSize;

  if WheelDelta > 0 then Inc(NewSize)
  else if WheelDelta < 0 then Dec(NewSize);

  if NewSize < 6 then NewSize := 6;
  if NewSize > 72 then NewSize := 72;

  if NewSize <> FBaseFontSize then
  begin
    // 1. Aggiorniamo la variabile di stato per il salvataggio
    FBaseFontSize := NewSize;

    // 2. Facciamo ricalcolare l'interfaccia (tiene conto anche dello zoom della trackbar)
    ApplyZoom(FZoomPercent);

    // 3. Aggiorniamo le etichette visive
    UpdateFontLabel;

    // 4. Ora l'INI salverà il dato corretto!
    SaveSettingsToIni;
  end;
end;

procedure TfrmMain.VSTKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DELETE then
  begin
    if ssCtrl in Shift then mnuHideTreeClick(nil) else mnuHideFolderClick(nil);
    Key := 0;
  end;
end;

{ === Helpers & Actions === }

function TfrmMain.IsRunningAsAdmin: Boolean;
{$IFDEF WINDOWS}
var hToken: THandle; Elevation: TOKEN_ELEVATION; cbSize: DWORD;
begin
  Result := False;
  hToken := 0;
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, hToken) then
  try
    cbSize := SizeOf(Elevation);
    if GetTokenInformation(hToken, TokenElevation, @Elevation, cbSize, cbSize) then
      Result := Elevation.TokenIsElevated <> 0;
  finally CloseHandle(hToken); end;
end;
{$ELSE}
begin Result := (FpGetuid = 0); end;
{$ENDIF}

procedure TfrmMain.btnAssociateClick(Sender: TObject);
{$IFDEF WINDOWS} var Reg: TRegistry; ExePath: string; {$ENDIF}
begin
  {$IFDEF WINDOWS}
  if not IsRunningAsAdmin then begin ShowMessage(S('msg_need_admin', 'Run Catpaq as Administrator to change file associations.')); Exit; end;
  ExePath := Application.ExeName;
  Reg := TRegistry.Create(KEY_ALL_ACCESS);
  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    Reg.OpenKey('.zpaq', True); Reg.WriteString('', 'CatpaqArchive'); Reg.CloseKey;
    Reg.OpenKey('.franzen', True); Reg.WriteString('', 'CatpaqArchive'); Reg.CloseKey;
    Reg.OpenKey('CatpaqArchive', True); Reg.WriteString('', 'ZPAQ Archive (Catpaq)'); Reg.CloseKey;
    Reg.OpenKey('CatpaqArchive\DefaultIcon', True); Reg.WriteString('', ExePath + ',0'); Reg.CloseKey;
    Reg.OpenKey('CatpaqArchive\shell\open\command', True); Reg.WriteString('', '"' + ExePath + '" "%1"'); Reg.CloseKey;
  finally Reg.Free; end;
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
  ShowMessage(S('msg_assoc_created', 'File associations created for .zpaq and .zpaq.franzen'));
  AddLog('File associations registered.');
  {$ELSE}
  ShowMessage(S('msg_assoc_win_only', 'File associations are only supported on Windows.'));
  {$ENDIF}
end;

procedure TfrmMain.btnDisassociateClick(Sender: TObject);
{$IFDEF WINDOWS} var Reg: TRegistry; {$ENDIF}
begin
  {$IFDEF WINDOWS}
  if not IsRunningAsAdmin then begin ShowMessage(S('msg_need_admin', 'Run Catpaq as Administrator to change file associations.')); Exit; end;
  Reg := TRegistry.Create(KEY_ALL_ACCESS);
  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    if Reg.KeyExists('.zpaq') then Reg.DeleteKey('.zpaq');
    if Reg.KeyExists('.franzen') then Reg.DeleteKey('.franzen');
    if Reg.KeyExists('CatpaqArchive') then Reg.DeleteKey('CatpaqArchive');
  finally Reg.Free; end;
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
  ShowMessage(S('msg_assoc_removed', 'File associations removed.'));
  AddLog('File associations removed.');
  {$ELSE}
  ShowMessage(S('msg_assoc_win_only', 'File associations are only supported on Windows.'));
  {$ENDIF}
end;

procedure TfrmMain.btnChangeTreeFontClick(Sender: TObject);
begin
  FontDialog1.Font.Name := FBaseFont;
  FontDialog1.Font.Size := FBaseFontSize;
  if FontDialog1.Execute then
  begin
    FBaseFont := FontDialog1.Font.Name;
    FBaseFontSize := FontDialog1.Font.Size;
    ApplyZoom(FZoomPercent);
    VST.Invalidate;
    UpdateFontLabel;
    SaveSettingsToIni;
    AddLog('Tree font changed to: ' + FBaseFont + ' ' + IntToStr(FBaseFontSize) + 'pt');
  end;
end;

procedure TfrmMain.btnBrowseBuildClick(Sender: TObject);
begin OpenURL('http://www.francocorbelli.it'); end;

function TfrmMain.IsFocusedNodeFolder: Boolean;
var Node: PVirtualNode; Data: PNodeData; FN: string;
begin
  Result := False;
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  FN := FArchiveData.Files[Data^.FileIndex].FileName;
  if Length(FN) > 0 then Result := (FN[Length(FN)] = '/') or (FN[Length(FN)] = '\');
end;

procedure TfrmMain.PopupMenu1Popup(Sender: TObject);
var IsFolder: Boolean;
begin
  IsFolder := IsFocusedNodeFolder;
  mnuExtractFileGUI.Visible := not IsFolder;
  mnuExtractFileText.Visible := not IsFolder;
  mnuExtractFolderGUI.Visible := IsFolder;
  mnuExtractFolderText.Visible := IsFolder;
  mnuSep1.Visible := True;
  mnuHideFolder.Visible := True;
  mnuHideTree.Visible := True;
  mnuShowAll.Visible := (FHiddenPaths.Count > 0) or (FHiddenTrees.Count > 0);
end;

function TfrmMain.IsPathHidden(const APath: string): Boolean;
var I: Integer;
begin
  Result := False;
  if FHiddenPaths.IndexOf(APath) >= 0 then begin Result := True; Exit; end;
  for I := 0 to FHiddenTrees.Count - 1 do
    if (Length(APath) > Length(FHiddenTrees[I])) and (Pos(FHiddenTrees[I], APath) = 1) then
    begin Result := True; Exit; end;
end;

procedure TfrmMain.HideFolderOnly(const APath: string);
begin FHiddenPaths.Add(APath); BuildFilteredList; RebuildTree; end;

procedure TfrmMain.HideTree(const APath: string);
begin FHiddenTrees.Add(APath); BuildFilteredList; RebuildTree; end;

procedure TfrmMain.ShowAllHidden;
begin FHiddenPaths.Clear; FHiddenTrees.Clear; BuildFilteredList; RebuildTree; end;

procedure TfrmMain.mnuHideFolderClick(Sender: TObject);
var Node: PVirtualNode; Data: PNodeData;
begin
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  HideFolderOnly(FArchiveData.Files[Data^.FileIndex].FileName);
  AddLog('Hidden folder: ' + FArchiveData.Files[Data^.FileIndex].FileName);
end;

procedure TfrmMain.mnuHideTreeClick(Sender: TObject);
var Node: PVirtualNode; Data: PNodeData; FN: string;
begin
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  FN := FArchiveData.Files[Data^.FileIndex].FileName;
  HideTree(FN);
  AddLog('Hidden tree: ' + FN + ' (and all children)');
end;

procedure TfrmMain.mnuShowAllClick(Sender: TObject);
begin ShowAllHidden; AddLog('All hidden items restored'); end;

{ === Extraction === }

function TfrmMain.GetFocusedVersion(out FE: TArchiveFileEntry; out FV: TFileVersion): Boolean;
var Node: PVirtualNode; Data: PNodeData; J, BestIdx, TargetVer: Integer;
begin
  Result := False;
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  FE := FArchiveData.Files[Data^.FileIndex];
  if (not Data^.IsParent) and (Data^.VersionIndex >= 0) and (Data^.VersionIndex <= High(FE.Versions)) then
    FV := FE.Versions[Data^.VersionIndex]
  else if Length(FE.Versions) > 0 then
  begin
    if (FTreeMode = tmSingleVersion) and (FCurrentVersion > 0) and (FCurrentVersion - 1 < Length(FArchiveData.GlobalVersions)) then
    begin
      TargetVer := FArchiveData.GlobalVersions[FCurrentVersion - 1].Number;
      BestIdx := -1;
      for J := 0 to High(FE.Versions) do if FE.Versions[J].Version <= TargetVer then BestIdx := J;
      if BestIdx >= 0 then FV := FE.Versions[BestIdx] else FV := FE.Versions[High(FE.Versions)];
    end else FV := FE.Versions[High(FE.Versions)];
  end else Exit;
  if FV.IsDeleted then begin ShowMessage(S('msg_cannot_extract_deleted', 'Cannot extract a deleted version.')); Exit; end;
  Result := True;
end;

procedure TfrmMain.DoExtractTo(const DestFolder: string);
var FE: TArchiveFileEntry; FV: TFileVersion; Cmd: string;
begin
  if not GetFocusedVersion(FE, FV) then Exit;
  Cmd := Format('x "%s" "%s" -to "%s" -until %d -catpaqmode', [FArchivePath, FE.FileName, DestFolder, FV.Version]);
  if FPasswordKey <> '' then Cmd := Cmd + ' -key "' + FPasswordKey + '"';
  if FPasswordFranzen <> '' then Cmd := Cmd + ' -franzen "' + FPasswordFranzen + '"';
  AddLog('Extracting: ' + FE.FileName + ' (ver ' + IntToStr(FV.Version) + ')');
  AddLog('Destination: ' + DestFolder);
  PageControl1.ActivePage := TabLog;

  FBridgeOp := 'EXTRACT';
  FBridge.IsDataMode := False;
  TimerUpdate.Enabled := True;

  if not FBridge.RunCommandAsync(Cmd) then
  begin
    AddLog('ERROR: Failed to start extraction');
    FBridgeOp := 'LIST';
  end;
end;

procedure TfrmMain.mnuExtractFileGUIClick(Sender: TObject);
begin ShowExtractDialog; end;

procedure TfrmMain.mnuExtractFileTextClick(Sender: TObject);
var DestPath: string;
begin
  DestPath := InputBox(S('dlg_extract_file_title', 'Extract file to folder'), S('dlg_extract_path_prompt', 'Enter the destination folder path:'), '');
  if DestPath = '' then Exit;
  if not ForceDirectories(DestPath) then begin ShowMessage(S('msg_cannot_create_folder', 'Cannot create folder: ') + DestPath); Exit; end;
  DoExtractTo(DestPath);
end;

procedure TfrmMain.mnuExtractFolderGUIClick(Sender: TObject);
begin ShowExtractDialog; end;

procedure TfrmMain.mnuExtractFolderTextClick(Sender: TObject);
var DestPath: string;
begin
  DestPath := InputBox(S('dlg_extract_folder_title', 'Extract folder to'), S('dlg_extract_path_prompt', 'Enter the destination folder path:'), '');
  if DestPath = '' then Exit;
  if not ForceDirectories(DestPath) then begin ShowMessage(S('msg_cannot_create_folder', 'Cannot create folder: ') + DestPath); Exit; end;
  DoExtractTo(DestPath);
end;

procedure TfrmMain.mnuExtractAllClick(Sender: TObject);
begin ShowExtractAllDialog; end;

procedure TfrmMain.mnuAddExtractToFolderClick(Sender: TObject);
var
  FilePath: string;
  Dialog: TfrmExtract;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then begin ShowMessage('No ZPAQ archive selected.'); Exit; end;

  Dialog := TfrmExtract.Create(Self);
  try
    Dialog.SetExtractionParamsAll(FilePath, FPasswordKey, FPasswordFranzen);
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then
      AddLog('Extraction destination: ' + Dialog.GetDestPath);
  finally
    Dialog.Free;
  end;
end;

{ Apre l'archivio .zpaq selezionato in modalità Time Machine (TabArchive),
  indipendentemente dal numero di versioni. Questo era il comportamento
  precedente del doppio click per archivi con 2+ versioni. }
procedure TfrmMain.mnuAddBrowseVersionsClick(Sender: TObject);
var
  FilePath: string;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then
  begin
    ShowMessage(S('msg_no_zpaq_selected', 'No ZPAQ archive selected.'));
    Exit;
  end;
  if FLoadingArchive then Exit;

  AddLog('Browse all versions: ' + FilePath);
  FLoadingArchive       := True;
  FLogProgressLineIndex := -1;
  FFileListAbortRequested    := False;
  { Svuota FArchiveBrowsePath così OnBridgeComplete va in TabArchive (Time Machine) }
  FArchiveBrowsePath    := '';
  SetLoadingState(True);
  PageControl1.ActivePage := TabLog;
  DoLoadArchive(FilePath);
end;

procedure TfrmMain.mnuAddTestZpaqClick(Sender: TObject);
var FilePath: string;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then begin ShowMessage('No ZPAQ archive selected.'); Exit; end;
  ShowTestDialog(FilePath);
end;

procedure TfrmMain.mnuAddTestAllZpaqClick(Sender: TObject);
var FilePath: string;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then begin ShowMessage('No ZPAQ archive selected.'); Exit; end;
  ShowTestDialog(FilePath);
end;

procedure TfrmMain.ShowTestDialog(const AArchivePath: string);
var Dialog: TfrmExtract;
begin
  if AArchivePath = '' then Exit;
  Dialog := TfrmExtract.Create(Self);
  try
    Dialog.SetTestParams(AArchivePath, FPasswordKey, FPasswordFranzen);
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.ShowModal;
  finally Dialog.Free; end;
end;

procedure TfrmMain.mnuCopyFileNameClick(Sender: TObject);
var Node: PVirtualNode; Data: PNodeData;
begin
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  Clipboard.AsText := ExtractFileName(ExcludeTrailingPathDelimiter(FArchiveData.Files[Data^.FileIndex].FileName));
end;

procedure TfrmMain.mnuCopyFullPathClick(Sender: TObject);
var Node: PVirtualNode; Data: PNodeData;
begin
  Node := VST.FocusedNode; if Node = nil then Exit;
  Data := VST.GetNodeData(Node);
  if (Data = nil) or (Data^.FileIndex < 0) then Exit;
  Clipboard.AsText := FArchiveData.Files[Data^.FileIndex].FileName;
end;

procedure TfrmMain.mnuExpandAllClick(Sender: TObject);
begin VST.FullExpand; end;

procedure TfrmMain.mnuCollapseAllClick(Sender: TObject);
begin VST.FullCollapse; end;

procedure TfrmMain.PageControl1Change(Sender: TObject);
begin
  // Blocca il cambio tab durante il caricamento
  if FLoadingArchive then
  begin
    if FLoadFromBrowseTab then
      PageControl1.ActivePage := TabAdd   // resta sulla tab Browse
    else
      PageControl1.ActivePage := TabLog;  // resta sulla tab Log
    Exit;
  end;
  if PageControl1.ActivePage = TabAdd then RefreshAddFilesList;
end;

procedure TfrmMain.SetLoadingState(ALoading: Boolean);
begin
  if FLoadFromBrowseTab then
  begin
    // === Caricamento avviato dalla tab Browse: usa pnlLoading sovrapposto al file list ===
    pnlLoading.Visible := ALoading;
    btnAbortLoading.Enabled := ALoading;
    pnlLogToolbar.Visible := False; // non serve il toolbar del log
    if ALoading then
    begin
      lblLoadingETA.Caption := '00:00:00';
      pgrLoading.Position := 0;
      pgrLoading.Max := 100;
      // Resta sulla tab Browse, NON cambiare tab
    end;
  end
  else
  begin
    // === Caricamento avviato dal log o da Open: comportamento originale ===
    pnlLogToolbar.Visible := ALoading;
    pnlLoading.Visible := False;
    if ALoading then
    begin
      lblLogStatus.Caption := 'Loading archive: ' + ExtractFileName(FArchivePath);
      PageControl1.ActivePage := TabLog;
    end;
  end;

  btnAbortLoading.Enabled := ALoading;
  // Impedisce cambio tab durante il caricamento (tranne la tab corrente)
  TabArchive.Enabled  := not ALoading;
  TabSettings.Enabled := not ALoading;
  if FLoadFromBrowseTab then
  begin
    TabAdd.Enabled := True; // restiamo qui
    TabLog.Enabled := not ALoading;
  end
  else
  begin
    TabAdd.Enabled := not ALoading;
    TabLog.Enabled := True; // restiamo qui
  end;
end;

procedure TfrmMain.btnAbortLoadClick(Sender: TObject);
begin
  btnAbortLoading.Enabled := False;
  lblLogStatus.Caption := 'Aborting...';
  AddArchiveLog('*** ABORT requested by user ***');
  FileListDbgWrite('btnAbortLoadClick: ABORT requested');

  // Percorso EXE asincrono: termina il processo
  if FBridge.Busy then
    FBridge.AbortCommand;

  // Percorso file-based thread: setta il flag e termina il thread
  FFileListAbortRequested := True;
  if Assigned(FileListThread) then
    FileListThread.Terminate;

  FileListDbgWrite('btnAbortLoadClick: abort flags set');
end;

{ Aggiorna la progress bar dalla GUI — chiamato nel thread principale via QueueAsyncCall.
  Riceve la percentuale dalle righe @SPK@DEC@ (0-99, fase decompressione) e W (10-90, fase output). }
procedure TfrmMain.FileListGuiUpdate(Data: PtrInt);
var Pct: Integer;
    ElapsedSecs: Double;
    ETASecs: Int64;
begin
  Pct := Integer(Data);
  if Pct < 0 then Pct := 0;
  if Pct > 100 then Pct := 100;
  pgrProgressLog.Max := 100;
  pgrProgressLog.Position := Pct;
  pgrProgresso.Max := 100;
  pgrProgresso.Position := Pct;
  // Workaround animazione Aero
  if Pct < pgrProgressLog.Max then
  begin
    pgrProgressLog.Position := Pct + 1;
    pgrProgressLog.Position := Pct;
  end;
  lblLoadInfo.Caption := 'Lettura archivio: ' + IntToStr(Pct) + '%';

  // === Aggiorna anche pnlLoading (visibile quando FLoadFromBrowseTab) ===
  if FLoadFromBrowseTab and pnlLoading.Visible then
  begin
    pgrLoading.Max := 100;
    pgrLoading.Position := Pct;
    // Workaround animazione Aero anche per pgrLoading
    if Pct < pgrLoading.Max then
    begin
      pgrLoading.Position := Pct + 1;
      pgrLoading.Position := Pct;
    end;
    // Calcola ETA basato sul tempo trascorso e la percentuale
    if Pct > 0 then
    begin
      ElapsedSecs := (Now - FLoadStartTime) * 86400.0;
      ETASecs := Round(ElapsedSecs * (100 - Pct) / Pct);
      lblLoadingETA.Caption := FormatETA(ETASecs);
    end
    else
      lblLoadingETA.Caption := '--:--:--';
  end;

  // Processa eventi GUI in coda (rende il bottone ABORT reattivo)
  Application.ProcessMessages;
end;


{ Chiamato dal thread principale via QueueAsyncCall quando TFileListThread termina. }
procedure TfrmMain.OnFileListComplete(Data: PtrInt);
var
  ElapsedSecs: Double;
  WasAborted: Boolean;
  TempFile: string;
  I: Integer;
begin
  FileListDbgWrite('OnFileListComplete: START');

  TempFile := '';

  // Attendi che il thread sia davvero terminato e recupera i risultati
  if Assigned(FileListThread) then
  begin
    FileListDbgWrite('OnFileListComplete: waiting for thread...');
    FileListThread.WaitFor;
    TempFile := FileListThread.TempFile;
    FileListDbgWrite('OnFileListComplete: thread done. TempFile=' + TempFile +
                     ' Success=' + BoolToStr(FileListThread.Success, 'T', 'F') +
                     ' ExitCode=' + IntToStr(FileListThread.ExitCode) +
                     ' StderrLines=' + IntToStr(FileListThread.StderrLog.Count));

    { Mostra le righe stderr nel memArchive (output zpaqfranz: info, errori) }
    if FileListThread.StderrLog.Count > 0 then
    begin
      memArchive.Lines.BeginUpdate;
      try
        for I := 0 to FileListThread.StderrLog.Count - 1 do
          memArchive.Lines.Add(FileListThread.StderrLog[I]);
        memArchive.SelStart := Length(memArchive.Text);
      finally
        memArchive.Lines.EndUpdate;
      end;
    end;

    FreeAndNil(FileListThread);
  end;

  WasAborted := FFileListAbortRequested;
  FileListDbgWrite('OnFileListComplete: WasAborted=' + BoolToStr(WasAborted, 'T', 'F'));

  if WasAborted then
  begin
    AddArchiveLog('*** Loading ABORTED by user ***');
    FileListDbgWrite('OnFileListComplete: ABORT path');
    if not FKeepTempFiles then
    begin
      if (TempFile <> '') and FileExists(TempFile) then
      begin
        SysUtils.DeleteFile(TempFile);
        FileListDbgWrite('OnFileListComplete: temp file deleted: ' + TempFile);
      end;
    end
    else
      AddArchiveLog('DEBUG: Temp file kept: ' + TempFile);
    pgrProgresso.Position   := 0;
    pgrProgressLog.Position := 0;
    btnOpen.Enabled := True;
    FLoadingArchive := False;
    FLogProgressLineIndex := -1;
    SetLoadingState(False);
    FLoadFromBrowseTab := False;
    Exit;
  end;

  // Verifica che il file temporaneo esista
  if (TempFile = '') or not FileExists(TempFile) then
  begin
    AddArchiveLog('ERROR: Temp file not found or empty: ' + TempFile);
    FileListDbgWrite('OnFileListComplete: ERROR temp file missing');
    pgrProgresso.Position   := 0;
    pgrProgressLog.Position := 0;
    btnOpen.Enabled := True;
    FLoadingArchive := False;
    FLogProgressLineIndex := -1;
    SetLoadingState(False);
    FLoadFromBrowseTab := False;
    Exit;
  end;

  // Salva il path per riferimento debug
  FTempListFile := TempFile;
  AddArchiveLog('Temp listing file: ' + TempFile);
  AddArchiveLog('Temp file size: ' + IntToStr(FileSizeByName(TempFile)) + ' bytes');
  FileListDbgWrite('OnFileListComplete: starting ParsePakkaListFromFile...');

  // Progress bar al 100% durante il parsing
  pgrProgressLog.Position := 100;
  pgrProgresso.Position := 100;
  lblLoadInfo.Caption := 'Parsing temp file...';
  if FLoadFromBrowseTab and pnlLoading.Visible then
  begin
    pgrLoading.Position := 100;
    lblLoadingETA.Caption := 'Parsing...';
  end;
  Application.ProcessMessages;

  // Controlla se l'utente ha premuto Abort nel frattempo
  if FFileListAbortRequested then
  begin
    AddArchiveLog('*** Loading ABORTED by user (before parsing) ***');
    FileListDbgWrite('OnFileListComplete: ABORT before parse');
    if not FKeepTempFiles then
      if (TempFile <> '') and FileExists(TempFile) then
        SysUtils.DeleteFile(TempFile);
    pgrProgresso.Position   := 0;
    pgrProgressLog.Position := 0;
    btnOpen.Enabled := True;
    FLoadingArchive := False;
    FLogProgressLineIndex := -1;
    SetLoadingState(False);
    FLoadFromBrowseTab := False;
    Exit;
  end;

  // Parsing dei dati dal file temporaneo (riga per riga, senza caricare tutto in RAM)
  try
    FArchiveData := FBridge.ParsePakkaListFromFile(TempFile);
  except
    on E: Exception do
    begin
      AddArchiveLog('ERROR during parsing: ' + E.ClassName + ': ' + E.Message);
      FileListDbgWrite('OnFileListComplete: PARSE EXCEPTION: ' + E.Message);
    end;
  end;

  FileListDbgWrite('OnFileListComplete: parse done. Versions=' +
                   IntToStr(Length(FArchiveData.GlobalVersions)) +
                   ' Files=' + IntToStr(Length(FArchiveData.Files)));

  { Cleanup file temporaneo }
  if not FKeepTempFiles then
  begin
    if FileExists(TempFile) then
    begin
      SysUtils.DeleteFile(TempFile);
      FileListDbgWrite('OnFileListComplete: temp file deleted');
    end;
  end
  else
    AddArchiveLog('DEBUG: Temp file kept: ' + TempFile);

  AddArchiveLog('Found ' + IntToStr(Length(FArchiveData.GlobalVersions)) +
         ' versions, ' + IntToStr(Length(FArchiveData.Files)) + ' files');

  FileListDbgWrite('OnFileListComplete: calling SetupTrackBar...');
  SetupTrackBar;
  FileListDbgWrite('OnFileListComplete: SetupTrackBar done');

  FileListDbgWrite('OnFileListComplete: calling BuildFilteredList...');
  BuildFilteredList;
  FileListDbgWrite('OnFileListComplete: BuildFilteredList done. FilteredFiles=' +
                   IntToStr(Length(FFilteredFiles)));

  FileListDbgWrite('OnFileListComplete: calling RebuildTree...');
  RebuildTree;
  FileListDbgWrite('OnFileListComplete: RebuildTree done');

  lblArchiveInfo.Caption  := ExtractFileName(FArchivePath);
  pgrProgresso.Position   := 0;
  pgrProgressLog.Position := 0;

  ElapsedSecs := (Now - FLoadStartTime) * 86400.0;
  lblLoadInfo.Caption := Format(S('lbl_loaded_fmt', '%d files loaded in %.3f s'),
                                [Length(FArchiveData.Files), ElapsedSecs]);
  AddArchiveLog(Format('%d files loaded in %.3f s', [Length(FArchiveData.Files), ElapsedSecs]));
  btnOpen.Enabled := True;

  FLoadingArchive := False;
  FLogProgressLineIndex := -1;

  FileListDbgWrite('OnFileListComplete: calling SetLoadingState(False)...');
  SetLoadingState(False);
  FLoadFromBrowseTab := False;
  FileListDbgWrite('OnFileListComplete: SetLoadingState done');

  FileListDbgWrite('OnFileListComplete: switching to tab...');

  // Doppio click su .zpaq → browse mode (ultima versione, senza -all)
  // Richiesta esplicita "all versions" → TabArchive (VirtualStringTree, con -all)
  if (FArchiveBrowsePath <> '') and (Length(FArchiveData.Files) > 0) then
  begin
    FileListDbgWrite('OnFileListComplete: calling ShowArchiveBrowse...');
    ShowArchiveBrowse(FArchiveBrowsePath, FArchiveData);
    FileListDbgWrite('OnFileListComplete: ShowArchiveBrowse done');
  end
  else
  begin
    FArchiveBrowsePath := '';
    FileListDbgWrite('OnFileListComplete: setting ActivePage to TabArchive...');
    PageControl1.ActivePage := TabArchive;
    FileListDbgWrite('OnFileListComplete: ActivePage set');
  end;

  FileListDbgWrite('OnFileListComplete: === ALL DONE ===');
end;

procedure TfrmMain.PanelBottomResize(Sender: TObject);
var
  loadleft:integer;
  loadtop:integer;
begin
  btnTimeMachine.Width := tpanel(sender).width- btnTimeMachine.Left - 4;
  edtaddpath.width:=pnladdnav.width-edtaddpath.left-4;
  btnexit2.left:=pnladdtoolbar.width-btnexit2.width-4;
  loadleft:=(lvaddfiles.width-pnlloading.Width) div 2;
  if (loadleft>0) then
  pnlloading.left:=loadleft
  else
  pnlloading.left:=0;

  loadtop:=lvaddfiles.top+(lvaddfiles.height-pnlloading.height) div 2;
  if (loadtop>0) then
  pnlloading.top:=loadtop
  else
  pnlloading.top:=0;
end;

{ === Archive loading === }

procedure TfrmMain.btnOpenClick(Sender: TObject);
begin
  if FBridge.Busy then begin ShowMessage(S('msg_busy', 'Operation in progress, please wait.')); Exit; end;
  if OpenDialog1.Execute then
  begin
    { Apertura da bottone Open = tutte le versioni → FArchiveBrowsePath vuoto → -all }
    FArchiveBrowsePath := '';
    DoLoadArchive(OpenDialog1.FileName);
  end;
end;

procedure TfrmMain.btnExit2Click(Sender: TObject);
begin
  close;
end;

procedure TfrmMain.btnAbortLoadingClick(Sender: TObject);
begin
  btnAbortLoading.Enabled := False;
  lblLoadingETA.Caption := 'Aborting...';
  AddArchiveLog('*** ABORT requested by user (browse panel) ***');
  FileListDbgWrite('btnAbortLoadingClick: ABORT requested');

  // Percorso EXE asincrono: termina il processo
  if FBridge.Busy then
    FBridge.AbortCommand;

  // Percorso file-based thread: setta il flag e termina il thread
  FFileListAbortRequested := True;
  if Assigned(FileListThread) then
    FileListThread.Terminate;

  FileListDbgWrite('btnAbortLoadingClick: abort flags set');
end;

procedure TfrmMain.DoLoadArchive(const AFileName: string);
begin
  if not FileExists(AFileName) then begin ShowMessage(S('msg_file_not_found', 'File not found: ') + AFileName); Exit; end;
  FArchivePath := AFileName;
  FArchiveType := DetectArchiveType(FArchivePath);
  lblArchiveInfo.Caption := ExtractFileName(FArchivePath) + ' ' + ArchiveTypeToStr(FArchiveType);
  AddLog('');
  AddLog('Opening: ' + FArchivePath);
  AddLog('Type: ' + ArchiveTypeToStr(FArchiveType));
  if FArchiveType = atUnknown then begin ShowMessage(S('msg_unknown_type', 'Unknown or invalid file type: ') + FArchivePath); Exit; end;
  FPasswordKey := '';
  FPasswordFranzen := '';
  FHiddenPaths.Clear;
  FHiddenTrees.Clear;
  AskPasswords;
  RunPakkaList;
end;

procedure TfrmMain.AskPasswords;
begin
  case FArchiveType of
    atZpaqAes: begin
      if password_aes <> '' then
      begin
        FPasswordKey := password_aes;
        AddLog('Using AES password from command line');
      end
      else
      begin
        FPasswordKey := InputBox(S('dlg_aes_title', 'AES Password Required'), S('dlg_aes_prompt', 'Enter AES password (-key):'), '');
        if FPasswordKey = '' then begin AddLog('Cancelled: no AES password provided'); Abort; end;
      end;
    end;
    atFranzen: begin
      if password_franzen <> '' then
      begin
        FPasswordFranzen := password_franzen;
        AddLog('Using Franzen password from command line');
      end
      else
      begin
        FPasswordFranzen := InputBox(S('dlg_franzen_title', 'Franzen Password Required'), S('dlg_franzen_prompt', 'Enter Franzen password (-franzen):'), '');
        if FPasswordFranzen = '' then begin AddLog('Cancelled: no Franzen password provided'); Abort; end;
      end;
    end;
    atAesFranzen: begin
      if password_aes <> '' then
      begin
        FPasswordKey := password_aes;
        AddLog('Using AES password from command line');
      end
      else
      begin
        FPasswordKey := InputBox(S('dlg_aes_title_12', 'AES Password Required (1/2)'), S('dlg_aes_prompt', 'Enter AES password (-key):'), '');
        if FPasswordKey = '' then begin AddLog('Cancelled: no AES password provided'); Abort; end;
      end;
      if password_franzen <> '' then
      begin
        FPasswordFranzen := password_franzen;
        AddLog('Using Franzen password from command line');
      end
      else
      begin
        FPasswordFranzen := InputBox(S('dlg_franzen_title_22', 'Franzen Password Required (2/2)'), S('dlg_franzen_prompt', 'Enter Franzen password (-franzen):'), '');
        if FPasswordFranzen = '' then begin AddLog('Cancelled: no Franzen password provided'); Abort; end;
      end;
    end;
  end;
end;

function TfrmMain.BuildCommandString: string;
begin
  Result := 'pakka "' + FArchivePath + '" -catpaqmode';
  { -all solo se NON siamo in browse mode (doppio click mostra solo ultima versione) }
  if FArchiveBrowsePath = '' then
    Result := Result + ' -all';
  if FPasswordKey <> '' then Result := Result + ' -key "' + FPasswordKey + '"';
  if FPasswordFranzen <> '' then Result := Result + ' -franzen "' + FPasswordFranzen + '"';
end;

procedure TfrmMain.RunPakkaList;
var
  CmdStr, TempPath: string;
begin
  pgrProgresso.Position := 0;
  VST.Clear;
  SetLength(FArchiveData.GlobalVersions, 0);
  SetLength(FArchiveData.Files, 0);
  SetLength(FFilteredFiles, 0);
  FCurrentVersion := 0;
  FFilterText := '';
  edtFilter.Text := '';

  TrackBar1.OnChange := nil;
  TrackBar1.Position := 0;
  TrackBar1.Max := 0;
  TrackBar1.OnChange := @TrackBar1Change;

  FBridgeOp := 'LIST';

  btnOpen.Enabled := False;
  lblArchiveInfo.Caption := ExtractFileName(FArchivePath) + ' (' + S('lbl_loading', 'loading...') + ')';
  FLoadStartTime := Now;
  FFileListAbortRequested := False;

  CmdStr := BuildCommandString;

  FileListDbgWrite('RunPakkaList: START');
  FileListDbgWrite('RunPakkaList: Archive=' + FArchivePath);
  FileListDbgWrite('RunPakkaList: Command=' + CmdStr);
  FileListDbgWrite('RunPakkaList: ExePath=' + FBridge.ExternalPath);



  { === Percorso file temporaneo (default, tutte le piattaforme) === }
  TempPath := FBridge.GetTempListingPath;
  FTempListFile := TempPath;

  FileListDbgWrite('RunPakkaList: TempFile=' + TempPath);

  lblLoadInfo.Caption := S('lbl_loading', 'Loading via temp file...');
  Application.ProcessMessages;
  AddArchiveLog('Running pakka list via -out temp file...');
  AddArchiveLog('Command: ' + CmdStr + ' -out "' + TempPath + '"');

  SetLoadingState(True);

  pgrProgresso.Max := 100;
  pgrProgresso.Position := 0;
  pgrProgressLog.Max := 100;
  pgrProgressLog.Position := 0;
  lblLoadInfo.Caption := 'zpaqfranz writing to temp file...';

  FileListThread := TFileListThread.Create(FBridge, CmdStr, TempPath);
  FileListThread.Start;

  FileListDbgWrite('RunPakkaList: file thread started, returning to main loop');
end;
{ === Evento Progress Telemetria === }
procedure TfrmMain.OnBridgeProgress(Sender: TObject; Percent: Integer; const AMsg: string);
begin
  if FBridgeOp = 'HASH' then
  begin
    pgrProgressLog.Position := Percent;
    if FBridge.ProgTotali > 0 then
      lblLoadInfo.Caption := Format('Hashing in progress: %d%% (%s / %s)',
        [Percent, FormatFileSize(FBridge.ProgLavorati), FormatFileSize(FBridge.ProgTotali)])
    else
      lblLoadInfo.Caption := Format('Hashing in progress: %d%%', [Percent]);
    Exit;
  end;

  if FBridgeOp = 'TEST' then
  begin
    pgrProgressLog.Position := Percent;
    // Build decoded progress line
    if FBridge.ProgTotali > 0 then
      lblLoadInfo.Caption := Format('Testing: %d%% - %s / %s - ETA %s',
        [Percent,
         FormatFileSize(FBridge.ProgLavorati),
         FormatFileSize(FBridge.ProgTotali),
         FormatETA(FBridge.ProgETA)])
    else
      lblLoadInfo.Caption := Format('Testing: %d%%', [Percent]);

    // Update in-place progress line in MemoLog
    MemoLog.Lines.BeginUpdate;
    try
      if (FTestProgressLineIndex >= 0) and (FTestProgressLineIndex < MemoLog.Lines.Count) then
        MemoLog.Lines[FTestProgressLineIndex] := lblLoadInfo.Caption
      else
      begin
        MemoLog.Lines.Add(lblLoadInfo.Caption);
        FTestProgressLineIndex := MemoLog.Lines.Count - 1;
      end;
    finally
      MemoLog.Lines.EndUpdate;
    end;
    Exit;
  end;

  // Avanzamento LIST: aggiorna barra di progresso.
  // Le righe "Scan NNN%" intercettate dal bridge triggerano questo path.
  // pgrProgressLog è visibile nella TabLog (mostrata durante il caricamento).
  pgrProgressLog.Max := 100;
  pgrProgressLog.Position := Percent;
  pgrProgresso.Position := Percent;
  lblLoadInfo.Caption := Format(S('lbl_loading_pct', 'Loading: %d%%'), [Percent]);

  // === Aggiorna anche pnlLoading (visibile quando FLoadFromBrowseTab) ===
  if FLoadFromBrowseTab and pnlLoading.Visible then
  begin
    pgrLoading.Max := 100;
    pgrLoading.Position := Percent;
    if Percent > 0 then
      lblLoadingETA.Caption := FormatETA(Round((Now - FLoadStartTime) * 86400.0 * (100 - Percent) / Percent))
    else
      lblLoadingETA.Caption := '--:--:--';
  end;

  Application.ProcessMessages;
end;

procedure TfrmMain.OnBridgeComplete(Sender: TObject; ExitCode: Integer);
var
  DataBuf: TStringList;
  LogBuf: TStringList;
  I, Minimo: Integer;
  ElapsedSecs: Double;
  HashLine, TheHash: string;
begin
  TimerUpdate.Enabled := False;
  btnOpen.Enabled := True;

  // --- LOGICA HASHING ---
  if FBridgeOp = 'HASH' then
  begin
    pgrProgressLog.Position := 0;
    lblLoadInfo.Caption := 'Operazione hash conclusa (ExitCode: ' + IntToStr(ExitCode) + ')';
    AddLog(S('msg_hash_completed', 'Hash operation completed.'));

    LogBuf := FBridge.FlushLogBuffer;
    try
      CleanLogBuffer(LogBuf);

      if LogBuf.Count > 0 then
      begin
        MemoLog.Lines.BeginUpdate;
        try
          MemoLog.Lines.AddStrings(LogBuf);
          MemoLog.SelStart := Length(MemoLog.Text);
        finally
          MemoLog.Lines.EndUpdate;
        end;

        // Se un solo file su Windows, copia l'hash negli appunti
        {$IFDEF WINDOWS}
        if FHashFileCount = 1 then
        begin
          // Ricerca dal basso verso l'alto l'ultima stringa utile
          for I := MemoLog.Lines.Count - 1 downto 0 do
          begin
            HashLine := Trim(MemoLog.Lines[I]);
            // Una linea di output hash di zpaqfranz è tipo: "6dfc26c9... j:/win11.zpaq"
            // Evitiamo le righe con '[' generate dai nostri AddLog interni
            if (HashLine <> '') and (Pos(' ', HashLine) > 0) and (Pos('[', HashLine) = 0) then
            begin
              TheHash := Copy(HashLine, 1, Pos(' ', HashLine) - 1);
              if Length(TheHash) >= 8 then
              begin
                Clipboard.AsText := TheHash;
                AddLog('>>> HASH COPIATO NEGLI APPUNTI: ' + TheHash);
                ShowMessage('L''hash calcolato è stato copiato negli appunti:'#13#10 + TheHash);
                Break;
              end;
            end;
          end;
        end;
        {$ENDIF}
      end;
    finally
      LogBuf.Free;
    end;

    FBridgeOp := 'LIST'; // Ripristina
    Exit;
  end;

  // --- LOGICA EXTRACT (via Main) ---
  if FBridgeOp = 'EXTRACT' then
  begin
    AddLog('Extraction completed, exit code: ' + IntToStr(ExitCode));
    LogBuf := FBridge.FlushLogBuffer;
    try
      CleanLogBuffer(LogBuf);

      if LogBuf.Count > 0 then begin MemoLog.Lines.BeginUpdate; try MemoLog.Lines.AddStrings(LogBuf); finally MemoLog.Lines.EndUpdate; end; end;
    finally LogBuf.Free; end;

    if ExitCode = 0 then ShowMessage('Estrazione completata con successo!')
    else ShowMessage('Errore durante l''estrazione! Controlla il log.');

    FBridgeOp := 'LIST';
    Exit;
  end;

  // --- LOGICA TEST ---
  if FBridgeOp = 'TEST' then
  begin
    pgrProgressLog.Position := 0;

    // Replace the in-place progress line (if present) with the final verdict
    if ExitCode = 0 then
      lblLoadInfo.Caption := 'Test OK'
    else
      lblLoadInfo.Caption := 'Test FAILED (exit code: ' + IntToStr(ExitCode) + ')';

    if (FTestProgressLineIndex >= 0) and (FTestProgressLineIndex < MemoLog.Lines.Count) then
      MemoLog.Lines[FTestProgressLineIndex] := '--- ' + lblLoadInfo.Caption + ' ---'
    else
      AddLog('--- ' + lblLoadInfo.Caption + ' ---');
    FTestProgressLineIndex := -1;

    LogBuf := FBridge.FlushLogBuffer;
    try
      CleanLogBuffer(LogBuf);
      if LogBuf.Count > 0 then
      begin
        MemoLog.Lines.BeginUpdate;
        try
          MemoLog.Lines.AddStrings(LogBuf);
          MemoLog.SelStart := Length(MemoLog.Text);
        finally
          MemoLog.Lines.EndUpdate;
        end;
      end;
    finally LogBuf.Free; end;

    FBridgeOp := 'LIST';
    Exit;
  end;

  // --- LOGICA PAKKA LIST ---
  FBridge.IsDataMode := False;
  AddLog('Command completed, exit code: ' + IntToStr(ExitCode));
  DataBuf := FBridge.FlushLogBuffer;
  try
    CleanLogBuffer(DataBuf);

    if DataBuf.Count > 0 then begin MemoLog.Lines.BeginUpdate; try MemoLog.Lines.AddStrings(DataBuf); finally MemoLog.Lines.EndUpdate; end; end;
  finally DataBuf.Free; end;

  DataBuf := FBridge.FlushDataBuffer;
  try
    AddLog('Parsing ' + IntToStr(DataBuf.Count) + ' data lines...');
    if DataBuf.Count > 0 then
    begin
      Minimo := Min(9, DataBuf.Count - 1);
      AddLog('--- First lines in DataBuffer:');
      for I := 0 to Minimo do AddLog('  [' + IntToStr(I) + '] ' + DataBuf[I]);
      AddLog('--- End DataBuffer sample');
    end else AddLog('WARNING: DataBuffer is empty! Check passwords or file path.');
    FArchiveData := FBridge.ParsePakkaList(DataBuf);
  finally DataBuf.Free; end;

  AddArchiveLog('Found ' + IntToStr(Length(FArchiveData.GlobalVersions)) + ' versions, ' + IntToStr(Length(FArchiveData.Files)) + ' files');
  SetupTrackBar;
  BuildFilteredList;
  RebuildTree;

  lblArchiveInfo.Caption := ExtractFileName(FArchivePath);
  pgrProgresso.Position := 0;
  pgrProgressLog.Position := 0;
  ElapsedSecs := (Now - FLoadStartTime) * 86400.0;
  lblLoadInfo.Caption := Format(S('lbl_loaded_fmt', '%d files loaded in %.1f s'), [Length(FArchiveData.Files), ElapsedSecs]);

  // Resetta il lock di caricamento
  FLoadingArchive := False;
  FLogProgressLineIndex := -1;
  SetLoadingState(False);

  // Doppio click su .zpaq → browse mode (ultima versione)
  // Richiesta esplicita "all versions" → TabArchive
  if (FArchiveBrowsePath <> '') and (Length(FArchiveData.Files) > 0) then
  begin
    ShowArchiveBrowse(FArchiveBrowsePath, FArchiveData);
    { FArchiveBrowsePath NON azzerato: serve al popup Test/Extract in browse mode }
  end
  else
  begin
    FArchiveBrowsePath := '';
    PageControl1.ActivePage := TabArchive;
  end;
end;

{ === Timer === }

procedure TfrmMain.TimerUpdateTimer(Sender: TObject);
var
  LogBuf: TStringList;
  I: Integer;
  Line, TrimLine: string;
  IsScanLine: Boolean;
begin
  LogBuf := FBridge.FlushLogBuffer;
  try
    CleanLogBuffer(LogBuf);

    if LogBuf.Count > 0 then
    begin
      MemoLog.Lines.BeginUpdate;
      try
        for I := 0 to LogBuf.Count - 1 do
        begin
          Line     := LogBuf[I];
          TrimLine := Trim(Line);

          // Le righe "Scan NNN% ..." vengono mostrate in-place nel MemoLog:
          // sovrascrivono la riga precedente invece di accumularne una per ogni tick.
          IsScanLine := (Length(TrimLine) >= 8) and (Copy(TrimLine, 1, 5) = 'Scan ');

          if IsScanLine then
          begin
            if (FLogProgressLineIndex >= 0) and
               (FLogProgressLineIndex < MemoLog.Lines.Count) then
              MemoLog.Lines[FLogProgressLineIndex] := TrimLine
            else
            begin
              MemoLog.Lines.Add(TrimLine);
              FLogProgressLineIndex := MemoLog.Lines.Count - 1;
            end;
          end
          else
          begin
            // Riga normale: aggiunge e reset dell'indice in-place
            MemoLog.Lines.Add(Line);
            FLogProgressLineIndex := -1;
          end;
        end;
        MemoLog.SelStart := Length(MemoLog.Text);
      finally
        MemoLog.Lines.EndUpdate;
      end;
    end;
  finally
    LogBuf.Free;
  end;
end;

{ === TrackBar / Time Machine === }

procedure TfrmMain.SetupTrackBar;
begin
  TrackBar1.OnChange := nil; // Disabilita temporaneamente l'evento per non fare double-refresh
  try
    TrackBar1.Min := 0;
    TrackBar1.Max := Length(FArchiveData.GlobalVersions);

    // Novità: Per impostazione predefinita posiziona sulla versione più recente
    if TrackBar1.Max > 0 then
    begin
      TrackBar1.Position := TrackBar1.Max;
      FCurrentVersion := TrackBar1.Max;
      FTreeMode := tmSingleVersion;
    end
    else
    begin
      TrackBar1.Position := 0;
      FCurrentVersion := 0;
      FTreeMode := tmAllVersions;
    end;

    UpdateTimeMachineCaption;
  finally
    TrackBar1.OnChange := @TrackBar1Change;
  end;
end;

procedure TfrmMain.TrackBar1Change(Sender: TObject);
begin
  FCurrentVersion := TrackBar1.Position;
  UpdateTimeMachineCaption;
  if FCurrentVersion = 0 then FTreeMode := tmAllVersions else FTreeMode := tmSingleVersion;
  BuildFilteredList; RebuildTree;
end;

procedure TfrmMain.UpdateTimeMachineCaption;
var Idx: Integer;
begin
  if FCurrentVersion = 0 then
    btnTimeMachine.Caption := S('btn_all_versions', 'Show ALL versions (Explorer View)')
  else begin
    Idx := FCurrentVersion - 1;
    if (Idx >= 0) and (Idx < Length(FArchiveData.GlobalVersions)) then
      btnTimeMachine.Caption := Format(S('btn_time_machine_fmt', 'Time Machine -> Ver %d / %s'),
        [FArchiveData.GlobalVersions[Idx].Number, FArchiveData.GlobalVersions[Idx].DateStr])
    else btnTimeMachine.Caption := S('btn_unknown_version', 'Unknown Version');
  end;
end;

procedure TfrmMain.btnTimeMachineClick(Sender: TObject);
begin TrackBar1.Position := 0; end;

{ === Filter === }

procedure TfrmMain.edtFilterKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then begin Key := #0; FFilterText := edtFilter.Text; BuildFilteredList; RebuildTree; end;
end;

procedure TfrmMain.BuildFilteredList;
var I, J, TargetVer, Count, BestIdx: Integer; Match, ExactMatch: Boolean; SearchText, FileName: string;
begin
  SetLength(FFilteredFiles, Length(FArchiveData.Files)); Count := 0;
  ExactMatch := False; SearchText := Trim(FFilterText);
  if (Length(SearchText) > 1) and (SearchText[1] = '=') then begin ExactMatch := True; SearchText := Copy(SearchText, 2, Length(SearchText)); end;
  TargetVer := 0;
  if (FTreeMode = tmSingleVersion) and (FCurrentVersion > 0) then
    if (FCurrentVersion - 1 >= 0) and (FCurrentVersion - 1 < Length(FArchiveData.GlobalVersions)) then
      TargetVer := FArchiveData.GlobalVersions[FCurrentVersion - 1].Number;
  for I := 0 to High(FArchiveData.Files) do
  begin
    FileName := FArchiveData.Files[I].FileName;
    if IsPathHidden(FileName) then Continue;
    if SearchText <> '' then
    begin
      if ExactMatch then Match := (CompareText(ExtractFileName(FileName), SearchText) = 0)
      else Match := (Pos(LowerCase(SearchText), LowerCase(FileName)) > 0);
      if not Match then Continue;
    end;
    if TargetVer > 0 then
    begin
      Match := False; BestIdx := -1;
      for J := 0 to High(FArchiveData.Files[I].Versions) do
        if FArchiveData.Files[I].Versions[J].Version <= TargetVer then BestIdx := J else Break;
      if BestIdx >= 0 then if not FArchiveData.Files[I].Versions[BestIdx].IsDeleted then Match := True;
      if not Match then Continue;
    end;
    FFilteredFiles[Count] := I; Inc(Count);
  end;
  SetLength(FFilteredFiles, Count);
  if FFilterText <> '' then lblFilterInfo.Caption := Format(S('lbl_showing_fmt', 'Showing %d / %d files'), [Count, Length(FArchiveData.Files)])
  else lblFilterInfo.Caption := '';
  lblFileCount.Caption := Format('%d %s', [Count, S('lbl_files', 'files')]);
end;

{ === VirtualStringTree === }

function TfrmMain.GetFileDisplayIndex(TreeIndex: Integer): Integer;
begin
  if (TreeIndex >= 0) and (TreeIndex < Length(FFilteredFiles)) then Result := FFilteredFiles[TreeIndex] else Result := -1;
end;

procedure TfrmMain.RebuildTree;
begin
  // Resetta lo stato di ordinamento quando viene ricaricato l'albero
  FVstSortColumn := -1;
  FVstSortAscending := True;
  if VST.Header.SortColumn >= 0 then
  begin
    VST.Header.SortColumn := -1;
    VST.Header.SortDirection := sdAscending;
  end;
  VST.Clear;
  VST.BeginUpdate;
  try
    VST.RootNodeCount := Length(FFilteredFiles);
  finally
    VST.EndUpdate;
  end;
end;

procedure TfrmMain.VSTInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
var Data, ParentData: PNodeData; FileIdx: Integer;
begin
  Data := VST.GetNodeData(Node);
  if ParentNode = nil then
  begin
    FileIdx := GetFileDisplayIndex(Node^.Index);
    Data^.FileIndex := FileIdx; Data^.VersionIndex := -1; Data^.IsParent := True; Data^.IsHidden := False;
    if (FTreeMode = tmAllVersions) and (FileIdx >= 0) and (Length(FArchiveData.Files[FileIdx].Versions) > 0) then
      Include(InitialStates, ivsHasChildren);
  end else begin
    ParentData := VST.GetNodeData(ParentNode);
    Data^.FileIndex := ParentData^.FileIndex; Data^.VersionIndex := Node^.Index; Data^.IsParent := False; Data^.IsHidden := False;
  end;
end;

procedure TfrmMain.VSTInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode; var ChildCount: Cardinal);
var Data: PNodeData;
begin
  Data := VST.GetNodeData(Node);
  if Data^.IsParent and (Data^.FileIndex >= 0) then ChildCount := Length(FArchiveData.Files[Data^.FileIndex].Versions) else ChildCount := 0;
end;

function TfrmMain.SplitDateTime(const FullDate: string; WantTime: Boolean): string;
var SpacePos: Integer;
begin
  SpacePos := Pos(' ', FullDate);
  if SpacePos > 0 then begin if WantTime then Result := Copy(FullDate, SpacePos + 1, Length(FullDate)) else Result := Copy(FullDate, 1, SpacePos - 1); end
  else begin if WantTime then Result := '' else Result := FullDate; end;
end;

function TfrmMain.FormatChildLine(const FV: TFileVersion): string;
var DatePart, TimePart, SizePart: string;
begin
  if FV.IsDeleted then begin Result := Format('  -> %8.8d  (DELETED)', [FV.Version]); Exit; end;
  DatePart := SplitDateTime(FV.DateStr, False); TimePart := SplitDateTime(FV.DateStr, True); SizePart := FormatFileSize(FV.Size);
  Result := Format('  -> %8.8d | %s | %s   %s', [FV.Version, DatePart, TimePart, SizePart]);
end;

procedure TfrmMain.VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
var Data: PNodeData; FE: TArchiveFileEntry; FV: TFileVersion; BestIdx, TargetVer: Integer;
  function GetBest: Integer; var k: Integer;
  begin Result := -1; TargetVer := FArchiveData.GlobalVersions[FCurrentVersion - 1].Number;
    for k := 0 to High(FE.Versions) do if FE.Versions[k].Version <= TargetVer then Result := k; end;
begin
  Data := VST.GetNodeData(Node); if Data^.FileIndex < 0 then Exit;
  FE := FArchiveData.Files[Data^.FileIndex];
  if Data^.IsParent then begin
    BestIdx := -1;
    if (FTreeMode = tmSingleVersion) and (FCurrentVersion > 0) then BestIdx := GetBest
    else if Length(FE.Versions) > 0 then BestIdx := High(FE.Versions);
    case Column of
      0: CellText := FE.FileName;
      1: if BestIdx >= 0 then CellText := IntToStr(FE.Versions[BestIdx].Version) else CellText := '?';
      2: if BestIdx >= 0 then CellText := SplitDateTime(FE.Versions[BestIdx].DateStr, False);
      3: if BestIdx >= 0 then CellText := SplitDateTime(FE.Versions[BestIdx].DateStr, True);
      4: if BestIdx >= 0 then CellText := FormatFileSize(FE.Versions[BestIdx].Size) else CellText := '-';
    end;
    if (FTreeMode = tmAllVersions) and (Column = 1) then CellText := Format('(%d vers)', [Length(FE.Versions)]);
  end else begin
    if (Data^.VersionIndex >= 0) and (Data^.VersionIndex <= High(FE.Versions)) then begin
      FV := FE.Versions[Data^.VersionIndex];
      case Column of 0: CellText := FormatChildLine(FV); 1: CellText := ''; 2: CellText := ''; 3: CellText := ''; 4: CellText := ''; end;
    end;
  end;
end;

procedure TfrmMain.VSTGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);
begin ImageIndex := -1; end;

procedure TfrmMain.VSTPaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
var Data: PNodeData; FE: TArchiveFileEntry; FileName: string; IsFolder: Boolean; LastChar: Char;
begin
  Data := Sender.GetNodeData(Node); if Data = nil then Exit; if Data^.FileIndex < 0 then Exit;
  FE := FArchiveData.Files[Data^.FileIndex]; FileName := FE.FileName; IsFolder := False;
  if Length(FileName) > 0 then begin LastChar := FileName[Length(FileName)]; if (LastChar = '/') or (LastChar = '\') then IsFolder := True; end;
  if not (vsSelected in Node^.States) then begin
    if Data^.IsParent then begin
      if IsFolder then begin TargetCanvas.Font.Color := $00008000; TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold]; end
      else TargetCanvas.Font.Color := clWindowText;
    end else begin
      if (Data^.VersionIndex >= 0) and (FArchiveData.Files[Data^.FileIndex].Versions[Data^.VersionIndex].IsDeleted) then
      begin TargetCanvas.Font.Color := clRed; TargetCanvas.Font.Style := [fsStrikeOut]; end;
    end;
  end;
end;

procedure TfrmMain.VSTBeforeCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  CellPaintMode: TVTCellPaintMode; var CellRect: TRect; var ContentRect: TRect);
var Data: PNodeData;
begin
  if (vsSelected in Node^.States) then Exit; Data := Sender.GetNodeData(Node); if Data = nil then Exit;
  if Data^.IsParent then begin TargetCanvas.Brush.Color := $00FAFAFA; TargetCanvas.FillRect(CellRect); end;
end;

procedure TfrmMain.AddLog(const AMsg: string);
begin MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + AMsg); end;

procedure TfrmMain.HandleDownloadProgress(Downloaded, Total: Int64);
var
  Percent: Integer;
begin
  // Aggiorna pgrProgressLog e pgrProgresso durante i download da internet
  if (Downloaded = 0) and (Total = 0) then
  begin
    // Reset: download non avviato o fallito
    pgrProgressLog.Position := 0;
    pgrProgressLog.Visible  := False;
    pgrProgresso.Position   := 0;
  end
  else if Total > 0 then
  begin
    Percent := Round(Downloaded * 100 / Total);
    pgrProgressLog.Visible  := True;
    pgrProgressLog.Max      := 100;
    pgrProgressLog.Position := Percent;
    pgrProgresso.Max        := 100;
    pgrProgresso.Position   := Percent;
  end
  else
  begin
    // Total ignoto: usa marquee-style (scorre da 0 a Max senza sapere il totale)
    pgrProgressLog.Visible  := True;
    pgrProgressLog.Max      := 1000;
    pgrProgressLog.Position := (pgrProgressLog.Position + 50) mod 1000;
    pgrProgresso.Max        := 1000;
    pgrProgresso.Position   := pgrProgressLog.Position;
  end;
  Application.ProcessMessages;
end;

{ === Internet Update === }

procedure TfrmMain.btnInternetUpdateClick(Sender: TObject);
var
  Checker: TUpdateChecker;
  UpdateInfo: TUpdateInfo;
  CurrentBuild: Integer;
  FileVerInfo: TFileVersionInfo;
  NewCatpaqPath, NewEXEPath, Msg, VerStr: string;
begin
  // --- Leggi versione corrente ---
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.FileName := ParamStr(0);
    FileVerInfo.ReadFileInfo;
    VerStr := FileVerInfo.VersionStrings.Values['FileVersion'];
    if VerStr <> '' then
      CurrentBuild := StrToIntDef(Copy(VerStr, LastDelimiter('.', VerStr) + 1, Length(VerStr)), 0)
    else
      CurrentBuild := 0;
  finally
    FileVerInfo.Free;
  end;

  PageControl1.ActivePage := TabLog;
  AddLog('--- Internet Update: START ---');
  AddLog('Current build: ' + IntToStr(CurrentBuild));
  Application.ProcessMessages;

  Checker := TUpdateChecker.Create;
  Checker.OnLog      := @AddLog;
  Checker.OnProgress := @HandleDownloadProgress;
  try
    // --- CheckForUpdate ---
    if not Checker.CheckForUpdate(CurrentBuild, UpdateInfo) then
    begin
      if not UpdateInfo.Valid then
      begin
        MessageDlg(S('dlg_update_error', 'Update Error'),
          S('msg_update_check_fail', 'Unable to check for updates. Please check your internet connection.') + sLineBreak + sLineBreak +
          'Details in the Log tab.',
          mtError, [mbOK], 0);
      end
      else
      begin
        MessageDlg(S('dlg_up_to_date', 'Up to Date'),
          Format(S('msg_up_to_date_fmt', 'You are already running the latest version (build %d)'),
            [CurrentBuild]),
          mtInformation, [mbOK], 0);
        AddLog('No updates available.');
      end;
      Exit;
    end;

    // --- Aggiornamento disponibile ---
    AddLog('Update available: server build=' + IntToStr(UpdateInfo.CatpaqInfo.BuildNumber));
    {$IFDEF WINDOWS}
    Msg := Format(S('msg_update_available_fmt', 'Your build %d is older than build %d.') + LineEnding +
      'Catpaq: %s (%s)' + LineEnding + 'zpaqfranz.exe: %s (%s)' + LineEnding +
      S('msg_update_now', 'Do you want to update now?'),
      [CurrentBuild, UpdateInfo.CatpaqInfo.BuildNumber,
       FormatFileSize(UpdateInfo.CatpaqInfo.FileSize), UpdateInfo.CatpaqInfo.DateTime,
       FormatFileSize(UpdateInfo.EXEInfo.FileSize), UpdateInfo.EXEInfo.DateTime]);
    {$ELSE}
    Msg := Format(S('msg_update_available_fmt', 'Your build %d is older than build %d.') + LineEnding +
      'Catpaq: %s (%s)' + LineEnding + 'zpaqfranz: %s (%s)' + LineEnding + LineEnding +
      S('msg_update_now', 'Do you want to update now?'),
      [CurrentBuild, UpdateInfo.CatpaqInfo.BuildNumber,
       FormatFileSize(UpdateInfo.CatpaqInfo.FileSize), UpdateInfo.CatpaqInfo.DateTime,
       FormatFileSize(UpdateInfo.EXEInfo.FileSize), UpdateInfo.EXEInfo.DateTime]);
    {$ENDIF}

    if MessageDlg(S('dlg_update_available', 'Update Available'), Msg,
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      AddLog('Update cancelled by user.');
      Exit;
    end;

    // --- Download ---
    Application.ProcessMessages;
    if not Checker.DownloadUpdate(UpdateInfo, NewCatpaqPath, NewEXEPath) then
    begin
      MessageDlg(S('dlg_download_error', 'Download Error'),
        S('msg_download_fail', 'Failed to download or verify update files.') + sLineBreak + sLineBreak +
        'Details in the Log tab.',
        mtError, [mbOK], 0);
      Exit;
    end;

    // --- Apply ---
    Application.ProcessMessages;
    if not Checker.ApplyUpdate(NewCatpaqPath, NewEXEPath) then
    begin
      MessageDlg(S('dlg_update_error', 'Update Error'),
        S('msg_apply_fail', 'Failed to apply update. Please try updating manually.'),
        mtError, [mbOK], 0);
      Exit;
    end;

    AddLog('Update applied. Restarting...');
    Application.Terminate;

  finally
    Checker.Free;
    AddLog('--- Internet Update: END ---');
    pgrProgressLog.Position := 0;
    pgrProgressLog.Visible  := False;
  end;
end;

procedure TfrmMain.chkAutoUpdateClick(Sender: TObject);
begin
  FAutoUpdateCheck := chkAutoUpdate.Checked;
  SaveSettingsToIni;
end;

{ Controlla la presenza di aggiornamenti all'avvio.
  - Windows: se disponibile chiede conferma e scarica tutto (catpaq + zpaqfranz).
  - Non-Windows: avvisa solo con un messaggio, non scarica nulla. }
procedure TfrmMain.DoStartupUpdateCheck;
var
  Checker: TUpdateChecker;
  UpdateInfo: TUpdateInfo;
  CurrentBuild: Integer;
  FileVerInfo: TFileVersionInfo;
  VerStr, Msg: string;
  NewCatpaqPath, NewEXEPath:string;
begin
  { Legge la versione corrente dall'eseguibile }
  CurrentBuild := 0;
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.FileName := ParamStr(0);
    FileVerInfo.ReadFileInfo;
    VerStr := FileVerInfo.VersionStrings.Values['FileVersion'];
    if VerStr <> '' then
      CurrentBuild := StrToIntDef(
        Copy(VerStr, LastDelimiter('.', VerStr) + 1, Length(VerStr)), 0);
  finally
    FileVerInfo.Free;
  end;

  AddLog('--- Startup update check: current build=' + IntToStr(CurrentBuild) + ' ---');
  Application.ProcessMessages;

  Checker := TUpdateChecker.Create;
  Checker.OnLog      := @AddLog;
  Checker.OnProgress := nil; { silenzioso all'avvio, niente barra }
  try
    if not Checker.CheckForUpdate(CurrentBuild, UpdateInfo) then
    begin
      if not UpdateInfo.Valid then
        AddLog('Startup update check: unable to reach server (skipped)')
      else
        AddLog('Startup update check: already up to date');
      Exit;
    end;

    { Aggiornamento disponibile }
    AddLog('Startup update check: new build ' +
      IntToStr(UpdateInfo.CatpaqInfo.BuildNumber) + ' available.');

    {$IFDEF WINDOWS}
    Msg := Format(
      S('msg_startup_update_win',
        'Catpaq build %d is available (you have build %d).' + LineEnding +
        'Files to download:' + LineEnding +
        '  catpaq.exe          %s  (%s)' + LineEnding +
        '  zpaqfranz.exe       %s  (%s)' + LineEnding +
        'Update now?'),
      [UpdateInfo.CatpaqInfo.BuildNumber, CurrentBuild,
       FormatFileSize(UpdateInfo.CatpaqInfo.FileSize), UpdateInfo.CatpaqInfo.DateTime,
       FormatFileSize(UpdateInfo.EXEInfo.FileSize),    UpdateInfo.EXEInfo.DateTime
       ]);

    if MessageDlg(
         S('dlg_startup_update', 'Update Available'), Msg,
         mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      AddLog('Startup update check: deferred by user.');
      Exit;
    end;

    { Procede con download + apply }
    PageControl1.ActivePage := TabLog;
    Application.ProcessMessages;

    if not Checker.DownloadUpdate(UpdateInfo, NewCatpaqPath, NewEXEPath) then
    begin
      MessageDlg(
        S('dlg_download_error', 'Download Error'),
        S('msg_download_fail', 'Failed to download or verify update files.') +
        sLineBreak + sLineBreak + 'Details in the Log tab.',
        mtError, [mbOK], 0);
      Exit;
    end;

    Application.ProcessMessages;
    if not Checker.ApplyUpdate(NewCatpaqPath, NewEXEPath) then
    begin
      MessageDlg(
        S('dlg_update_error', 'Update Error'),
        S('msg_apply_fail', 'Failed to apply update. Please try updating manually.'),
        mtError, [mbOK], 0);
      Exit;
    end;

    AddLog('Startup update: applied. Restarting...');
    Application.Terminate;

    {$ELSE}
    { Non-Windows: solo avviso, niente download }
    Msg := Format(
      S('msg_startup_update_nowin',
        'Catpaq build %d is available on the developer''s site.' + LineEnding +
        'You are currently running build %d.' + LineEnding + LineEnding +
        'Please download the update manually from:' + LineEnding +
        'http://www.francocorbelli.it/catpaq/'),
      [UpdateInfo.CatpaqInfo.BuildNumber, CurrentBuild]);
    MessageDlg(
      S('dlg_startup_update', 'Update Available'), Msg,
      mtInformation, [mbOK], 0);
    AddLog('Startup update check: user notified (non-Windows platform, no auto-download).');
    {$ENDIF}

  finally
    Checker.Free;
  end;
end;

{ === i18n helper === }
function TfrmMain.S(const AKey, ADefault: string): string;
var Idx: Integer;
begin
  Idx := FLang.IndexOfName(AKey);
  if Idx >= 0 then
    Result := FLang.ValueFromIndex[Idx]
  else
    Result := ADefault;
end;

procedure TfrmMain.LoadLanguage(const ALangName: string);
var
  LangFile: string;
  Ini: TIniFile;
  Keys: TStringList;
  I: Integer;
begin
  FLang.Clear;
  FLangName := LowerCase(ALangName);
  if (FLangName = '') or (FLangName = 'english') then
  begin
    FLangName := 'english';
    ApplyLanguage;
    Exit;
  end;
  LangFile := ExtractFilePath(Application.ExeName) + 'languages_' + FLangName + '.ini';
  if not FileExists(LangFile) then
  begin
    FLangName := 'english';
    ApplyLanguage;
    Exit;
  end;
  Ini := TIniFile.Create(LangFile);
  Keys := TStringList.Create;
  try
    Ini.ReadSection('Strings', Keys);
    for I := 0 to Keys.Count - 1 do
      FLang.Add(Keys[I] + '=' + Ini.ReadString('Strings', Keys[I], ''));
  finally
    Keys.Free;
    Ini.Free;
  end;
  ApplyLanguage;
end;

procedure TfrmMain.ScanLanguages;
var
  SR: TSearchRec;
  LangDir, BaseName, DisplayName: string;
  I: Integer;
begin
  cbLanguage.Items.Clear;
  cbLanguage.Items.Add('English');
  LangDir := ExtractFilePath(Application.ExeName);
  if FindFirst(LangDir + 'languages_*.ini', faAnyFile, SR) = 0 then
  begin
    repeat
      BaseName := ChangeFileExt(SR.Name, '');
      DisplayName := Copy(BaseName, Length('languages_') + 1, Length(BaseName));
      if DisplayName <> '' then
      begin
        DisplayName[1] := UpCase(DisplayName[1]);
        cbLanguage.Items.Add(DisplayName);
      end;
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
  I := cbLanguage.Items.IndexOf(FLangName);
  if I < 0 then
  begin
    if Length(FLangName) > 0 then
    begin
      DisplayName := FLangName;
      DisplayName[1] := UpCase(DisplayName[1]);
      I := cbLanguage.Items.IndexOf(DisplayName);
    end;
  end;
  if I < 0 then I := 0;
  cbLanguage.ItemIndex := I;
end;

procedure TfrmMain.ApplyLanguage;
begin
  SetGlobalLang(FLang);

  // --- Log popup (runtime, riapplicato se lingua cambia) --------------------
  if Assigned(mnuSaveLog) then mnuSaveLog.Caption := S('log_save', 'Save system log to file...');
  if Assigned(mnuLogBack)  then mnuLogBack.Caption  := S('log_back',  '<= Back to Browse');
  if Assigned(mnuLogClear) then mnuLogClear.Caption := S('log_clear', 'Clear system log');

  // --- Archive log popup (runtime) -------------------------------------------
  if Assigned(mnuSaveArchive) then mnuSaveArchive.Caption := S('archive_log_save', 'Save archive log to file...');
  if Assigned(mnuArchiveLogBack) then mnuArchiveLogBack.Caption := S('log_back', '<= Back to Browse');
  if Assigned(mnuClearArchive) then mnuClearArchive.Caption := S('archive_log_clear', 'Clear archive log');

  // --- Tab captions ---------------------------------------------------------
  TabArchive.Caption            := S('tab_archive',          'Versions');
  TabLog.Caption                := S('tab_log',              'Log');
  TabSettings.Caption           := S('tab_settings',         'Settings');
  TabAdd.Caption                := S('tab_add',              'Browse');

  // --- Versions tab ---------------------------------------------------------
  lblFilter.Caption             := S('lbl_filter',           'Filter:');
  edtFilter.TextHint            := S('filter_hint',          'Type and press Enter (=exact match)');
  btnOpen.Caption               := S('btn_open',             'Select ZPAQ...');
  lblArchiveInfo.Caption        := S('lbl_no_archive',       'No archive loaded');

  // --- Settings tab ---------------------------------------------------------
  gbFileAssoc.Caption           := S('gb_file_assoc',        'File Associations');
  btnAssociate.Caption          := S('btn_associate',        'Associate .zpaq and .zpaq.franzen');
  btnDisassociate.Caption       := S('btn_disassociate',     'Remove file associations');
  gbFont.Caption                := S('gb_font',              'Tree Font');
  btnChangeTreeFont.Caption     := S('btn_change_font',      'Change tree font...');
  gbLinks.Caption               := S('gb_links',             'Links and Updates');
  btnBrowseBuild.Caption        := S('btn_browse_build',     'Browse Catpaq builds');
  btnInternetUpdate.Caption     := S('btn_internet_update',  'Internet Update');
  if Assigned(chkAutoUpdate) then
    chkAutoUpdate.Caption       := S('chk_auto_update', 'Check for updates at startup');
  gbZoom.Caption                := S('gb_zoom',              'Interface Zoom');
  gbLanguage.Caption            := S('gb_language',          'Language');

  // --- Versions tree popup --------------------------------------------------
  mnuExtractFileGUI.Caption     := S('mnu_extract_file_gui',    'Extract file to folder (GUI)...');
  mnuExtractFileText.Caption    := S('mnu_extract_file_text',   'Extract file to folder (text)...');
  mnuExtractFolderGUI.Caption   := S('mnu_extract_folder_gui',  'Extract folder to... (GUI)');
  mnuExtractFolderText.Caption  := S('mnu_extract_folder_text', 'Extract folder to... (text)');
  mnuCopyFileName.Caption       := S('mnu_copy_filename',       'Copy filename');
  mnuCopyFullPath.Caption       := S('mnu_copy_fullpath',       'Copy full path');
  mnuExpandAll.Caption          := S('mnu_expand_all',          'Expand all');
  mnuCollapseAll.Caption        := S('mnu_collapse_all',        'Collapse all');
  mnuHideFolder.Caption         := S('mnu_hide_folder',         'Hide selected folder');
  mnuHideTree.Caption           := S('mnu_hide_tree',           'Hide selected tree');
  mnuShowAll.Caption            := S('mnu_show_all',            'Show everything');

  // --- Browse tab toolbar ---------------------------------------------------
  btnExit2.Caption              := S('btn_exit',             '&Exit');
  btnAddAdd.Caption             := S('btn_add_add',          'Add');
  btnAddExtract.Caption         := S('btn_add_extract',      'Extract');
  btnAddTest.Caption            := S('btn_add_test',         'Test');
  lblAddFilter.Caption          := S('lbl_add_select',       'Select:');
  edtAddFilter.TextHint         := S('filter_add_hint',      'Type filter and press Enter (=exact match)');
  btnAddRefresh.Caption         := S('btn_add_refresh',      'Refresh');

  // --- Browse popup menu ----------------------------------------------------
  mnuAddFilesToZpaq.Caption     := S('mnu_add_files_to_zpaq',      'Add files to ZPAQ...');
  mnuAddAllToZpaq.Caption       := S('mnu_add_all_to_zpaq',        'Add all to ZPAQ');
  mnuAddOpen.Caption            := S('mnu_add_open',               'Open');
  mnuAddOpenInExplorer.Caption  := S('mnu_add_open_in_explorer',   'Open in Explorer');
  mnuAddRename.Caption          := S('mnu_add_rename',             'Rename');
  mnuAddDelete.Caption          := S('mnu_add_delete',             'Delete');
  mnuAddCreateFolder.Caption    := S('mnu_add_create_folder',      'Create folder');
  mnuAddProperties.Caption      := S('mnu_add_properties',         'Properties');
  mnuAddExtractToFolder.Caption := S('mnu_add_extract_to_folder',  'Extract ZPAQ archive to...');
  mnuAddBrowseVersions.Caption  := S('mnu_add_browse_versions',    'Browse all versions...');
  mnuAddHash.Caption            := S('mnu_add_hash',               'Hash');
  mnuAddTestZpaq.Caption        := S('mnu_add_test',               'Test');
  mnuAddTestAllZpaq.Caption     := S('mnu_add_test_all',           'Test all');

  // --- Archive browse popup + Test popup ------------------------------------
  itmLastversion.Caption        := S('itm_last_version',    'Last version');
  itmAll.Caption                := S('itm_all_versions',    'All versions');
  mnuArchiveBack.Caption        := S('mnu_archive_back',        '← Back to filesystem');
  mnuArchiveExtract1.Caption    := S('mnu_archive_extract',     'Extract...');
  mnuArchiveExtractAll.Caption  := S('mnu_archive_extract_all', 'Extract all...');
  mnuArchiveExtract2.Caption    := S('mnu_archive_test',        'Test');

  if VST.Header.Columns.Count >= 5 then
  begin
    VST.Header.Columns[0].Text := S('col_filename', 'File Name');
    VST.Header.Columns[1].Text := S('col_version', 'Version');
    VST.Header.Columns[2].Text := S('col_date', 'Date');
    VST.Header.Columns[3].Text := S('col_time', 'Time');
    VST.Header.Columns[4].Text := S('col_size', 'Size');
  end;

  if lvAddFiles.Header.Columns.Count >= 6 then
  begin
    lvAddFiles.Header.Columns[0].Text := S('col_name', 'Name');
    lvAddFiles.Header.Columns[1].Text := S('col_size', 'Size');
    lvAddFiles.Header.Columns[2].Text := S('col_modified', 'Modified');
    lvAddFiles.Header.Columns[3].Text := S('col_created', 'Created');
    lvAddFiles.Header.Columns[4].Text := S('col_attributes', 'Attributes');
    lvAddFiles.Header.Columns[5].Text := S('col_extension', 'Ext');
  end;

  UpdateTimeMachineCaption;
  UpdateFontLabel;
  UpdateZoomLabel;
end;

procedure TfrmMain.cbLanguageChange(Sender: TObject);
var LN: string;
begin
  if cbLanguage.ItemIndex < 0 then Exit;
  LN := LowerCase(cbLanguage.Items[cbLanguage.ItemIndex]);
  LoadLanguage(LN);
  SaveSettingsToIni;
end;

{ ============================================================================ }
{ === TAB ADD - FILE EXPLORER IMPLEMENTATION ================================ }
{ ============================================================================ }

function TfrmMain.IsCaseSensitiveFS: Boolean;
begin
  {$IFDEF WINDOWS}
  Result := False;
  {$ELSE}
  Result := True;
  {$ENDIF}
end;

procedure TfrmMain.InitAddTab;
begin
  btnAddExtract.Visible := False;
  btnAddTest.Visible := False;

  { Wire VST events for lvAddFiles (file browser) }
  lvAddFiles.NodeDataSize := 0; { No extra per-node data - we use Node^.Index into FAddFilesList }
  lvAddFiles.OnGetText := @lvAddFilesGetText;
  lvAddFiles.OnInitNode := @lvAddFilesInitNode;
  lvAddFiles.OnPaintText := @lvAddFilesPaintText;
  lvAddFiles.OnHeaderClick := @lvAddFilesHeaderClick;
  lvAddFiles.OnFocusChanged := @lvAddFilesFocusChanged;

  {$IFDEF WINDOWS}
  FCurrentAddPath := 'C:\';
  {$ELSE}
  FCurrentAddPath := GetUserDir;
  {$ENDIF}
  PopulateAddDrives;
  NavigateToPath(FCurrentAddPath);
end;
                        procedure TfrmMain.PopulateAddDrives;
{$IFDEF WINDOWS}
var Drives: DWORD; I: Integer; DriveLetter: Char;
{$ENDIF}
begin
  cmbAddDrives.OnChange := nil; // <--- DISABILITA L'EVENTO
  try
    cmbAddDrives.Items.Clear;
    {$IFDEF WINDOWS}
    Drives := GetLogicalDrives;
    for I := 0 to 25 do
    begin
      if (Drives and (1 shl I)) <> 0 then
      begin
        DriveLetter := Chr(Ord('A') + I);
        cmbAddDrives.Items.Add(DriveLetter + ':\');
      end;
    end;
    if cmbAddDrives.Items.Count > 0 then cmbAddDrives.ItemIndex := 0;
    {$ELSE}
    cmbAddDrives.Items.Add('/');
    cmbAddDrives.Items.Add(GetUserDir);
    if DirectoryExists('/media') then cmbAddDrives.Items.Add('/media');
    if DirectoryExists('/mnt') then cmbAddDrives.Items.Add('/mnt');
    cmbAddDrives.ItemIndex := 1;
    {$ENDIF}
  finally
    cmbAddDrives.OnChange := @cmbAddDrivesChange; // <--- RIABILITA L'EVENTO
  end;
end;

procedure TfrmMain.NavigateToPath(const APath: string);
var NormalizedPath: string;
begin
  NormalizedPath := IncludeTrailingPathDelimiter(APath);
  if not DirectoryExists(NormalizedPath) then begin AddLog('Directory not found: ' + NormalizedPath); Exit; end;

  { Se siamo in archive browse mode, uscire automaticamente }
  if FArchiveBrowseMode then
  begin
    FArchiveBrowseMode := False;
    FArchiveBrowsePath := '';
    lvAddFiles.Color := clWindow;
    lvAddFiles.PopupMenu := PopupMenuAdd;
  end;

  FCurrentAddPath := NormalizedPath;
  edtAddPath.Text := FCurrentAddPath;
  lblAddPath.Caption := 'Path: ' + FCurrentAddPath;

  {$IFDEF WINDOWS}
  if Length(FCurrentAddPath) >= 3 then
  begin
    cmbAddDrives.OnChange := nil; // <--- DISABILITA L'EVENTO
    try
      cmbAddDrives.ItemIndex := cmbAddDrives.Items.IndexOf(UpperCase(Copy(FCurrentAddPath, 1, 3)));
    finally
      cmbAddDrives.OnChange := @cmbAddDrivesChange; // <--- RIABILITA L'EVENTO
    end;
  end;
  {$ENDIF}

  RefreshAddFilesList;
end;

procedure TfrmMain.RefreshAddFilesList;
var SR: TSearchRec; Count: Integer; FileItem: TFileExplorerItem;
begin
  lvAddFiles.Clear;
  SetLength(FAddFilesList, 0);
  Count := 0;

  { Riga ".." per salire di directory }
  {$IFDEF WINDOWS} if Length(FCurrentAddPath) > 3 then {$ELSE} if FCurrentAddPath <> '/' then {$ENDIF}
  begin
    SetLength(FAddFilesList, Count + 1);
    FAddFilesList[Count].Name := '..';
    FAddFilesList[Count].FullPath := ExtractFilePath(ExcludeTrailingPathDelimiter(FCurrentAddPath));
    FAddFilesList[Count].IsDirectory := True;
    FAddFilesList[Count].Size := -1;
    FAddFilesList[Count].Modified := 0;
    FAddFilesList[Count].Created := 0;
    FAddFilesList[Count].Attributes := 0;
    Inc(Count);
  end;

  { Directories first }
  if FindFirst(FCurrentAddPath + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        SetLength(FAddFilesList, Count + 1);
        FileItem.Name := SR.Name + '/';
        FileItem.FullPath := FCurrentAddPath + SR.Name;
        FileItem.IsDirectory := True;
        FileItem.Size := -1;
        FileItem.Modified := FileDateToDateTime(SR.Time);
        FileItem.Created := FileItem.Modified;
        FileItem.Attributes := SR.Attr;
        FAddFilesList[Count] := FileItem;
        Inc(Count);
      end;
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;

  { Then files }
  if FindFirst(FCurrentAddPath + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) = 0 then
      begin
        SetLength(FAddFilesList, Count + 1);
        FileItem.Name := SR.Name;
        FileItem.FullPath := FCurrentAddPath + SR.Name;
        FileItem.IsDirectory := False;
        FileItem.Size := SR.Size;
        FileItem.Modified := FileDateToDateTime(SR.Time);
        FileItem.Created := FileItem.Modified;
        FileItem.Attributes := SR.Attr;
        FAddFilesList[Count] := FileItem;
        Inc(Count);
      end;
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;

  lvAddFiles.Color := clWindow;
  lvAddFiles.BeginUpdate;
  try
    lvAddFiles.RootNodeCount := Count;
  finally
    lvAddFiles.EndUpdate;
  end;

  FLvSortColumn := -1;
  FLvSortAscending := True;
  AddLog(Format('Loaded %d items from %s', [Count, FCurrentAddPath]));
  UpdateZpaqButtons;
end;

{ === Archive Browse Mode === }

// Popola lvAddFiles con file dell'archivio (una sola versione).
// Ora usa FAddFilesList come data model e VST virtualizzato: istantaneo anche con milioni di file.
procedure TfrmMain.ShowArchiveBrowse(const AArchivePath: string; const AData: TArchiveData);
var
  I, Count: Integer;
  FE: TArchiveFileEntry;
  FV: TFileVersion;
  DisplayName: string;
begin
  FArchiveBrowseMode := True;
  FArchiveBrowsePath := AArchivePath;

  FileListDbgWrite('ShowArchiveBrowse: START files=' + IntToStr(Length(AData.Files)));

  // Aggiorna la label del path per indicare che siamo dentro un archivio
  edtAddPath.Text := '[ARCHIVE] ' + AArchivePath;
  lblAddPath.Caption := 'Archive: ' + ExtractFileName(AArchivePath);

  // Cambia il popup menu
  lvAddFiles.PopupMenu := PopupMenuArchiveBrowse;

  { Popola FAddFilesList — unico data model }
  SetLength(FAddFilesList, Length(AData.Files) + 1); { +1 per ".." }
  Count := 0;

  { Prima riga: ".." per tornare al filesystem }
  FAddFilesList[Count].Name := '..';
  FAddFilesList[Count].FullPath := '';
  FAddFilesList[Count].IsDirectory := True;
  FAddFilesList[Count].Size := -1;
  FAddFilesList[Count].Modified := 0;
  FAddFilesList[Count].Created := 0;
  FAddFilesList[Count].Attributes := 0;
  Inc(Count);

  { File dell'archivio (prende l'ultima/unica versione di ogni file) }
  for I := 0 to High(AData.Files) do
  begin
    FE := AData.Files[I];
    if Length(FE.Versions) = 0 then Continue;
    FV := FE.Versions[High(FE.Versions)];
    if FV.IsDeleted then Continue;

    DisplayName := ExtractFileName(ExcludeTrailingPathDelimiter(FE.FileName));
    if DisplayName = '' then DisplayName := FE.FileName;

    FAddFilesList[Count].Name := DisplayName;
    FAddFilesList[Count].FullPath := FE.FileName;
    FAddFilesList[Count].IsDirectory := False;
    FAddFilesList[Count].Size := FV.Size;
    FAddFilesList[Count].Modified := 0;
    if (FV.DateStr <> 'DELETED') and (FV.DateStr <> '') then
    begin
      { zpaqfranz date format: "DD/MM/YYYY HH:NN:SS"
        Parsing manuale per evitare dipendenza dal locale di Windows }
      try
        if Length(FV.DateStr) >= 19 then
          FAddFilesList[Count].Modified := EncodeDate(
            StrToIntDef(Copy(FV.DateStr, 7, 4), 2000),
            StrToIntDef(Copy(FV.DateStr, 4, 2), 1),
            StrToIntDef(Copy(FV.DateStr, 1, 2), 1)) +
          EncodeTime(
            StrToIntDef(Copy(FV.DateStr, 12, 2), 0),
            StrToIntDef(Copy(FV.DateStr, 15, 2), 0),
            StrToIntDef(Copy(FV.DateStr, 18, 2), 0), 0);
      except
        FAddFilesList[Count].Modified := 0;
      end;
    end;
    FAddFilesList[Count].Created := 0;
    FAddFilesList[Count].Attributes := 0;
    Inc(Count);
  end;
  SetLength(FAddFilesList, Count);

  { Imposta il VST — istantaneo anche con milioni di righe }
  lvAddFiles.Color := $00F0F0F0;
  lvAddFiles.BeginUpdate;
  try
    lvAddFiles.Clear;
    lvAddFiles.RootNodeCount := Count;
  finally
    lvAddFiles.EndUpdate;
  end;

  FileListDbgWrite('ShowArchiveBrowse: END items=' + IntToStr(Count));

  // Rimani sulla tab Add (non cambiare tab)
  PageControl1.ActivePage := TabAdd;

  AddArchiveLog(Format('Archive browse mode: %d files in %s',
    [Count - 1, ExtractFileName(AArchivePath)]));

  UpdateZpaqButtons;
end;

// Torna alla modalità filesystem normale
procedure TfrmMain.ExitArchiveBrowseMode;
begin
  FArchiveBrowseMode := False;
  FArchiveBrowsePath := '';

  // Ripristina sfondo bianco (modalità filesystem)
  lvAddFiles.Color := clWindow;

  // Ripristina il popup menu originale
  lvAddFiles.PopupMenu := PopupMenuAdd;

  // Torna al filesystem
  NavigateToPath(FCurrentAddPath);
  UpdateZpaqButtons;
end;

{ === PopupMenuArchiveBrowse handlers === }

procedure TfrmMain.PopupMenuArchiveBrowsePopup(Sender: TObject);
var
  HasSel: Boolean;
  Idx: Integer;
begin
  Idx := LvGetFocusedIndex(lvAddFiles);
  HasSel := (LvSelectedCount(lvAddFiles) > 0) and
    ((Idx < 0) or (Idx >= Length(FAddFilesList)) or (FAddFilesList[Idx].Name <> '..'));
  mnuArchiveExtract1.Enabled    := HasSel;
  mnuArchiveExtractAll.Enabled  := True;  // sempre disponibile
  mnuArchiveExtract2.Enabled    := HasSel;
end;

procedure TfrmMain.mnuArchiveBackClick(Sender: TObject);
begin
  ExitArchiveBrowseMode;
end;

{ Extract... — passa la lista dei file selezionati.
  Con 1 file: -to è un FILE (catpaqmode).
  Con N file: -to deve avere N token (validato in frmExtract). }
procedure TfrmMain.mnuArchiveExtract1Click(Sender: TObject);
var
  Dialog: TfrmExtract;
  SelNames: TStringList;
  J, Idx: Integer;
  SelName, SelFullPath: string;
  N: PVirtualNode;
begin
  if not FArchiveBrowseMode then Exit;

  SelNames := TStringList.Create;
  try
    { Raccoglie tutti gli item selezionati (escluso "..") }
    N := lvAddFiles.GetFirstSelected;
    while N <> nil do
    begin
      Idx := N^.Index;
      if (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..') then
      begin
        SelName := FAddFilesList[Idx].Name;
        { Cerca il path completo nell'archivio data }
        SelFullPath := SelName;
        for J := 0 to High(FArchiveData.Files) do
          if SameText(ExtractFileName(ExcludeTrailingPathDelimiter(
               FArchiveData.Files[J].FileName)), SelName) then
          begin
            SelFullPath := FArchiveData.Files[J].FileName;
            Break;
          end;
        SelNames.Add(SelFullPath);
      end;
      N := lvAddFiles.GetNextSelected(N);
    end;

    if SelNames.Count = 0 then Exit;

    Dialog := TfrmExtract.Create(Self);
    try
      if SelNames.Count = 1 then
        Dialog.SetExtractionParams(FArchiveBrowsePath, SelNames[0], -1,
                                   FPasswordKey, FPasswordFranzen)
      else
        Dialog.SetExtractionParamsMulti(FArchiveBrowsePath, SelNames,
                                        FPasswordKey, FPasswordFranzen);
      Dialog.SetExternalPath(FBridge.ExternalPath);
      Dialog.ShowModal;
      if Dialog.GetDestPath <> '' then
        AddLog('Archive browse extraction destination: ' + Dialog.GetDestPath);
    finally
      Dialog.Free;
    end;
  finally
    SelNames.Free;
  end;
end;

{ Extract all... — nessun filtro file, -to è sempre una CARTELLA }
procedure TfrmMain.mnuArchiveExtractAllClick(Sender: TObject);
var
  Dialog: TfrmExtract;
begin
  if not FArchiveBrowseMode then Exit;

  Dialog := TfrmExtract.Create(Self);
  try
    Dialog.SetExtractionParamsAll(FArchiveBrowsePath, FPasswordKey, FPasswordFranzen);
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then
      AddLog('Archive browse extract-all destination: ' + Dialog.GetDestPath);
  finally
    Dialog.Free;
  end;
end;

procedure TfrmMain.mnuArchiveExtract2Click(Sender: TObject);
begin
  ShowTestDialog(GetSelectedZpaqPath);
end;

procedure TfrmMain.ApplyAddFilter(const AFilter: string);
var I: Integer; SearchText, ItemName, ItemNameNoSlash: string; ExactMatch, Match, CaseSensitive: Boolean; MatchCount: Integer; N: PVirtualNode;
begin
  if Trim(AFilter) = '' then begin lvAddFiles.ClearSelection; Exit; end;
  ExactMatch := False; SearchText := Trim(AFilter); CaseSensitive := IsCaseSensitiveFS;
  if (Length(SearchText) > 0) and (SearchText[1] = '=') then begin ExactMatch := True; SearchText := Copy(SearchText, 2, Length(SearchText)); end;
  MatchCount := 0; lvAddFiles.ClearSelection;
  N := lvAddFiles.GetFirst;
  I := 0;
  while N <> nil do
  begin
    if (I >= 0) and (I < Length(FAddFilesList)) then
    begin
      ItemName := FAddFilesList[I].Name;
      if ItemName <> '..' then
      begin
        ItemNameNoSlash := ItemName;
        if (Length(ItemNameNoSlash) > 0) and (ItemNameNoSlash[Length(ItemNameNoSlash)] = '/') then ItemNameNoSlash := Copy(ItemNameNoSlash, 1, Length(ItemNameNoSlash) - 1);
        if ExactMatch then begin if CaseSensitive then Match := (ItemNameNoSlash = SearchText) else Match := (LowerCase(ItemNameNoSlash) = LowerCase(SearchText)); end
        else begin if CaseSensitive then Match := (Pos(SearchText, ItemNameNoSlash) > 0) else Match := (Pos(LowerCase(SearchText), LowerCase(ItemNameNoSlash)) > 0); end;
        if Match then begin lvAddFiles.Selected[N] := True; Inc(MatchCount); if MatchCount = 1 then lvAddFiles.FocusedNode := N; end;
      end;
    end;
    N := lvAddFiles.GetNext(N);
    Inc(I);
  end;
  lvAddFiles.Invalidate; if lvAddFiles.CanFocus then lvAddFiles.SetFocus;
  AddLog(Format('Filter "%s": %d item(s) selected', [AFilter, MatchCount]));
end;

function TfrmMain.BuildSelectedFilesString: string;
var N: PVirtualNode; Idx: Integer; FilePath: string;
begin
  Result := '';
  N := lvAddFiles.GetFirstSelected;
  while N <> nil do
  begin
    Idx := N^.Index;
    if (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..') then
    begin
      FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
      if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
      if Result <> '' then Result := Result + ' ';
      Result := Result + '"' + FilePath + '"';
    end;
    N := lvAddFiles.GetNextSelected(N);
  end;
end;

function TfrmMain.BuildAllFilesString: string;
var I: Integer; FilePath: string;
begin
  Result := '';
  for I := 0 to High(FAddFilesList) do
  begin
    if FAddFilesList[I].Name = '..' then Continue;
    FilePath := FCurrentAddPath + FAddFilesList[I].Name;
    if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
    if Result <> '' then Result := Result + ' ';
    Result := Result + '"' + FilePath + '"';
  end;
end;

function TfrmMain.HasOnlyFoldersSelected: Boolean;
var N: PVirtualNode; Idx: Integer; HasSelection: Boolean;
begin
  Result := True; HasSelection := False;
  N := lvAddFiles.GetFirstSelected;
  while N <> nil do
  begin
    Idx := N^.Index;
    if (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..') then
    begin
      HasSelection := True;
      if not FAddFilesList[Idx].IsDirectory then begin Result := False; Exit; end;
    end;
    N := lvAddFiles.GetNextSelected(N);
  end;
  if not HasSelection then Result := False;
end;

procedure TfrmMain.OpenSelectedFile;
var Idx: Integer; FilePath, FileExt: string;
begin
  if FLoadingArchive then Exit;
  Idx := LvGetFocusedIndex(lvAddFiles);
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;

  if FAddFilesList[Idx].Name = '..' then
  begin
    if FArchiveBrowseMode then ExitArchiveBrowseMode
    else btnAddUpClick(nil);
    Exit;
  end;

  if FArchiveBrowseMode then
  begin
    if FLoadingArchive then Exit;
    { In browse mode: se è un .zpaq, esci dal browse e aprilo }
    FilePath := FAddFilesList[Idx].Name;
    FileExt  := LowerCase(ExtractFileExt(FilePath));
    if (FileExt = '.zpaq') or (Pos('.zpaq.franzen', LowerCase(FilePath)) > 0) then
    begin
      { Serve il path completo nel filesystem — cerca il file nella directory corrente }
      FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
      if FileExists(FilePath) then
      begin
        ExitArchiveBrowseMode;
        OpenZpaqFile(FilePath);
      end
      else
        AddLog('Archive browse: .zpaq not found on disk: ' + FilePath);
    end
    else
      AddLog('Archive browse: selected "' + FAddFilesList[Idx].Name + '"');
    Exit;
  end;

  if FAddFilesList[Idx].IsDirectory then
  begin
    NavigateToPath(FAddFilesList[Idx].FullPath);
    Exit;
  end;

  FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
  FileExt  := LowerCase(ExtractFileExt(FilePath));
  if (FileExt = '.zpaq') or (Pos('.zpaq.franzen', LowerCase(FilePath)) > 0) then
  begin
    OpenZpaqFile(FilePath);
    Exit;
  end;
  {$IFDEF WINDOWS}
  ShellExecute(0, 'open', PChar(FilePath), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  OpenDocument(FilePath);
  {$ENDIF}
end;

procedure TfrmMain.OpenZpaqFile(const AFilePath: string);
begin
  FLoadingArchive    := True;
  FLogProgressLineIndex := -1;
  FFileListAbortRequested := False;
  FArchiveBrowsePath := AFilePath;
  // Determina se siamo nella tab Browse: in tal caso mostra pnlLoading inline
  FLoadFromBrowseTab := (PageControl1.ActivePage = TabAdd);
  SetLoadingState(True);
  DoLoadArchive(AFilePath);
  // NON cambiamo tab qui: OnFileListComplete decide in base al conteggio versioni
end;

procedure TfrmMain.OpenInExplorer;
var Idx: Integer; FilePath: string;
begin
  Idx := LvGetFocusedIndex(lvAddFiles);
  if (Idx >= 0) and (Idx < Length(FAddFilesList)) then
  begin
    if FAddFilesList[Idx].Name = '..' then
      FilePath := ExtractFilePath(ExcludeTrailingPathDelimiter(FCurrentAddPath))
    else if FAddFilesList[Idx].IsDirectory then
      FilePath := FAddFilesList[Idx].FullPath
    else
      FilePath := FCurrentAddPath;
    {$IFDEF WINDOWS} ShellExecute(0, 'explore', PChar(FilePath), nil, nil, SW_SHOWNORMAL); {$ELSE} OpenDocument(FilePath); {$ENDIF}
    Exit;
  end;
  {$IFDEF WINDOWS} ShellExecute(0, 'explore', PChar(FCurrentAddPath), nil, nil, SW_SHOWNORMAL); {$ELSE} OpenDocument(FCurrentAddPath); {$ENDIF}
end;

{ === Tab Add Event Handlers === }

procedure TfrmMain.btnAddAddClick(Sender: TObject); begin mnuAddFilesToZpaqClick(Sender); end;
procedure TfrmMain.btnAddTestClick(Sender: TObject);
var
  Pt: TPoint;
begin
  // 1. Imposta le coordinate manualmente (evitiamo la funzione Point() che confonde Lazarus)
  Pt.X := 0;
  Pt.Y := btnAddTest.Height;

  // 2. Le converte in coordinate assolute dello schermo
  Pt := btnAddTest.ClientToScreen(Pt);

  // 3. Fa apparire il menu a tendina esattamente incollato sotto al bottone!
  popTest.PopUp(Pt.X, Pt.Y);
end;
procedure TfrmMain.btnAddExtractClick(Sender: TObject);
begin
  AddLog('DEBUG: forced load settings');
  LoadSettingsFromIni;
  // Forza anche l'applicazione immediata della geometria (senza aspettare il timer)
  FTimerRestore.Enabled := False;
  FTimerRestore.Enabled := True;
  // mnuAddExtractToFolderClick(Sender);  { ← ripristina quando non serve più il debug }
end;

procedure TfrmMain.edtAddFilterKeyPress(Sender: TObject; var Key: Char);
begin if Key = #13 then begin Key := #0; ApplyAddFilter(edtAddFilter.Text); end; end;

procedure TfrmMain.edtAddPathKeyPress(Sender: TObject; var Key: Char);
var NewPath: string;
begin
  if Key = #13 then begin Key := #0; NewPath := Trim(edtAddPath.Text);
    if NewPath <> '' then begin if DirectoryExists(NewPath) then NavigateToPath(NewPath) else ShowMessage(S('msg_dir_not_found', 'Directory not found: ') + NewPath); end;
  end;
end;

procedure TfrmMain.btnAddUpClick(Sender: TObject);
var ParentPath: string;
begin
  if FArchiveBrowseMode then begin ExitArchiveBrowseMode; Exit; end;
  ParentPath := ExtractFilePath(ExcludeTrailingPathDelimiter(FCurrentAddPath));
  if ParentPath <> '' then NavigateToPath(ParentPath);
end;

procedure TfrmMain.btnAddRefreshClick(Sender: TObject); begin RefreshAddFilesList; end;
procedure TfrmMain.cmbAddDrivesChange(Sender: TObject); begin if cmbAddDrives.ItemIndex >= 0 then NavigateToPath(cmbAddDrives.Items[cmbAddDrives.ItemIndex]); end;
procedure TfrmMain.lvAddFilesDblClick(Sender: TObject); begin OpenSelectedFile; end;

procedure TfrmMain.lvAddFilesHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
begin
  if HitInfo.Button <> mbLeft then Exit;
  if FLvSortColumn = HitInfo.Column then
    FLvSortAscending := not FLvSortAscending
  else
  begin
    FLvSortColumn := HitInfo.Column;
    FLvSortAscending := True;
  end;
  Sender.SortColumn := FLvSortColumn;
  if FLvSortAscending then Sender.SortDirection := sdAscending
  else Sender.SortDirection := sdDescending;
  SortLvAddFiles(FLvSortColumn, FLvSortAscending);
end;

procedure TfrmMain.lvAddFilesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN: begin if ssShift in Shift then OpenInExplorer else OpenSelectedFile; Key := 0; end;
    VK_BACK: begin btnAddUpClick(nil); Key := 0; end;
    VK_F2: begin mnuAddRenameClick(nil); Key := 0; end;
    VK_F5: begin RefreshAddFilesList; Key := 0; end;
    VK_F7: begin mnuAddCreateFolderClick(nil); Key := 0; end;
    VK_DELETE: begin mnuAddDeleteClick(nil); Key := 0; end;
  end;
end;

procedure TfrmMain.lvAddFilesMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var NewSize: Integer;
begin
  if not (ssCtrl in Shift) then Exit;
  Handled := True; NewSize := lvAddFiles.Font.Size;
  if WheelDelta > 0 then Inc(NewSize) else if WheelDelta < 0 then Dec(NewSize);
  if NewSize < 6 then NewSize := 6; if NewSize > 72 then NewSize := 72;
  if NewSize <> lvAddFiles.Font.Size then
  begin
    lvAddFiles.Font.Size := NewSize;
    AddLog('File list font size: ' + IntToStr(NewSize) + ' pt');
    SaveSettingsToIni;
  end;
end;

{ === VST handlers for lvAddFiles === }

procedure TfrmMain.lvAddFilesGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
var Idx: Integer; FI: TFileExplorerItem; AttrStr: string;
begin
  CellText := '';
  Idx := Node^.Index;
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;
  FI := FAddFilesList[Idx];
  case Column of
    0: CellText := FI.Name;
    1: if FI.IsDirectory then CellText := '' else if FI.Size >= 0 then CellText := FormatFileSize(FI.Size);
    2: if FI.Modified > 0 then
       begin
         if FArchiveBrowseMode then
           { In archive mode, the date string comes from zpaqfranz and may be stored differently }
           CellText := FormatDateTime('yyyy-mm-dd hh:nn:ss', FI.Modified)
         else
           CellText := FormatDateTime('yyyy-mm-dd hh:nn', FI.Modified);
       end;
    3: if FI.Created > 0 then CellText := FormatDateTime('yyyy-mm-dd hh:nn', FI.Created);
    4: begin
         AttrStr := '';
         if FI.IsDirectory then AttrStr := '<DIR>';
         if (FI.Attributes and faReadOnly) <> 0 then AttrStr := AttrStr + 'R';
         {$IFDEF WINDOWS}
         if (FI.Attributes and faHidden) <> 0 then AttrStr := AttrStr + 'H';
         if (FI.Attributes and faSysFile) <> 0 then AttrStr := AttrStr + 'S';
         {$ENDIF}
         if (FI.Attributes and faArchive) <> 0 then AttrStr := AttrStr + 'A';
         CellText := AttrStr;
       end;
    5: if not FI.IsDirectory then CellText := LowerCase(ExtractFileExt(FI.Name));
  end;
end;

procedure TfrmMain.lvAddFilesInitNode(Sender: TBaseVirtualTree; ParentNode,
  Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
begin
  { No children, flat list }
end;

procedure TfrmMain.lvAddFilesPaintText(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);
var Idx: Integer; ItemName, LowerName: string; IsFolder, IsZpaq: Boolean;
begin
  Idx := Node^.Index;
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;
  ItemName  := FAddFilesList[Idx].Name;
  LowerName := LowerCase(ItemName);
  IsFolder  := FAddFilesList[Idx].IsDirectory or (ItemName = '..');
  IsZpaq    := (not IsFolder) and
               ( (ExtractFileExt(LowerName) = '.zpaq') or
                 (Pos('.zpaq.franzen', LowerName) > 0) );
  if IsFolder then
  begin
    TargetCanvas.Font.Color := $00007000; { dark green }
    TargetCanvas.Font.Style := [fsBold];
  end
  else if IsZpaq then
  begin
    TargetCanvas.Font.Color := clRed;
    TargetCanvas.Font.Style := [fsBold];
  end
  else
  begin
    TargetCanvas.Font.Color := clWindowText;
    TargetCanvas.Font.Style := [];
  end;
end;

procedure TfrmMain.lvAddFilesFocusChanged(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex);
begin
  UpdateZpaqButtons;
end;

function TfrmMain.IsZpaqFile(const AFileName: string): Boolean;
var LN: string;
begin
  LN := LowerCase(AFileName);
  Result := (Pos('.zpaq', LN) > 0);
end;

{ Restituisce il path dell'archivio .zpaq su cui operare.
  - In archive browse mode: è l'archivio correntemente aperto (FArchiveBrowsePath).
  - In filesystem normale: è il file .zpaq selezionato nel VST. }
function TfrmMain.GetSelectedZpaqPath: string;
var Idx: Integer; FilePath: string;
begin
  Result := '';
  if FArchiveBrowseMode then
  begin
    Result := FArchiveBrowsePath;
    Exit;
  end;
  if LvSelectedCount(lvAddFiles) <> 1 then Exit;
  Idx := LvGetFocusedIndex(lvAddFiles);
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;
  if FAddFilesList[Idx].Name = '..' then Exit;
  FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
  if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = PathDelim) then
    FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
  if Pos('.zpaq', LowerCase(FilePath)) > 0 then
    Result := FilePath;
end;

procedure TfrmMain.UpdateZpaqButtons;
var SelZpaq: Boolean; Idx: Integer; LN: string;
begin
  if FArchiveBrowseMode then
  begin
    btnAddAdd.Visible     := False;
    btnAddExtract.Visible := True;
    btnAddTest.Visible    := True;
  end
  else
  begin
    SelZpaq := False;
    if LvSelectedCount(lvAddFiles) = 1 then
    begin
      Idx := LvGetFocusedIndex(lvAddFiles);
      if (Idx >= 0) and (Idx < Length(FAddFilesList)) then
      begin
        LN := LowerCase(FAddFilesList[Idx].Name);
        SelZpaq := (Pos('.zpaq', LN) > 0);
      end;
    end;
    btnAddAdd.Visible     := True;
    btnAddExtract.Visible := SelZpaq;
    btnAddTest.Visible    := SelZpaq;
  end;
end;

procedure TfrmMain.PopupMenuAddPopup(Sender: TObject);
var HasSelection, OnlyFolders, SelZpaq: Boolean; LN: string; Idx, SelCnt: Integer;
begin
  SelCnt := LvSelectedCount(lvAddFiles);
  HasSelection := SelCnt > 0;
  OnlyFolders := HasOnlyFoldersSelected;
  if HasSelection then begin if OnlyFolders then mnuAddFilesToZpaq.Caption := S('mnu_add_folders_to_zpaq', 'Add folders to ZPAQ...') else mnuAddFilesToZpaq.Caption := S('mnu_add_files_to_zpaq', 'Add files to ZPAQ...'); end
  else mnuAddFilesToZpaq.Caption := S('mnu_add_files_to_zpaq', 'Add files to ZPAQ...');
  mnuAddFilesToZpaq.Enabled := HasSelection; mnuAddOpen.Enabled := HasSelection; mnuAddOpenInExplorer.Enabled := True;
  SelZpaq := False;
  if SelCnt = 1 then
  begin
    Idx := LvGetFocusedIndex(lvAddFiles);
    if (Idx >= 0) and (Idx < Length(FAddFilesList)) then begin LN := LowerCase(FAddFilesList[Idx].Name); SelZpaq := (Pos('.zpaq', LN) > 0); end;
  end;
  mnuAddExtractToFolder.Enabled := SelZpaq; mnuAddExtractToFolder.Visible := True;
  mnuAddBrowseVersions.Enabled  := SelZpaq; mnuAddBrowseVersions.Visible  := True;
  mnuAddTestZpaq.Enabled := SelZpaq; mnuAddTestZpaq.Visible := True;
  mnuAddTestAllZpaq.Enabled := SelZpaq; mnuAddTestAllZpaq.Visible := True;
  Idx := LvGetFocusedIndex(lvAddFiles);
  mnuAddRename.Enabled := (SelCnt = 1) and (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..');
  mnuAddDelete.Enabled := HasSelection and not ((SelCnt = 1) and (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name = '..'));
  mnuAddProperties.Enabled := HasSelection;
  mnuAddHash.Enabled       := HasSelection and not FArchiveBrowseMode;
end;

procedure TfrmMain.mnuAddFilesToZpaqClick(Sender: TObject);
var FilesList: TStringList; N: PVirtualNode; Idx: Integer; FilePath: string;
begin
  FilesList := TStringList.Create;
  try
    N := lvAddFiles.GetFirstSelected;
    while N <> nil do
    begin
      Idx := N^.Index;
      if (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..') then
      begin
        FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
        if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
        FilesList.Add(FilePath);
      end;
      N := lvAddFiles.GetNextSelected(N);
    end;
    if FilesList.Count > 0 then begin AddLog(Format('Opening Add dialog with %d selected item(s)', [FilesList.Count])); ShowAddDialog(FilesList); end
    else AddLog('No files selected');
  finally FilesList.Free; end;
end;

procedure TfrmMain.mnuAddAllToZpaqClick(Sender: TObject);
var FilesList: TStringList; I: Integer; FilePath: string;
begin
  FilesList := TStringList.Create;
  try
    for I := 0 to High(FAddFilesList) do begin
      if FAddFilesList[I].Name = '..' then Continue;
      FilePath := FCurrentAddPath + FAddFilesList[I].Name;
      if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
      FilesList.Add(FilePath);
    end;
    if FilesList.Count > 0 then begin AddLog(Format('Opening Add dialog with ALL %d item(s)', [FilesList.Count])); ShowAddDialog(FilesList); end
    else AddLog('No files to add');
  finally FilesList.Free; end;
end;

procedure TfrmMain.mnuAddOpenClick(Sender: TObject); begin OpenSelectedFile; end;
procedure TfrmMain.mnuAddOpenInExplorerClick(Sender: TObject); begin OpenInExplorer; end;

procedure TfrmMain.mnuAddRenameClick(Sender: TObject);
var OldName, NewName, OldPath, NewPath: string; Idx: Integer;
begin
  Idx := LvGetFocusedIndex(lvAddFiles);
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;
  if FAddFilesList[Idx].Name = '..' then Exit;
  OldName := FAddFilesList[Idx].Name;
  if (Length(OldName) > 0) and (OldName[Length(OldName)] = '/') then OldName := Copy(OldName, 1, Length(OldName) - 1);
  NewName := InputBox(S('dlg_rename_title', 'Rename'), S('dlg_rename_prompt', 'Enter new name:'), OldName);
  if (NewName <> '') and (NewName <> OldName) then begin
    OldPath := FCurrentAddPath + OldName; NewPath := FCurrentAddPath + NewName;
    if RenameFile(OldPath, NewPath) then begin AddLog('Renamed: ' + OldName + ' -> ' + NewName); RefreshAddFilesList; end
    else ShowMessage(S('msg_rename_failed', 'Failed to rename file.'));
  end;
end;

procedure TfrmMain.mnuAddDeleteClick(Sender: TObject);
var DeleteCount, SelCnt: Integer; FilePath: string; N: PVirtualNode; Idx: Integer;
begin
  SelCnt := LvSelectedCount(lvAddFiles);
  if SelCnt = 0 then Exit;
  if MessageDlg(S('dlg_delete_title', 'Confirm Delete'), Format(S('dlg_delete_prompt', 'Are you sure you want to delete %d item(s)?'), [SelCnt]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DeleteCount := 0;
  N := lvAddFiles.GetFirstSelected;
  while N <> nil do
  begin
    Idx := N^.Index;
    if (Idx >= 0) and (Idx < Length(FAddFilesList)) and (FAddFilesList[Idx].Name <> '..') then
    begin
      FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
      if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
      if DirectoryExists(FilePath) then begin if RemoveDir(FilePath) then Inc(DeleteCount); end
      else begin if SysUtils.DeleteFile(FilePath) then Inc(DeleteCount); end;
    end;
    N := lvAddFiles.GetNextSelected(N);
  end;
  AddLog(Format('Deleted %d item(s)', [DeleteCount])); RefreshAddFilesList;
end;

procedure TfrmMain.mnuAddCreateFolderClick(Sender: TObject);
var FolderName, FolderPath: string;
begin
  FolderName := InputBox(S('dlg_create_folder_title', 'Create Folder'), S('dlg_create_folder_prompt', 'Enter folder name:'), '');
  if FolderName <> '' then begin
    FolderPath := FCurrentAddPath + FolderName;
    if CreateDir(FolderPath) then begin AddLog('Created folder: ' + FolderName); RefreshAddFilesList; end
    else ShowMessage(S('msg_create_folder_failed', 'Failed to create folder.'));
  end;
end;

procedure TfrmMain.mnuAddPropertiesClick(Sender: TObject);
var FilePath: string; Idx: Integer;
  {$IFDEF WINDOWS} SEI: SHELLEXECUTEINFOW; WFilePath, WVerb: WideString; {$ENDIF}
begin
  Idx := LvGetFocusedIndex(lvAddFiles);
  if (Idx < 0) or (Idx >= Length(FAddFilesList)) then Exit;
  if FAddFilesList[Idx].Name = '..' then Exit;
  FilePath := FCurrentAddPath + FAddFilesList[Idx].Name;
  if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
  {$IFDEF WINDOWS}
  WFilePath := FilePath; WVerb := 'properties';
  {$PUSH}{$HINTS OFF}
  FillChar(SEI, SizeOf(SEI), 0); SEI.cbSize := SizeOf(SEI); SEI.lpFile := PWideChar(WFilePath); SEI.lpVerb := PWideChar(WVerb); SEI.fMask := SEE_MASK_INVOKEIDLIST;
  {$POP}
  ShellExecuteExW(@SEI);
  {$ELSE} AddLog('Properties for: ' + FilePath); {$ENDIF}
end;

{ --- SISTEMA CALCOLO HASH COMPLETO --- }

procedure TfrmMain.mnuHashClick(Sender: TObject);
var
  HashAlgo, FilesStr, Cmd: string;
begin
  if not (Sender is TMenuItem) then Exit;

  // Il check SSD deve solo cambiare lo stato grafico, non esegue l'hash
  if Sender = mnuHashSSD then Exit;

  // 1. Mappatura algoritmi di hash
  if Sender = mnuHashCRC32 then HashAlgo := '-crc32'
  else if Sender = mnuHashXXHash then HashAlgo := '-xxhash'
  else if Sender = mnuHashSHA1 then HashAlgo := '-sha1'
  else if Sender = mnuHashSHA256 then HashAlgo := '-sha256'
  else if Sender = mnuHashXXH3 then HashAlgo := '-xxh3'
  else if Sender = mnuHashBLAKE3 then HashAlgo := '-blake3'
  else if Sender = mnuHashSHA3 then HashAlgo := '-sha3'
  else if Sender = mnuHashMD5 then HashAlgo := '-md5'
  else if Sender = mnuHashWhirlpool then HashAlgo := '-whirlpool'
  else if Sender = mnuHashHighway64 then HashAlgo := '-highway64'
  else if Sender = mnuHashHighway128 then HashAlgo := '-highway128'
  else if Sender = mnuHashHighway256 then HashAlgo := '-highway256'
  else if Sender = mnuHashWyhash then HashAlgo := '-wyhash'
  else if Sender = mnuHashNilsimsa then HashAlgo := '-nilsimsa'
  else if Sender = mnuHashEntropy then HashAlgo := '-entropy'
  else if Sender = mnuHashQuick then HashAlgo := '-quick'
  else if Sender = mnuHashZeta then HashAlgo := '-zeta'
  else if Sender = mnuHashFranzMulti then HashAlgo := '-franzhash'
  else if Sender = mnuHashFranzSingle then HashAlgo := '-franzhash -frugal'
  else
  begin
    AddLog('Algoritmo di Hash sconosciuto.');
    Exit;
  end;

  // 2. Acquisizione File
  FilesStr := BuildSelectedFilesString;
  if FilesStr = '' then Exit;

  FHashFileCount := LvSelectedCount(lvAddFiles);

  // 3. Preparazione Comando
  Cmd := 'hash ' + FilesStr + ' -catpaqmode -terse ' + HashAlgo;

  // Se la spunta Hash SSD è attiva, aggiungiamo il parametro multithread
  if mnuHashSSD.Checked then
    Cmd := Cmd + ' -ssd';

  // 4. Configurazione e Avvio interfaccia
  PageControl1.ActivePage := TabLog;
  MemoLog.Lines.Clear;
  AddLog('Avvio calcolo Hash...');
  AddLog('Algoritmo scelto: ' + HashAlgo);
  if mnuHashSSD.Checked then AddLog('Modalità SSD (Multithread) attiva.');
  AddLog('Comando: zpaqfranz ' + Cmd);
  AddLog('Attendere, l''operazione potrebbe richiedere tempo...');
  AddLog('');

  pgrProgressLog.Position := 0;

  FBridgeOp := 'HASH';
  FBridge.IsDataMode := False; // L'output terse va nel log normale

  btnOpen.Enabled := False;
  TimerUpdate.Enabled := True;

  if not FBridge.RunCommandAsync(Cmd) then
  begin
    AddLog('ERRORE: Impossibile avviare il calcolo dell''hash.');
    pgrProgressLog.Position := 0;
    btnOpen.Enabled := True;
    FBridgeOp := 'LIST';
  end;
end;


procedure TfrmMain.ShowAddDialog(AFilesList: TStringList);
var
  Dialog: TfrmSimply;
begin
  if AFilesList.Count = 0 then Exit;
  Dialog := TfrmSimply.Create(Self);
  try
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.SetFileList(AFilesList);
    if Dialog.ShowModal = mrOK then
    begin
      if Dialog.cmbArchiveName.Text <> '' then
      begin
        Dialog.SaveRecentArchive(Dialog.cmbArchiveName.Text);
        AddLog('Archive selected: ' + Dialog.cmbArchiveName.Text);
      end;
    end
    else AddLog('Add operation cancelled');
  finally Dialog.Free; end;
end;

procedure TfrmMain.ShowExtractDialog;
var Dialog: TfrmExtract; FE: TArchiveFileEntry; FV: TFileVersion;
begin
  if not GetFocusedVersion(FE, FV) then Exit;
  Dialog := TfrmExtract.Create(Self);
  try
    Dialog.SetExtractionParams(FArchivePath, FE.FileName, FV.Version, FPasswordKey, FPasswordFranzen);
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then AddLog('Last extraction destination: ' + Dialog.GetDestPath);
  finally Dialog.Free; end;
end;

procedure TfrmMain.ShowExtractAllDialog;
var Dialog: TfrmExtract;
begin
  if FArchivePath = '' then begin ShowMessage('No archive loaded.'); Exit; end;
  Dialog := TfrmExtract.Create(Self);
  try
    Dialog.SetExtractionParamsAll(FArchivePath, FPasswordKey, FPasswordFranzen);
    Dialog.SetExternalPath(FBridge.ExternalPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then AddLog('Extract all destination: ' + Dialog.GetDestPath);
  finally Dialog.Free; end;
end;


procedure TfrmMain.itmAllClick(Sender: TObject);
var FilePath, Cmd: string;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then Exit;

  Cmd := 't "' + FilePath + '" -catpaqmode -all';
  PageControl1.ActivePage := TabLog;
  MemoLog.Lines.Clear;
  FTestProgressLineIndex := -1;
  AddLog('Test archive (all versions): ' + FilePath);
  AddLog('Command: zpaqfranz ' + Cmd);
  AddLog('');

  FBridgeOp := 'TEST';
  FBridge.IsDataMode := False;
  btnOpen.Enabled := False;
  TimerUpdate.Enabled := True;

  if not FBridge.RunCommandAsync(Cmd) then
  begin
    AddLog('ERROR: Failed to start test command.');
    btnOpen.Enabled := True;
    TimerUpdate.Enabled := False;
    FBridgeOp := 'LIST';
  end;
end;

procedure TfrmMain.itmLastversionClick(Sender: TObject);
var FilePath, Cmd: string;
begin
  FilePath := GetSelectedZpaqPath;
  if FilePath = '' then Exit;

  Cmd := 't "' + FilePath + '" -catpaqmode';
  PageControl1.ActivePage := TabLog;
  MemoLog.Lines.Clear;
  FTestProgressLineIndex := -1;
  AddLog('Test archive (last version): ' + FilePath);
  AddLog('Command: zpaqfranz ' + Cmd);
  AddLog('');

  FBridgeOp := 'TEST';
  FBridge.IsDataMode := False;
  btnOpen.Enabled := False;
  TimerUpdate.Enabled := True;

  if not FBridge.RunCommandAsync(Cmd) then
  begin
    AddLog('ERROR: Failed to start test command.');
    btnOpen.Enabled := True;
    TimerUpdate.Enabled := False;
    FBridgeOp := 'LIST';
  end;
end;

{ ============================================================================ }
{ === SORT IMPLEMENTATIONS ================================================== }
{ ============================================================================ }

{ --- Sort del VST (file list archivio) --- }

procedure TfrmMain.VSTHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
begin
  if HitInfo.Button <> mbLeft then Exit;
  if Length(FFilteredFiles) = 0 then Exit;

  if FVstSortColumn = HitInfo.Column then
    FVstSortAscending := not FVstSortAscending
  else
  begin
    FVstSortColumn := HitInfo.Column;
    FVstSortAscending := True;
  end;

  // Aggiorna indicatore visivo header
  Sender.SortColumn := FVstSortColumn;
  if FVstSortAscending then Sender.SortDirection := sdAscending
  else Sender.SortDirection := sdDescending;

  SortFilteredFiles(FVstSortColumn, FVstSortAscending);
  VST.Invalidate;
end;

procedure TfrmMain.SortFilteredFiles(AColumn: Integer; AAscending: Boolean);
  function GetSortKey(AFileIdx: Integer): string;
  var FE: TArchiveFileEntry; BestIdx, TargetVer, k: Integer;
  begin
    FE := FArchiveData.Files[AFileIdx];
    BestIdx := -1;
    if (FTreeMode = tmSingleVersion) and (FCurrentVersion > 0) and
       (FCurrentVersion - 1 < Length(FArchiveData.GlobalVersions)) then
    begin
      TargetVer := FArchiveData.GlobalVersions[FCurrentVersion - 1].Number;
      for k := 0 to High(FE.Versions) do
        if FE.Versions[k].Version <= TargetVer then BestIdx := k;
    end
    else if Length(FE.Versions) > 0 then
      BestIdx := High(FE.Versions);

    case AColumn of
      0: Result := LowerCase(FE.FileName);
      1: if BestIdx >= 0 then Result := Format('%10d', [FE.Versions[BestIdx].Version]) else Result := '';
      2: if BestIdx >= 0 then Result := SplitDateTime(FE.Versions[BestIdx].DateStr, False) else Result := '';
      3: if BestIdx >= 0 then Result := SplitDateTime(FE.Versions[BestIdx].DateStr, True) else Result := '';
      4: if BestIdx >= 0 then Result := Format('%20d', [FE.Versions[BestIdx].Size]) else Result := '';
    else
      Result := LowerCase(FE.FileName);
    end;
  end;

var
  I, J, N: Integer;
  Swapped: Boolean;
  Tmp: Integer;
  KeyI, KeyJ: string;
begin
  N := Length(FFilteredFiles);
  if N <= 1 then Exit;

  // Bubble sort semplice (efficiente per liste tipiche <10k elementi)
  repeat
    Swapped := False;
    for I := 0 to N - 2 do
    begin
      J := I + 1;
      KeyI := GetSortKey(FFilteredFiles[I]);
      KeyJ := GetSortKey(FFilteredFiles[J]);
      if AAscending then
      begin
        if KeyI > KeyJ then
        begin
          Tmp := FFilteredFiles[I]; FFilteredFiles[I] := FFilteredFiles[J]; FFilteredFiles[J] := Tmp;
          Swapped := True;
        end;
      end
      else
      begin
        if KeyI < KeyJ then
        begin
          Tmp := FFilteredFiles[I]; FFilteredFiles[I] := FFilteredFiles[J]; FFilteredFiles[J] := Tmp;
          Swapped := True;
        end;
      end;
    end;
    Dec(N);
  until not Swapped;

  // Ricostruisce l'albero con il nuovo ordine
  VST.BeginUpdate;
  try
    VST.Clear;
    VST.RootNodeCount := Length(FFilteredFiles);
  finally
    VST.EndUpdate;
  end;
end;

{ --- Sort del file list (lvAddFiles) --- }

procedure TfrmMain.SortLvAddFiles(AColumn: Integer; AAscending: Boolean);
var
  I, J, N, HasDotDot: Integer;
  Swapped: Boolean;
  TmpItem: TFileExplorerItem;
  KeyI, KeyJ: string;

  function SortKey(const FI: TFileExplorerItem): string;
  begin
    case AColumn of
      0: if FI.IsDirectory then Result := #0 + LowerCase(FI.Name)
         else Result := #1 + LowerCase(FI.Name);
      1: if FI.IsDirectory then Result := #0 + LowerCase(FI.Name)
         else Result := #1 + Format('%030d', [FI.Size]);
      2: if FI.IsDirectory then Result := #0 + FormatDateTime('yyyymmddhhnnss', FI.Modified)
         else Result := #1 + FormatDateTime('yyyymmddhhnnss', FI.Modified);
      3: if FI.IsDirectory then Result := #0 + FormatDateTime('yyyymmddhhnnss', FI.Created)
         else Result := #1 + FormatDateTime('yyyymmddhhnnss', FI.Created);
      4: begin
           Result := '';
           if FI.IsDirectory then Result := '<DIR>';
           if (FI.Attributes and faReadOnly) <> 0 then Result := Result + 'R';
         end;
      5: if FI.IsDirectory then Result := #0 + LowerCase(FI.Name)
         else Result := #1 + LowerCase(ExtractFileExt(FI.Name));
    else
      Result := LowerCase(FI.Name);
    end;
  end;

begin
  N := Length(FAddFilesList);
  if N <= 1 then Exit;

  HasDotDot := 0;
  if (N > 0) and (FAddFilesList[0].Name = '..') then
    HasDotDot := 1;

  N := N - HasDotDot;
  if N <= 1 then Exit;

  // Bubble sort su FAddFilesList (escludendo ".." in posizione 0)
  repeat
    Swapped := False;
    for I := HasDotDot to HasDotDot + N - 2 do
    begin
      J := I + 1;
      KeyI := SortKey(FAddFilesList[I]);
      KeyJ := SortKey(FAddFilesList[J]);
      if AAscending then
      begin
        if KeyI > KeyJ then
        begin
          TmpItem := FAddFilesList[I]; FAddFilesList[I] := FAddFilesList[J]; FAddFilesList[J] := TmpItem;
          Swapped := True;
        end;
      end
      else
      begin
        if KeyI < KeyJ then
        begin
          TmpItem := FAddFilesList[I]; FAddFilesList[I] := FAddFilesList[J]; FAddFilesList[J] := TmpItem;
          Swapped := True;
        end;
      end;
    end;
    Dec(N);
  until not Swapped;

  // Refresh del VST (i nodi sono virtualizzati, basta invalidare)
  lvAddFiles.BeginUpdate;
  try
    lvAddFiles.Clear;
    lvAddFiles.RootNodeCount := Length(FAddFilesList);
  finally
    lvAddFiles.EndUpdate;
  end;
end;



procedure TfrmMain.btnHelpClick(Sender: TObject);
begin OpenURL('https://github.com/fcorbelli/catpaq/wiki'); end;


end.
