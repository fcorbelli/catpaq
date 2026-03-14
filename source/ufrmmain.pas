
unit ufrmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Menus, Clipbrd, IniFiles, LCLType, LCLIntf, FileInfo, Math, dynlibs,
  {$IFDEF WINDOWS}
  Registry, Windows, ShellApi,
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
  // @@DLL_HASH_START@@
  EXPECTED_DLL_HASH = 'aaad8c75b39df85d3fe77c9218dd145034f08881bf7bb53ee676d679d6950763';
  // @@DLL_HASH_END@@
  
  // @@EXE_HASH_START@@
  EXPECTED_EXE_HASH = '1f7e167bbb9a938af533a22bab10b7aa7691571b6f404dfe9d7f7e06e9c7e28e';
  // @@EXE_HASH_END@@

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
    lblAdminStatus: TLabel;
    lblArchiveInfo: TLabel;
    lblCurrentFont: TLabel;
    lblFileCount: TLabel;
    lblFilter: TLabel;
    lblFilterInfo: TLabel;
    lblLoadInfo: TLabel;
    lblZoomValue: TLabel;
    MemoLog: TMemo;
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
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    TabArchive: TTabSheet;
    TabLog: TTabSheet;
    TabSettings: TTabSheet;
    TabAdd: TTabSheet;
    tbZoom: TTrackBar;
    TimerUpdate: TTimer;
    TrackBar1: TTrackBar;
    VST: TLazVirtualStringTree;

    // Tab Add components
    pnlAddToolbar: TPanel;
    pnlAddFilter: TPanel;
    pnlAddNav: TPanel;
    lvAddFiles: TListView;
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
    mnuArchiveExtract1: TMenuItem;
    mnuArchiveExtract2: TMenuItem;

    procedure btnExit2Click(Sender: TObject);
    procedure btnHelp1Click(Sender: TObject);
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
    procedure lvAddFilesColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvAddFilesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lvAddFilesMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure lvAddFilesAdvancedCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure lvAddFilesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure PopupMenuAddPopup(Sender: TObject);
    procedure mnuAddFilesToZpaqClick(Sender: TObject);
    procedure mnuAddAllToZpaqClick(Sender: TObject);
    procedure mnuAddExtractToFolderClick(Sender: TObject);
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
    FDLLAbortRequested: Boolean; // True = utente ha premuto Abort durante listing DLL sincrono

    // --- Pannello Abort nella TabLog (creato a runtime) ---
    pnlLogToolbar: TPanel;
    btnAbortLoad:  TButton;
    lblLogStatus:  TLabel;

    // --- Componenti generati a runtime per evitare EReadError ---
    pmLog: TPopupMenu;
    mnuSaveLog: TMenuItem;
    mnuLogBack: TMenuItem;
    mnuLogClear: TMenuItem;
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
    procedure MemoLogKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnAbortLoadClick(Sender: TObject);
    procedure SetLoadingState(ALoading: Boolean);
    procedure OnDLLListComplete(Data: PtrInt);
    procedure DLLGuiUpdate(Data: PtrInt);
    procedure DoLoadArchive(const AFileName: string);
    procedure ShowArchiveBrowse(const AArchivePath: string; const AData: TArchiveData);
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

    function IsZpaqFile(const AFileName: string): Boolean;
    procedure UpdateZpaqButtons;
    function GetSelectedZpaqPath: string;
    function TryDownloadDLL: Boolean;
    function ExecuteStartupChecks: Boolean; // True = OK, False = errore/avviso
    function ValidateDLL: Boolean;
    function ValidateEXE: Boolean;
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
         { === DEFINIZIONI C/C++ PER LISTING VELOCE TRAMITE DLL === }

{ === DEFINIZIONI C/C++ PER LISTING VELOCE TRAMITE DLL === }

type
  TOutputCallback = procedure(line: PAnsiChar); cdecl;
  TZpaqRunCommand = function(lpCmdLine: PAnsiChar): Integer; cdecl;
  TZpaqResetProc  = procedure; cdecl;

{ Thread che esegue ZpaqRun in background, liberando il thread principale
  per gestire la UI (progress bar, bottone ABORT, ecc.). }
type
  TDLLListThread = class(TThread)
  private
    FCommand:   AnsiString;
    FZpaqRun:   TZpaqRunCommand;
    FZpaqReset: TZpaqResetProc;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACommand: AnsiString;
                       AZpaqRun:   TZpaqRunCommand;
                       AZpaqReset: TZpaqResetProc);
    function ThreadHandle: THandle;
  end;

var
  FastDLLBuffer:   TStringList = nil;
  FastDLLPending:  string = '';
  FastDLLThread:   TDLLListThread = nil;
  FastDLLhDLL:     TLibHandle = NilHandle;
  FastDLLDone:     Boolean = False;   // settato dal thread quando ha finito

{ === DEBUG: file di log grezzo per FastDLLOutputCallback === }
var
  FastDLLDbgFile: string = '';

procedure FastDLLDbgWrite(const ALine: string);
var F: TextFile;
begin
  if not DebugMode then Exit;
  if FastDLLDbgFile = '' then
    FastDLLDbgFile := ExtractFilePath(ParamStr(0)) + 'catpaq_dll_debug.txt';
  AssignFile(F, FastDLLDbgFile);
  {$I-}
  if FileExists(FastDLLDbgFile) then Append(F) else Rewrite(F);
  if IOResult = 0 then begin Writeln(F, ALine); Flush(F); CloseFile(F); end;
  {$I+}
end;
{ === FINE HELPERS DEBUG === }

{ === TDLLListThread === }

constructor TDLLListThread.Create(const ACommand: AnsiString;
                                   AZpaqRun:   TZpaqRunCommand;
                                   AZpaqReset: TZpaqResetProc);
begin
  inherited Create(True); // CreateSuspended
  FCommand   := ACommand;
  FZpaqRun   := AZpaqRun;
  FZpaqReset := AZpaqReset;
  FreeOnTerminate := False;
end;

procedure TDLLListThread.Execute;
begin
  try
    FZpaqRun(PAnsiChar(FCommand));
  finally
    if Assigned(FZpaqReset) then FZpaqReset;
    FastDLLDone := True;
    Application.QueueAsyncCall(@frmMain.OnDLLListComplete, 0);
  end;
end;

function TDLLListThread.ThreadHandle: THandle;
begin
  Result := Handle;
end;

{ === FastDLL callback — chiamata dal TDLLListThread, NON dal thread principale.
  Non tocca direttamente i controlli GUI: usa QueueAsyncCall per il progresso
  e variabili globali protette per i dati. === }

var
  FastDLLLastPercent: Integer = -1; // ultimo % inviato alla GUI (evita spam)

procedure FastDLLOutputCallback(line: PAnsiChar); cdecl;
var
  P, StartP: PChar;
  S, PercStr: string;
  Percent, ExpectedLines: Integer;
begin
  if not Assigned(FastDLLBuffer) then Exit;

  P := line;
  StartP := P;
  while P^ <> #0 do
  begin
    if P^ = #10 then
    begin
      SetString(S, StartP, P - StartP);
      if (Length(S) > 0) and (S[Length(S)] = #13) then
        SetLength(S, Length(S) - 1);

      S := FastDLLPending + S;
      FastDLLPending := '';
      StartP := P + 1;

      FastDLLDbgWrite(FormatDateTime('hh:nn:ss.zzz', Now) + ' [' + S + ']');

      // INTERCETTA LA TELEMETRIA NATIVA DI ZPAQFRANZ
      if Pos('$$$NULL-W', S) = 1 then
      begin
        PercStr := Trim(Copy(S, 11, 3));
        Percent := StrToIntDef(PercStr, 0);

        FastDLLDbgWrite('  --> $$$NULL-W riconosciuto, PercStr="' + PercStr + '" Percent=' + IntToStr(Percent));

        // Aggiorna la GUI nel thread principale (thread-safe)
        if Percent <> FastDLLLastPercent then
        begin
          FastDLLLastPercent := Percent;
          Application.QueueAsyncCall(@frmMain.DLLGuiUpdate, PtrInt(Percent));
        end;

        // Controlla abort: se richiesto svuota il buffer così il parsing
        // restituirà 0 file e OnDLLListComplete gestirà l'abort
        if frmMain.FDLLAbortRequested then
        begin
          FastDLLBuffer.Clear;
          Exit;
        end;
      end
      else
      begin
        // ALLOCAZIONE DINAMICA DELLA RAM
        if (Length(S) > 0) and (S[1] = '+') then
        begin
          ExpectedLines := StrToIntDef(Copy(S, 2, Length(S)), 0);
          if ExpectedLines > 0 then
            FastDLLBuffer.Capacity := ExpectedLines + 100;
        end;
        FastDLLBuffer.Add(S);
      end;
    end;
    Inc(P);
  end;

  if StartP < P then
  begin
    SetString(S, StartP, P - StartP);
    FastDLLPending := FastDLLPending + S;
  end;
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
      Caption := Format('Catpaq V1.0.0 build %d', [BuildNum]);
    end
    else
      Caption := 'Catpaq V1.0.0 build 0';
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
  FDLLAbortRequested := False;
  FArchiveBrowsePath := '';
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
  mnuSaveLog.Caption := 'Save log to file...';
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
  mnuLogClear.Caption := 'Clear log';
  mnuLogClear.OnClick := @mnuLogClearClick;
  pmLog.Items.Add(mnuLogClear);
  MemoLog.PopupMenu := pmLog;
  MemoLog.OnKeyDown := @MemoLogKeyDown;

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
    if lvAddFiles.Columns.Count >= 6 then
    begin
      lvAddFiles.Columns[0].Width := lvAddFiles.ClientWidth * 40 div 100;
      lvAddFiles.Columns[1].Width := lvAddFiles.ClientWidth * 12 div 100;
      lvAddFiles.Columns[2].Width := lvAddFiles.ClientWidth * 18 div 100;
      lvAddFiles.Columns[3].Width := lvAddFiles.ClientWidth * 18 div 100;
      lvAddFiles.Columns[4].Width := lvAddFiles.ClientWidth *  6 div 100;
      lvAddFiles.Columns[5].Width := lvAddFiles.ClientWidth *  6 div 100;
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
           IntToStr(lvAddFiles.ClientWidth) + ')');
    for I := 0 to Min(High(FSavedColWidthsLv), lvAddFiles.Columns.Count - 1) do
      if FSavedColWidthsLv[I] > 0 then
      begin
        lvAddFiles.Columns[I].Width := FSavedColWidthsLv[I] * lvAddFiles.ClientWidth div 1000;
        AddLog('  lista col[' + IntToStr(I) + '] ' + IntToStr(FSavedColWidthsLv[I]) +
               'o/oo → ' + IntToStr(lvAddFiles.Columns[I].Width) + 'px');
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
  for I := 0 to Min(High(FLastColWidthsLv),  lvAddFiles.Columns.Count - 1) do
    FLastColWidthsLv[I]  := lvAddFiles.Columns[I].Width;
  for I := 0 to Min(High(FLastColWidthsVst), VST.Header.Columns.Count - 1) do
    FLastColWidthsVst[I] := VST.Header.Columns[I].Width;

  AddLog('OnTimerRestore: snapshot iniziale L=' + IntToStr(Left) +
         ' T=' + IntToStr(Top) + ' W=' + IntToStr(Width) + ' H=' + IntToStr(Height));
  for I := 0 to lvAddFiles.Columns.Count - 1 do
    AddLog('  lista col[' + IntToStr(I) + ']=' + IntToStr(lvAddFiles.Columns[I].Width));

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
    for I := 0 to Min(High(FLastColWidthsLv), lvAddFiles.Columns.Count - 1) do
      if lvAddFiles.Columns[I].Width <> FLastColWidthsLv[I] then
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
    for I := 0 to Min(High(FLastColWidthsLv),  lvAddFiles.Columns.Count - 1) do
      FLastColWidthsLv[I]  := lvAddFiles.Columns[I].Width;
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

procedure TfrmMain.OnTimerStartup(Sender: TObject);
var
  StartupOK: Boolean;
begin
  FTimerStartup.Enabled := False;
  PageControl1.OnChange := nil;  // impedisce auto-caricamenti durante il cambio tab

  StartupOK := ExecuteStartupChecks;

  if FCommandLineFile <> '' then
  begin
    // Avviato con file da riga di comando → vai direttamente all'archivio
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
  {$IFDEF WINDOWS}
  DllFound: Boolean;
  DllPath: string;
  {$ENDIF}
begin
  Result := False; // pessimistico: True solo se tutto OK alla fine

  // I log vengono scritti senza cambiare tab: è OnTimerStartup che
  // sceglie il tab da mostrare in base al valore restituito.
  AddLog('--- System Startup Check ---');
  Application.ProcessMessages;

  ExeFound := False;

  // --- Determina i path attesi (platform-specific) ---
  {$IFDEF WINDOWS}
  ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';
  DllPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.dll';
  DllFound := False;
  {$ELSE}
  // macOS e Linux: solo l'eseguibile zpaqfranz è richiesto (niente DLL)
  ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz';
  {$ENDIF}

  // --- Controlla presenza fisica dei file ---
  ExeFound := FileExists(ExePath);
  AddLog('EXE present: ' + BoolToStr(ExeFound, 'YES', 'NO') + '  [' + ExePath + ']');

  {$IFDEF WINDOWS}
  DllFound := FileExists(DllPath);
  AddLog('DLL present: ' + BoolToStr(DllFound, 'YES', 'NO') + '  [' + DllPath + ']');

  // Su Windows ENTRAMBI i file sono obbligatori
  if not ExeFound or not DllFound then
  begin
    if not ExeFound and not DllFound then
    begin
      AddLog('WARNING: Both zpaqfranz.exe and zpaqfranz.dll are missing.');
      MessageDlg('Missing files',
        'Both zpaqfranz.exe and zpaqfranz.dll are missing.' + sLineBreak +
        'The application needs BOTH files to work.' + sLineBreak + sLineBreak +
        'Expected location: ' + ExtractFilePath(ParamStr(0)) + sLineBreak +
        'The application will try to download them.',
        mtWarning, [mbOK], 0);
    end
    else if not ExeFound then
    begin
      AddLog('WARNING: zpaqfranz.exe is missing.');
      MessageDlg('Missing file',
        'zpaqfranz.exe is missing.' + sLineBreak +
        'Both zpaqfranz.exe AND zpaqfranz.dll must be present.' + sLineBreak + sLineBreak +
        'Expected location: ' + ExePath + sLineBreak +
        'The application will try to download it.',
        mtWarning, [mbOK], 0);
    end
    else
    begin
      AddLog('WARNING: zpaqfranz.dll is missing.');
      MessageDlg('Missing file',
        'zpaqfranz.dll is missing.' + sLineBreak +
        'Both zpaqfranz.exe AND zpaqfranz.dll must be present.' + sLineBreak + sLineBreak +
        'Expected location: ' + DllPath + sLineBreak +
        'The application will try to download it.',
        mtWarning, [mbOK], 0);
    end;

    // Offri download automatico
    AddLog('Missing files. Offering download...');
    Application.ProcessMessages;

    if TryDownloadDLL then
    begin
      ExeFound := FileExists(ExePath);
      DllFound  := FileExists(DllPath);
      AddLog('After download - EXE: ' + BoolToStr(ExeFound, 'YES', 'NO') +
             '  DLL: ' + BoolToStr(DllFound, 'YES', 'NO'));

      if not ExeFound or not DllFound then
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
      if not ValidateDLL then
      begin
        AddLog('FATAL: Downloaded DLL validation failed.');
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
    if not ValidateDLL then
    begin
      AddLog('FATAL: DLL hash validation failed. Blocking open.');
      btnOpen.Enabled := False;
      Exit;
    end;
  end;

  // --- Windows: carica il bridge (richiede ENTRAMBI i file) ---
  if FBridge.LoadDLL then
  begin
    AddLog('Bridge loaded: ' + FBridge.DLLPath);
    btnOpen.Enabled := True;
    Result := True;
  end
  else
  begin
    AddLog('ERROR: Could not load bridge (zpaqfranz.dll). Open disabled.');
    AddLog('Make sure BOTH zpaqfranz.exe AND zpaqfranz.dll are in: ' +
           ExtractFilePath(ParamStr(0)));
    btnOpen.Enabled := False;
  end;

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

  // EXE trovato: carica il bridge (solo EXE, niente DLL)
  // NOTA: la validazione SHA256 di zpaqfranz è disabilitata su macOS/Linux
  // (l'utente procura l'eseguibile autonomamente per la propria piattaforma)
  if FBridge.LoadDLL then
  begin
    AddLog('Bridge loaded (EXE mode): ' + FBridge.DLLPath);
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

function TfrmMain.ValidateDLL: Boolean;
{$IFDEF WINDOWS}
var
  DLLPath, ActualHash: string;
{$ENDIF}
begin
  Result := True;

  {$IFDEF WINDOWS}
  // Su macOS/Linux non esiste la DLL: la validazione viene saltata
  // e l'unico controllo è ValidateEXE (zpaqfranz).

  // Modalità sviluppo: hash placeholder → skip
  if EXPECTED_DLL_HASH = '0000000000000000000000000000000000000000000000000000000000000000' then
  begin
    AddLog('DLL validation: SKIPPED (development mode)');
    Exit;
  end;

  DLLPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.dll';

  // File assente: non è compito di questo metodo segnalarlo
  if not FileExists(DLLPath) then Exit;

  AddLog('DLL validation: Computing SHA256...');
  ActualHash := SHA256File(DLLPath);

  if ActualHash = '' then
  begin
    AddLog('DLL validation: ERROR - Could not compute hash');
    Result := False;
    MessageDlg(S('dlg_dll_validation_error', 'Validation Error'),
      S('msg_dll_hash_compute_fail', 'Cannot compute hash of the DLL file.'),
      mtError, [mbOK], 0);
    Exit;
  end;

  AddLog('DLL Expected: ' + EXPECTED_DLL_HASH);
  AddLog('DLL Actual:   ' + ActualHash);

  if LowerCase(ActualHash) <> LowerCase(EXPECTED_DLL_HASH) then
  begin
    AddLog('DLL validation: FAILED - Hash mismatch!');
    Result := False;
    MessageDlg(S('dlg_dll_validation_error', 'Validation Error'),
      S('msg_dll_hash_mismatch', 'Security check failed for zpaqfranz.dll!' + sLineBreak +
        'The file does not match the expected version.' + sLineBreak +
        'The file may be corrupted or tampered with.'),
      mtError, [mbOK], 0);
  end
  else
    AddLog('DLL validation: PASSED');
  {$ELSE}
  AddLog('DLL validation: SKIPPED (not required on this platform)');
  {$ENDIF}
end;

function TfrmMain.TryDownloadDLL: Boolean;
{$IFDEF WINDOWS}
var
  Checker:          TUpdateChecker;
  UpdateInfo:       TUpdateInfo;
  ExeData, DllData: TBytes;
  ExeHash, DllHash: string;
  ExePath, DllPath: string;
  FS: TFileStream;
begin
  Result := False;
  AddLog('--- TryDownloadDLL: START ---');
  AddLog('App path: ' + ExtractFilePath(ParamStr(0)));

  if MessageDlg(S('dlg_dll_missing_title', 'Files Missing'),
    S('dlg_dll_missing_msg',
      'zpaqfranz.exe and zpaqfranz.dll are required but not found.' + sLineBreak +
      'Do you want to download both files now?'),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
  begin
    AddLog('TryDownloadDLL: user cancelled.');
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
        ShowMessage(S('dlg_dll_download_fail',
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
      ShowMessage(S('dlg_dll_download_fail',
        'Failed to download zpaqfranz.exe.') + sLineBreak +
        'Check the Log tab for details.');
      Exit;
    end;

    ExeHash := Checker.CalculateSHA256FromBytes_Public(ExeData);
    AddLog('EXE hash computed:  ' + ExeHash);
    AddLog('EXE hash expected:  ' + UpdateInfo.EXEInfo.SHA256Hash);
    if ExeHash <> UpdateInfo.EXEInfo.SHA256Hash then
    begin
      AddLog('TryDownloadDLL: EXE HASH MISMATCH');
      ShowMessage(S('dlg_dll_hash_fail', 'Security check failed on zpaqfranz.exe.'));
      Exit;
    end;

    // --- Scarica zpaqfranz.dll ---
    AddLog('Downloading zpaqfranz.dll (' +
           IntToStr(UpdateInfo.DLLInfo.FileSize div 1024) + ' KB)...');
    if not Checker.DownloadDLLFile(DllData) then
    begin
      ShowMessage(S('dlg_dll_download_fail',
        'Failed to download zpaqfranz.dll.') + sLineBreak +
        'Check the Log tab for details.');
      Exit;
    end;

    DllHash := Checker.CalculateSHA256FromBytes_Public(DllData);
    AddLog('DLL hash computed:  ' + DllHash);
    AddLog('DLL hash expected:  ' + UpdateInfo.DLLInfo.SHA256Hash);
    if DllHash <> UpdateInfo.DLLInfo.SHA256Hash then
    begin
      AddLog('TryDownloadDLL: DLL HASH MISMATCH');
      ShowMessage(S('dlg_dll_hash_fail', 'Security check failed on zpaqfranz.dll.'));
      Exit;
    end;

    // --- Salva entrambi su disco ---
    ExePath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.exe';
    DllPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.dll';

    try
      AddLog('Saving zpaqfranz.exe to ' + ExePath);
      FS := TFileStream.Create(ExePath, fmCreate);
      try
        if Length(ExeData) > 0 then FS.Write(ExeData[0], Length(ExeData));
      finally FS.Free; end;

      AddLog('Saving zpaqfranz.dll to ' + DllPath);
      FS := TFileStream.Create(DllPath, fmCreate);
      try
        if Length(DllData) > 0 then FS.Write(DllData[0], Length(DllData));
      finally FS.Free; end;

      AddLog('Both files saved successfully.');
      Result := True;
    except
      on E: Exception do
      begin
        AddLog('TryDownloadDLL: save FAILED - ' + E.ClassName + ': ' + E.Message);
        ShowMessage(S('dlg_dll_save_fail', 'Cannot save files. Check folder permissions.'));
      end;
    end;

  finally
    Checker.Free;
    AddLog('--- TryDownloadDLL: END result=' + BoolToStr(Result, 'TRUE', 'FALSE') + ' ---');
    pgrProgressLog.Position := 0;
    pgrProgressLog.Visible  := False;
    pgrProgresso.Position   := 0;
    pgrProgresso.Visible    := False;
  end;
end;
{$ELSE}
// Su macOS e Linux il download automatico non è disponibile.
// L'utente deve procurarsi zpaqfranz per la propria piattaforma manualmente.
begin
  Result := False;
  AddLog('TryDownloadDLL: automatic download not available on this platform.');
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
    for I := 0 to lvAddFiles.Columns.Count - 1 do
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
      if lvAddFiles.ClientWidth > 0 then
        for I := 0 to lvAddFiles.Columns.Count - 1 do
          Ini.WriteInteger('ListColumns', 'Width' + IntToStr(I),
            lvAddFiles.Columns[I].Width * 1000 div lvAddFiles.ClientWidth)
      else
        for I := 0 to lvAddFiles.Columns.Count - 1 do
          Ini.WriteInteger('ListColumns', 'Width' + IntToStr(I), lvAddFiles.Columns[I].Width);
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
    Dialog.SetDLLPath(FBridge.DLLPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then
      AddLog('Extraction destination: ' + Dialog.GetDestPath);
  finally
    Dialog.Free;
  end;
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
    Dialog.SetDLLPath(FBridge.DLLPath);
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
  // Blocca il cambio tab durante il caricamento: rimanda sempre alla TabLog
  if FLoadingArchive then
  begin
    PageControl1.ActivePage := TabLog;
    Exit;
  end;
  if PageControl1.ActivePage = TabAdd then RefreshAddFilesList;
end;

procedure TfrmMain.SetLoadingState(ALoading: Boolean);
begin
  pnlLogToolbar.Visible := ALoading;
  btnAbortLoad.Enabled  := ALoading;
  // Impedisce cambio tab: OnChange lo gestisce, ma disabilitare le tab dà
  // un feedback visivo immediato all'utente
  TabAdd.Enabled      := not ALoading;
  TabArchive.Enabled  := not ALoading;
  TabSettings.Enabled := not ALoading;
  if ALoading then
  begin
    lblLogStatus.Caption := 'Loading archive: ' + ExtractFileName(FArchivePath);
    PageControl1.ActivePage := TabLog;
  end;
end;

procedure TfrmMain.btnAbortLoadClick(Sender: TObject);
begin
  btnAbortLoad.Enabled := False;
  lblLogStatus.Caption := 'Aborting...';
  AddLog('*** ABORT requested by user ***');

  // Percorso EXE asincrono: termina il processo
  if FBridge.Busy then
    FBridge.AbortCommand;

  // Percorso DLL thread: setta il flag per il percorso pulito...
  FDLLAbortRequested := True;

  // ...e forza la terminazione immediata del thread DLL.
  // TerminateThread è brutale ma necessario: ZpaqRun non espone un meccanismo
  // di cancellazione, e tra un $$$NULL-W e l'altro possono passare molti secondi.
  // NB: TerminateThread bypassa il blocco finally in Execute, quindi
  // dobbiamo accodar manualmente OnDLLListComplete per ripristinare la UI.
  {$IFDEF WINDOWS}
  if Assigned(FastDLLThread) and not FastDLLThread.Finished then
  begin
    Windows.TerminateThread(FastDLLThread.ThreadHandle, 1);
    Application.QueueAsyncCall(@OnDLLListComplete, 0);
  end;
  {$ENDIF}
end;

{ Aggiorna la progress bar dalla GUI — chiamato nel thread principale via QueueAsyncCall. }
procedure TfrmMain.DLLGuiUpdate(Data: PtrInt);
var Pct: Integer;
begin
  Pct := Integer(Data);
  pgrProgressLog.Max := 100;
  pgrProgressLog.Position := Pct;
  // Workaround animazione Aero
  if Pct < pgrProgressLog.Max then
  begin
    pgrProgressLog.Position := Pct + 1;
    pgrProgressLog.Position := Pct;
  end;
  lblLoadInfo.Caption := 'Lettura archivio: ' + IntToStr(Pct) + '%';
end;

{ Chiamato dal thread principale via QueueAsyncCall quando TDLLListThread termina. }
procedure TfrmMain.OnDLLListComplete(Data: PtrInt);
var
  ElapsedSecs: Double;
  WasAborted: Boolean;
begin
  // Attendi che il thread sia davvero terminato e liberalo
  if Assigned(FastDLLThread) then
  begin
    FastDLLThread.WaitFor;
    FreeAndNil(FastDLLThread);
  end;

  // Libera la DLL
  if FastDLLhDLL <> NilHandle then
  begin
    FreeLibrary(FastDLLhDLL);
    FastDLLhDLL := NilHandle;
  end;

  WasAborted := FDLLAbortRequested;

  // Guard: può arrivare sia da TerminateThread (manuale) che da Execute (normale).
  // La seconda chiamata trova FastDLLhDLL già = NilHandle → esce subito.
  if (FastDLLhDLL = NilHandle) and not WasAborted and not Assigned(FastDLLBuffer) then
    Exit;

  if WasAborted then
  begin
    AddLog('*** Loading ABORTED by user ***');
    FreeAndNil(FastDLLBuffer);
    pgrProgresso.Position   := 0;
    pgrProgressLog.Position := 0;
    btnOpen.Enabled := True;
    FLoadingArchive := False;
    FLogProgressLineIndex := -1;
    SetLoadingState(False);
    Exit;
  end;

  // Parsing dei dati raccolti dal thread
  try
    if Assigned(FastDLLBuffer) then
      FArchiveData := FBridge.ParsePakkaList(FastDLLBuffer);
  finally
    FreeAndNil(FastDLLBuffer);
  end;

  AddLog('Found ' + IntToStr(Length(FArchiveData.GlobalVersions)) +
         ' versions, ' + IntToStr(Length(FArchiveData.Files)) + ' files');
  SetupTrackBar;
  BuildFilteredList;
  RebuildTree;

  lblArchiveInfo.Caption  := ExtractFileName(FArchivePath);
  pgrProgresso.Position   := 0;
  pgrProgressLog.Position := 0;

  ElapsedSecs := (Now - FLoadStartTime) * 86400.0;
  lblLoadInfo.Caption := Format(S('lbl_loaded_fmt', '%d files loaded in %.3f s'),
                                [Length(FArchiveData.Files), ElapsedSecs]);
  btnOpen.Enabled := True;

  FLoadingArchive := False;
  FLogProgressLineIndex := -1;
  SetLoadingState(False);

  if (FArchiveBrowsePath <> '') and
     (Length(FArchiveData.GlobalVersions) < 2) and
     (Length(FArchiveData.Files) > 0) then
    ShowArchiveBrowse(FArchiveBrowsePath, FArchiveData)
  else
  begin
    FArchiveBrowsePath := '';
    PageControl1.ActivePage := TabArchive;
  end;
end;

procedure TfrmMain.PanelBottomResize(Sender: TObject);
begin
  btnTimeMachine.Width := tpanel(sender).width- btnTimeMachine.Left - 4;
  edtaddpath.width:=pnladdnav.width-edtaddpath.left-4;
  btnexit2.left:=pnladdtoolbar.width-btnexit2.width-4;
end;

{ === Archive loading === }

procedure TfrmMain.btnOpenClick(Sender: TObject);
begin
  if FBridge.Busy then begin ShowMessage(S('msg_busy', 'Operation in progress, please wait.')); Exit; end;
  if OpenDialog1.Execute then DoLoadArchive(OpenDialog1.FileName);
end;

procedure TfrmMain.btnExit2Click(Sender: TObject);
begin
  close;
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
  Result := 'pakka "' + FArchivePath + '" -all';
  if FPasswordKey <> '' then Result := Result + ' -key "' + FPasswordKey + '"';
  if FPasswordFranzen <> '' then Result := Result + ' -franzen "' + FPasswordFranzen + '"';
end;

procedure TfrmMain.RunPakkaList;
var
  {$IFDEF WINDOWS}
  DLLPath: string;
  hDLL: TLibHandle;
  ZpaqRun:    TZpaqRunCommand;
  ZpaqSetOut: procedure(cb: TOutputCallback); cdecl;
  ZpaqReset:  TZpaqResetProc;
  {$ENDIF}
  ElapsedSecs: Double;
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

  {$IFDEF WINDOWS}
  // === WINDOWS: prima prova la DLL (listing in thread separato), poi fallback EXE ===
  lblLoadInfo.Caption := S('lbl_loading', 'Loading fast via DLL...');
  Application.ProcessMessages;

  DLLPath := ExtractFilePath(ParamStr(0)) + 'zpaqfranz.dll';

  AddLog('Attempting fast pakka list (Direct DLL)...');

  hDLL := LoadLibrary(pchar(DLLPath));
  if hDLL <> NilHandle then
  begin
    Pointer(ZpaqRun) := GetProcAddress(hDLL, 'Zpaq_RunCommand');
    Pointer(ZpaqSetOut) := GetProcAddress(hDLL, 'Zpaq_SetOutputCallback');
    Pointer(ZpaqReset) := GetProcAddress(hDLL, 'Zpaq_ResetCallbacks');

    if Assigned(ZpaqRun) and Assigned(ZpaqSetOut) then
    begin
      FastDLLBuffer  := TStringList.Create;
      FastDLLPending := '';
      FastDLLDone    := False;
      FastDLLhDLL    := hDLL;  // il thread libererà la DLL via OnDLLListComplete

      pgrProgresso.Max := 100;
      pgrProgresso.Position := 0;

      ZpaqSetOut(@FastDLLOutputCallback);

      // Avvia il thread: ZpaqRun gira in background, il thread principale è libero
      FastDLLThread := TDLLListThread.Create(
        AnsiString(BuildCommandString), ZpaqRun, ZpaqReset);
      FastDLLThread.Start;

      // Ritorna subito: OnDLLListComplete (via QueueAsyncCall) completerà il lavoro
      Exit;
    end
    else
    begin
      AddLog('WARNING: DLL functions not found. Falling back to EXE...');
      FreeLibrary(hDLL);
      FastDLLhDLL := NilHandle;
    end;
  end
  else AddLog('WARNING: DLL not found. Falling back to EXE async...');

  {$ELSE}
  // === macOS / Linux: usa direttamente l'EXE (niente DLL) ===
  lblLoadInfo.Caption := S('lbl_loading', 'Loading via zpaqfranz...');
  Application.ProcessMessages;
  AddLog('Running pakka list via Executable (platform mode)...');
  {$ENDIF}

  // --- Percorso comune: listing asincrono tramite EXE ---
  FBridge.IsDataMode := True;
  TimerUpdate.Enabled := True;
  AddLog('Running pakka list via Executable...');
  if not FBridge.RunCommandAsync(BuildCommandString) then
  begin
    AddLog('ERROR: Failed to start command');
    btnOpen.Enabled := True;
    TimerUpdate.Enabled := False;
    lblLoadInfo.Caption := '';
    FLoadingArchive := False;
    FLogProgressLineIndex := -1;
    SetLoadingState(False);
  end;
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

  AddLog('Found ' + IntToStr(Length(FArchiveData.GlobalVersions)) + ' versions, ' + IntToStr(Length(FArchiveData.Files)) + ' files');
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

  // Decisione post-caricamento: se stiamo arrivando dal file selector (DblClick)
  // e l'archivio ha meno di 2 versioni (include il caso 0 = formato streaming/bug
  // di parsing dove la versione implicita non viene contata) → browse mode.
  // Con 2+ versioni → tab archivio come sempre.
  if (FArchiveBrowsePath <> '') and
     (Length(FArchiveData.GlobalVersions) < 2) and
     (Length(FArchiveData.Files) > 0) then
  begin
    ShowArchiveBrowse(FArchiveBrowsePath, FArchiveData);
    { FArchiveBrowsePath NON azzerato: serve al popup Test/Extract in browse mode }
  end
  else
  begin
    FArchiveBrowsePath := '';
    // (1) Torna a Browse se versione singola, altrimenti Versions (TabArchive)
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
  NewCatpaqPath, NewEXEPath, NewDLLPath, Msg, VerStr: string;
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
      'zpaqfranz.dll: %s (%s)' + LineEnding + LineEnding +
      S('msg_update_now', 'Do you want to update now?'),
      [CurrentBuild, UpdateInfo.CatpaqInfo.BuildNumber,
       FormatFileSize(UpdateInfo.CatpaqInfo.FileSize), UpdateInfo.CatpaqInfo.DateTime,
       FormatFileSize(UpdateInfo.EXEInfo.FileSize), UpdateInfo.EXEInfo.DateTime,
       FormatFileSize(UpdateInfo.DLLInfo.FileSize), UpdateInfo.DLLInfo.DateTime]);
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
    if not Checker.DownloadUpdate(UpdateInfo, NewCatpaqPath, NewEXEPath, NewDLLPath) then
    begin
      MessageDlg(S('dlg_download_error', 'Download Error'),
        S('msg_download_fail', 'Failed to download or verify update files.') + sLineBreak + sLineBreak +
        'Details in the Log tab.',
        mtError, [mbOK], 0);
      Exit;
    end;

    // --- Apply ---
    Application.ProcessMessages;
    if not Checker.ApplyUpdate(NewCatpaqPath, NewEXEPath, NewDLLPath) then
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
  if Assigned(mnuSaveLog) then mnuSaveLog.Caption := S('log_save', 'Save log to file...');
  if Assigned(mnuLogBack)  then mnuLogBack.Caption  := S('log_back',  '<= Back to Browse');
  if Assigned(mnuLogClear) then mnuLogClear.Caption := S('log_clear', 'Clear log');

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
  mnuAddHash.Caption            := S('mnu_add_hash',               'Hash');
  mnuAddTestZpaq.Caption        := S('mnu_add_test',               'Test');
  mnuAddTestAllZpaq.Caption     := S('mnu_add_test_all',           'Test all');

  // --- Archive browse popup + Test popup ------------------------------------
  itmLastversion.Caption        := S('itm_last_version',    'Last version');
  itmAll.Caption                := S('itm_all_versions',    'All versions');
  mnuArchiveBack.Caption        := S('mnu_archive_back',    '← Back to filesystem');
  mnuArchiveExtract1.Caption    := S('mnu_archive_extract', 'Extract...');
  mnuArchiveExtract2.Caption    := S('mnu_archive_test',    'Test');

  if VST.Header.Columns.Count >= 5 then
  begin
    VST.Header.Columns[0].Text := S('col_filename', 'File Name');
    VST.Header.Columns[1].Text := S('col_version', 'Version');
    VST.Header.Columns[2].Text := S('col_date', 'Date');
    VST.Header.Columns[3].Text := S('col_time', 'Time');
    VST.Header.Columns[4].Text := S('col_size', 'Size');
  end;

  if lvAddFiles.Columns.Count >= 6 then
  begin
    lvAddFiles.Columns[0].Caption := S('col_name', 'Name');
    lvAddFiles.Columns[1].Caption := S('col_size', 'Size');
    lvAddFiles.Columns[2].Caption := S('col_modified', 'Modified');
    lvAddFiles.Columns[3].Caption := S('col_created', 'Created');
    lvAddFiles.Columns[4].Caption := S('col_attributes', 'Attributes');
    lvAddFiles.Columns[5].Caption := S('col_extension', 'Ext');
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
var SR: TSearchRec; Item: TListItem; Count: Integer; FileItem: TFileExplorerItem; AttrStr: string;
begin
  // Assicura sfondo bianco quando si mostra il filesystem
  lvAddFiles.Color := clWindow;
  lvAddFiles.Items.BeginUpdate;
  try
    lvAddFiles.Items.Clear; SetLength(FAddFilesList, 0); Count := 0;
    {$IFDEF WINDOWS} if Length(FCurrentAddPath) > 3 then {$ELSE} if FCurrentAddPath <> '/' then {$ENDIF}
    begin
      Item := lvAddFiles.Items.Add; Item.Caption := '..'; Item.SubItems.Add(''); Item.SubItems.Add(''); Item.SubItems.Add(''); Item.SubItems.Add('<DIR>'); Item.SubItems.Add('');
      SetLength(FAddFilesList, Count + 1); FAddFilesList[Count].Name := '..'; FAddFilesList[Count].FullPath := ExtractFilePath(ExcludeTrailingPathDelimiter(FCurrentAddPath)); FAddFilesList[Count].IsDirectory := True; FAddFilesList[Count].Size := -1; Inc(Count);
    end;
    if FindFirst(FCurrentAddPath + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          SetLength(FAddFilesList, Count + 1);
          FileItem.Name := SR.Name + '/'; FileItem.FullPath := FCurrentAddPath + SR.Name; FileItem.IsDirectory := True; FileItem.Size := -1; FileItem.Modified := FileDateToDateTime(SR.Time); FileItem.Created := FileItem.Modified; FileItem.Attributes := SR.Attr; FAddFilesList[Count] := FileItem;
          Item := lvAddFiles.Items.Add; Item.Caption := SR.Name + '/'; Item.SubItems.Add(''); Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', FileItem.Modified)); Item.SubItems.Add('');
          AttrStr := '<DIR>'; if (SR.Attr and faReadOnly) <> 0 then AttrStr := AttrStr + 'R'; if (SR.Attr and faHidden) <> 0 then AttrStr := AttrStr + 'H'; if (SR.Attr and faSysFile) <> 0 then AttrStr := AttrStr + 'S'; Item.SubItems.Add(AttrStr); Item.SubItems.Add(''); Inc(Count);
        end;
      until FindNext(SR) <> 0; SysUtils.FindClose(SR);
    end;
    if FindFirst(FCurrentAddPath + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) = 0 then
        begin
          SetLength(FAddFilesList, Count + 1);
          FileItem.Name := SR.Name; FileItem.FullPath := FCurrentAddPath + SR.Name; FileItem.IsDirectory := False; FileItem.Size := SR.Size; FileItem.Modified := FileDateToDateTime(SR.Time); FileItem.Created := FileItem.Modified; FileItem.Attributes := SR.Attr; FAddFilesList[Count] := FileItem;
          Item := lvAddFiles.Items.Add; Item.Caption := SR.Name; Item.SubItems.Add(FormatFileSize(SR.Size)); Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', FileItem.Modified)); Item.SubItems.Add('');
          AttrStr := ''; if (SR.Attr and faReadOnly) <> 0 then AttrStr := AttrStr + 'R'; if (SR.Attr and faHidden) <> 0 then AttrStr := AttrStr + 'H'; if (SR.Attr and faSysFile) <> 0 then AttrStr := AttrStr + 'S'; if (SR.Attr and faArchive) <> 0 then AttrStr := AttrStr + 'A'; Item.SubItems.Add(AttrStr); Item.SubItems.Add(LowerCase(ExtractFileExt(SR.Name))); Inc(Count);
        end;
      until FindNext(SR) <> 0; SysUtils.FindClose(SR);
    end;
  finally lvAddFiles.Items.EndUpdate; end;
  FLvSortColumn := -1;
  FLvSortAscending := True;
  AddLog(Format('Loaded %d items from %s', [Count, FCurrentAddPath]));
  UpdateZpaqButtons;
end;

{ === Archive Browse Mode === }

// Popola lvAddFiles confile dell'archivio (una sola versione).
// Sostituisce temporaneamente la vista filesystem con i contenuti dell'archivio.
procedure TfrmMain.ShowArchiveBrowse(const AArchivePath: string; const AData: TArchiveData);
var
  I: Integer;
  Item: TListItem;
  FE: TArchiveFileEntry;
  FV: TFileVersion;
  DisplayName: string;
begin
  FArchiveBrowseMode := True;
  FArchiveBrowsePath := AArchivePath;

  // Sfondo grigino per indicare modalità archivio
  lvAddFiles.Color := $00F0F0F0;

  // Cambia il popup menu del listview
  lvAddFiles.PopupMenu := PopupMenuArchiveBrowse;

  // Aggiorna la label del path per indicare che siamo dentro un archivio
  edtAddPath.Text := '[ARCHIVE] ' + AArchivePath;
  lblAddPath.Caption := 'Archive: ' + ExtractFileName(AArchivePath);

  lvAddFiles.Items.BeginUpdate;
  try
    lvAddFiles.Items.Clear;

    // Prima riga: ".." per tornare al filesystem
    Item := lvAddFiles.Items.Add;
    Item.Caption := '..';
    Item.SubItems.Add('');
    Item.SubItems.Add('');
    Item.SubItems.Add('');
    Item.SubItems.Add('<UP>');
    Item.SubItems.Add('');

    // File dell'archivio (prende l'ultima/unica versione di ogni file)
    for I := 0 to High(AData.Files) do
    begin
      FE := AData.Files[I];
      if Length(FE.Versions) = 0 then Continue;
      FV := FE.Versions[High(FE.Versions)];
      if FV.IsDeleted then Continue;  // non mostrare file cancellati

      // Mostra solo il nome del file (non il path completo)
      DisplayName := ExtractFileName(ExcludeTrailingPathDelimiter(FE.FileName));
      if DisplayName = '' then DisplayName := FE.FileName;

      Item := lvAddFiles.Items.Add;
      Item.Caption := DisplayName;
      Item.SubItems.Add(FormatFileSize(FV.Size));
      Item.SubItems.Add(FV.DateStr);
      Item.SubItems.Add('');
      Item.SubItems.Add('');
      Item.SubItems.Add(LowerCase(ExtractFileExt(DisplayName)));
      // Salviamo il path completo nel Data del ListItem non disponibile direttamente,
      // usiamo FAddFilesList per accesso rapido
    end;
  finally
    lvAddFiles.Items.EndUpdate;
  end;

  // Rimani sulla tab Add (non cambiare tab)
  PageControl1.ActivePage := TabAdd;

  AddLog(Format('Archive browse mode: %d files in %s',
    [lvAddFiles.Items.Count - 1, ExtractFileName(AArchivePath)]));

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
begin
  // Per ora tutte le voci sono sempre abilitate
  mnuArchiveExtract1.Enabled := (lvAddFiles.SelCount > 0) and
    ((lvAddFiles.Selected = nil) or (lvAddFiles.Selected.Caption <> '..'));
  mnuArchiveExtract2.Enabled := mnuArchiveExtract1.Enabled;
end;

procedure TfrmMain.mnuArchiveBackClick(Sender: TObject);
begin
  ExitArchiveBrowseMode;
end;

procedure TfrmMain.mnuArchiveExtract1Click(Sender: TObject);
var
  Dialog: TfrmExtract;
  SelName, SelFullPath: string;
  I: Integer;
begin
  { Siamo in archive browse mode: FArchiveBrowsePath = archivio corrente.
    Se c'è un file selezionato (non "..") lo estraiamo singolarmente,
    altrimenti estraiamo tutto. }
  SelName := '';
  if (lvAddFiles.SelCount = 1) and (lvAddFiles.Selected <> nil) and
     (lvAddFiles.Selected.Caption <> '..') then
    SelName := lvAddFiles.Selected.Caption;

  Dialog := TfrmExtract.Create(Self);
  try
    if SelName <> '' then
    begin
      { Cerchiamo il path completo nell'archivio data }
      SelFullPath := SelName;
      for I := 0 to High(FArchiveData.Files) do
        if SameText(ExtractFileName(ExcludeTrailingPathDelimiter(
             FArchiveData.Files[I].FileName)), SelName) then
        begin
          SelFullPath := FArchiveData.Files[I].FileName;
          Break;
        end;
      Dialog.SetExtractionParams(FArchiveBrowsePath, SelFullPath, -1,
                                  FPasswordKey, FPasswordFranzen);
    end
    else
      Dialog.SetExtractionParamsAll(FArchiveBrowsePath, FPasswordKey, FPasswordFranzen);
    Dialog.SetDLLPath(FBridge.DLLPath);
    Dialog.ShowModal;
    if Dialog.GetDestPath <> '' then
      AddLog('Archive browse extraction destination: ' + Dialog.GetDestPath);
  finally
    Dialog.Free;
  end;
end;

procedure TfrmMain.mnuArchiveExtract2Click(Sender: TObject);
begin
  ShowTestDialog(GetSelectedZpaqPath);
end;

procedure TfrmMain.ApplyAddFilter(const AFilter: string);
var I: Integer; SearchText, ItemName, ItemNameNoSlash: string; ExactMatch, Match, CaseSensitive: Boolean; MatchCount: Integer; Item: TListItem;
begin
  if Trim(AFilter) = '' then begin lvAddFiles.ClearSelection; Exit; end;
  ExactMatch := False; SearchText := Trim(AFilter); CaseSensitive := IsCaseSensitiveFS;
  if (Length(SearchText) > 0) and (SearchText[1] = '=') then begin ExactMatch := True; SearchText := Copy(SearchText, 2, Length(SearchText)); end;
  MatchCount := 0; lvAddFiles.ClearSelection;
  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    Item := lvAddFiles.Items[I]; ItemName := Item.Caption; if ItemName = '..' then Continue;
    ItemNameNoSlash := ItemName; if (Length(ItemNameNoSlash) > 0) and (ItemNameNoSlash[Length(ItemNameNoSlash)] = '/') then ItemNameNoSlash := Copy(ItemNameNoSlash, 1, Length(ItemNameNoSlash) - 1);
    if ExactMatch then begin if CaseSensitive then Match := (ItemNameNoSlash = SearchText) else Match := (LowerCase(ItemNameNoSlash) = LowerCase(SearchText)); end
    else begin if CaseSensitive then Match := (Pos(SearchText, ItemNameNoSlash) > 0) else Match := (Pos(LowerCase(SearchText), LowerCase(ItemNameNoSlash)) > 0); end;
    if Match then begin Item.Selected := True; Inc(MatchCount); if MatchCount = 1 then Item.Focused := True; end;
  end;
  lvAddFiles.Invalidate; if lvAddFiles.CanFocus then lvAddFiles.SetFocus;
  AddLog(Format('Filter "%s": %d item(s) selected', [AFilter, MatchCount]));
end;

function TfrmMain.BuildSelectedFilesString: string;
var I: Integer; FilePath: string;
begin
  Result := '';
  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    if lvAddFiles.Items[I].Selected then
    begin
      if lvAddFiles.Items[I].Caption = '..' then Continue;
      FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
      if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
      if Result <> '' then Result := Result + ' ';
      Result := Result + '"' + FilePath + '"';
    end;
  end;
end;

function TfrmMain.BuildAllFilesString: string;
var I: Integer; FilePath: string;
begin
  Result := '';
  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    if lvAddFiles.Items[I].Caption = '..' then Continue;
    FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
    if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
    if Result <> '' then Result := Result + ' ';
    Result := Result + '"' + FilePath + '"';
  end;
end;

function TfrmMain.HasOnlyFoldersSelected: Boolean;
var I: Integer; HasSelection: Boolean;
begin
  Result := True; HasSelection := False;
  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    if lvAddFiles.Items[I].Selected then
    begin
      if lvAddFiles.Items[I].Caption = '..' then Continue;
      HasSelection := True;
      if not ((Length(lvAddFiles.Items[I].Caption) > 0) and (lvAddFiles.Items[I].Caption[Length(lvAddFiles.Items[I].Caption)] = '/')) then begin Result := False; Exit; end;
    end;
  end;
  if not HasSelection then Result := False;
end;

procedure TfrmMain.OpenSelectedFile;
var I: Integer; FilePath, FileExt: string;
begin
  // (2) Congela il doppio click se un caricamento archivio è già in corso
  if FLoadingArchive then Exit;

  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    if lvAddFiles.Items[I].Selected then
    begin
      if lvAddFiles.Items[I].Caption = '..' then
      begin
        // In archive browse mode ".." torna al filesystem,
        // altrimenti sale di directory come prima
        if FArchiveBrowseMode then
          ExitArchiveBrowseMode
        else
          btnAddUpClick(nil);
        Exit;
      end;
      if FArchiveBrowseMode then
      begin
        // In browse mode ignora il doppio click se già in caricamento
        if FLoadingArchive then Exit;
        AddLog('Archive browse: selected "' + lvAddFiles.Items[I].Caption + '"');
        Exit;
      end;
      if (I < Length(FAddFilesList)) and FAddFilesList[I].IsDirectory then
      begin
        NavigateToPath(FAddFilesList[I].FullPath);
        Exit;
      end
      else
      begin
        FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
        FileExt  := LowerCase(ExtractFileExt(FilePath));
        // Apri zpaq solo per .zpaq o .zpaq.franzen
        if (FileExt = '.zpaq') or (Pos('.zpaq.franzen', LowerCase(FilePath)) > 0) then
        begin
          OpenZpaqFile(FilePath);
          Exit;
        end;
        // Tutti gli altri file: apri con l'applicazione predefinita del sistema
        {$IFDEF WINDOWS}
        ShellExecute(0, 'open', PChar(FilePath), nil, nil, SW_SHOWNORMAL);
        {$ELSE}
        OpenDocument(FilePath);
        {$ENDIF}
        Exit;
      end;
    end;
  end;
end;

procedure TfrmMain.OpenZpaqFile(const AFilePath: string);
begin
  FLoadingArchive    := True;
  FLogProgressLineIndex := -1;
  FDLLAbortRequested := False;
  FArchiveBrowsePath := AFilePath;
  SetLoadingState(True);
  DoLoadArchive(AFilePath);
  // NON cambiamo tab qui: OnBridgeComplete decide in base al conteggio versioni
end;

procedure TfrmMain.OpenInExplorer;
var I: Integer; FilePath: string;
begin
  for I := 0 to lvAddFiles.Items.Count - 1 do
  begin
    if lvAddFiles.Items[I].Selected then
    begin
      if lvAddFiles.Items[I].Caption = '..' then FilePath := ExtractFilePath(ExcludeTrailingPathDelimiter(FCurrentAddPath))
      else if (I < Length(FAddFilesList)) and FAddFilesList[I].IsDirectory then FilePath := FAddFilesList[I].FullPath
      else FilePath := FCurrentAddPath;
      {$IFDEF WINDOWS} ShellExecute(0, 'explore', PChar(FilePath), nil, nil, SW_SHOWNORMAL); {$ELSE} OpenDocument(FilePath); {$ENDIF}
      Exit;
    end;
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

procedure TfrmMain.lvAddFilesColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column = nil then Exit;
  if FLvSortColumn = Column.Index then
    FLvSortAscending := not FLvSortAscending
  else
  begin
    FLvSortColumn := Column.Index;
    FLvSortAscending := True;
  end;
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

procedure TfrmMain.lvAddFilesAdvancedCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
var
  ItemName, LowerName: string;
  IsZpaq, IsFolder: Boolean;
  FgColor, BgColor: TColor;
  IsSelected: Boolean;
  R: TRect;
  I, ColX, ColW: Integer;
  ColText: string;
  LV: TListView;
begin
  if Item = nil then Exit;
  ItemName  := Item.Caption;
  LowerName := LowerCase(ItemName);
  IsFolder  := ((Length(ItemName) > 0) and (ItemName[Length(ItemName)] = '/'))
               or (ItemName = '..');
  IsZpaq    := (not IsFolder) and
               ( (ExtractFileExt(LowerName) = '.zpaq') or
                 (Copy(LowerName, Length(LowerName) - 12, 13) = '.zpaq.franzen') );
  // File normale: lascia disegnare al sistema, resetta colori
  if (not IsFolder) and (not IsZpaq) then
  begin
    DefaultDraw := True;
    if Stage = cdPrePaint then
    begin
      Sender.Canvas.Font.Color := clWindowText;
      Sender.Canvas.Font.Style := [];
    end;
    Exit;
  end;
  if Stage <> cdPrePaint then begin DefaultDraw := False; Exit; end;
  DefaultDraw := False;
  LV         := Sender as TListView;
  IsSelected := cdsSelected in State;
  // Eredita font del listview (nome + dimensione) per coerenza visiva
  Sender.Canvas.Font.Assign(LV.Font);
  if IsFolder then begin FgColor := $00007000; Sender.Canvas.Font.Style := [fsBold]; end
  else             begin FgColor := clRed;      Sender.Canvas.Font.Style := [fsBold]; end;
  if IsSelected then begin BgColor := clHighlight; FgColor := clHighlightText; end
  else BgColor := Sender.Color;
  R := Item.DisplayRect(drBounds);
  Sender.Canvas.Brush.Color := BgColor;
  Sender.Canvas.FillRect(R);
  Sender.Canvas.Font.Color := FgColor;
  // Colonna 0
  ColX := R.Left + 2;
  if LV.Columns.Count > 0 then ColW := LV.Columns[0].Width
  else ColW := R.Right - R.Left;
  Sender.Canvas.TextOut(ColX, R.Top + 2, ItemName);
  // Colonne successive (SubItems)
  ColX := R.Left + ColW;
  for I := 0 to Item.SubItems.Count - 1 do
  begin
    if I + 1 < LV.Columns.Count then ColW := LV.Columns[I + 1].Width
    else ColW := 80;
    ColText := Item.SubItems[I];
    if ColText <> '' then
      Sender.Canvas.TextOut(ColX + 2, R.Top + 2, ColText);
    ColX := ColX + ColW;
  end;
end;

function TfrmMain.IsZpaqFile(const AFileName: string): Boolean;
var LN: string;
begin
  LN := LowerCase(AFileName);
  Result := (Pos('.zpaq', LN) > 0);
end;

{ Restituisce il path dell'archivio .zpaq su cui operare.
  - In archive browse mode: è l'archivio correntemente aperto (FArchiveBrowsePath).
  - In filesystem normale: è il file .zpaq selezionato nel listview. }
function TfrmMain.GetSelectedZpaqPath: string;
var FilePath: string;
begin
  Result := '';
  if FArchiveBrowseMode then
  begin
    Result := FArchiveBrowsePath;
    Exit;
  end;
  if (lvAddFiles.SelCount <> 1) or (lvAddFiles.Selected = nil) then Exit;
  if lvAddFiles.Selected.Caption = '..' then Exit;
  FilePath := FCurrentAddPath + lvAddFiles.Selected.Caption;
  if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = PathDelim) then
    FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
  if Pos('.zpaq', LowerCase(FilePath)) > 0 then
    Result := FilePath;
end;

procedure TfrmMain.UpdateZpaqButtons;
var SelZpaq: Boolean; LN: string;
begin
  if FArchiveBrowseMode then
  begin
    { Dentro un archivio: Add nascosto, Extract e Test sempre visibili }
    btnAddAdd.Visible     := False;
    btnAddExtract.Visible := True;
    btnAddTest.Visible    := True;
  end
  else
  begin
    { Filesystem normale: Add sempre visibile.
      Extract e Test compaiono IN AGGIUNTA se è selezionato un .zpaq,
      ma Add non sparisce mai. }
    SelZpaq := False;
    if (lvAddFiles.SelCount = 1) and (lvAddFiles.Selected <> nil) then
    begin
      LN := LowerCase(lvAddFiles.Selected.Caption);
      SelZpaq := (Pos('.zpaq', LN) > 0);
    end;
    btnAddAdd.Visible     := True;
    btnAddExtract.Visible := SelZpaq;
    btnAddTest.Visible    := SelZpaq;
  end;
end;

procedure TfrmMain.lvAddFilesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  UpdateZpaqButtons;
end;

procedure TfrmMain.PopupMenuAddPopup(Sender: TObject);
var HasSelection, OnlyFolders, SelZpaq: Boolean; LN: string;
begin
  HasSelection := lvAddFiles.SelCount > 0; OnlyFolders := HasOnlyFoldersSelected;
  if HasSelection then begin if OnlyFolders then mnuAddFilesToZpaq.Caption := S('mnu_add_folders_to_zpaq', 'Add folders to ZPAQ...') else mnuAddFilesToZpaq.Caption := S('mnu_add_files_to_zpaq', 'Add files to ZPAQ...'); end
  else mnuAddFilesToZpaq.Caption := S('mnu_add_files_to_zpaq', 'Add files to ZPAQ...');
  mnuAddFilesToZpaq.Enabled := HasSelection; mnuAddOpen.Enabled := HasSelection; mnuAddOpenInExplorer.Enabled := True;
  SelZpaq := False;
  if (lvAddFiles.SelCount = 1) and (lvAddFiles.Selected <> nil) then begin LN := LowerCase(lvAddFiles.Selected.Caption); SelZpaq := (Pos('.zpaq', LN) > 0); end;
  mnuAddExtractToFolder.Enabled := SelZpaq; mnuAddExtractToFolder.Visible := True;
  mnuAddTestZpaq.Enabled := SelZpaq; mnuAddTestZpaq.Visible := True;
  mnuAddTestAllZpaq.Enabled := SelZpaq; mnuAddTestAllZpaq.Visible := True;
  mnuAddRename.Enabled := (lvAddFiles.SelCount = 1) and (lvAddFiles.Selected <> nil) and (lvAddFiles.Selected.Caption <> '..');
  mnuAddDelete.Enabled := HasSelection and not ((lvAddFiles.SelCount = 1) and (lvAddFiles.Selected <> nil) and (lvAddFiles.Selected.Caption = '..'));
  mnuAddProperties.Enabled := HasSelection;
  mnuAddHash.Enabled       := HasSelection and not FArchiveBrowseMode;
end;

procedure TfrmMain.mnuAddFilesToZpaqClick(Sender: TObject);
var FilesList: TStringList; I: Integer; FilePath: string;
begin
  FilesList := TStringList.Create;
  try
    for I := 0 to lvAddFiles.Items.Count - 1 do
      if lvAddFiles.Items[I].Selected then begin
        if lvAddFiles.Items[I].Caption = '..' then Continue;
        FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
        if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
        FilesList.Add(FilePath);
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
    for I := 0 to lvAddFiles.Items.Count - 1 do begin
      if lvAddFiles.Items[I].Caption = '..' then Continue;
      FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
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
var OldName, NewName, OldPath, NewPath: string;
begin
  if lvAddFiles.Selected = nil then Exit; if lvAddFiles.Selected.Caption = '..' then Exit;
  OldName := lvAddFiles.Selected.Caption;
  if (Length(OldName) > 0) and (OldName[Length(OldName)] = '/') then OldName := Copy(OldName, 1, Length(OldName) - 1);
  NewName := InputBox(S('dlg_rename_title', 'Rename'), S('dlg_rename_prompt', 'Enter new name:'), OldName);
  if (NewName <> '') and (NewName <> OldName) then begin
    OldPath := FCurrentAddPath + OldName; NewPath := FCurrentAddPath + NewName;
    if RenameFile(OldPath, NewPath) then begin AddLog('Renamed: ' + OldName + ' -> ' + NewName); RefreshAddFilesList; end
    else ShowMessage(S('msg_rename_failed', 'Failed to rename file.'));
  end;
end;

procedure TfrmMain.mnuAddDeleteClick(Sender: TObject);
var I, DeleteCount: Integer; FilePath: string;
begin
  if lvAddFiles.SelCount = 0 then Exit;
  if MessageDlg(S('dlg_delete_title', 'Confirm Delete'), Format(S('dlg_delete_prompt', 'Are you sure you want to delete %d item(s)?'), [lvAddFiles.SelCount]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  DeleteCount := 0;
  for I := lvAddFiles.Items.Count - 1 downto 0 do
    if lvAddFiles.Items[I].Selected and (lvAddFiles.Items[I].Caption <> '..') then begin
      FilePath := FCurrentAddPath + lvAddFiles.Items[I].Caption;
      if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] = '/') then FilePath := Copy(FilePath, 1, Length(FilePath) - 1);
      if DirectoryExists(FilePath) then begin if RemoveDir(FilePath) then Inc(DeleteCount); end
      else begin if SysUtils.DeleteFile(FilePath) then Inc(DeleteCount); end;
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
var FilePath: string;
  {$IFDEF WINDOWS} SEI: SHELLEXECUTEINFOW; WFilePath, WVerb: WideString; {$ENDIF}
begin
  if lvAddFiles.Selected = nil then Exit; if lvAddFiles.Selected.Caption = '..' then Exit;
  FilePath := FCurrentAddPath + lvAddFiles.Selected.Caption;
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

  FHashFileCount := lvAddFiles.SelCount;

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
    Dialog.SetDLLPath(FBridge.DLLPath);
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
    Dialog.SetDLLPath(FBridge.DLLPath);
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
    Dialog.SetDLLPath(FBridge.DLLPath);
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
type
  // Snapshot immutabile di un item del listview
  TItemSnapshot = record
    Caption:  string;
    Sub0:     string; // Size (formatted)
    Sub1:     string; // Modified
    Sub2:     string; // Created
    Sub3:     string; // Attributes
    Sub4:     string; // Extension
    RealSize: Int64;  // dimensione reale in byte (da FAddFilesList)
    IsFolder: Boolean;
    OrigIdx:  Integer; // indice originale in FAddFilesList
  end;

var
  I, J, N, LvIdx, HasDotDot: Integer;
  Swapped: Boolean;
  Snaps: array of TItemSnapshot;
  TmpSnap: TItemSnapshot;
  KeyI, KeyJ: string;

  // Ricava la chiave di sort dallo snapshot (non dall'item live)
  function SortKey(const S: TItemSnapshot): string;
  begin
    // Cartelle sempre prima dei file (prefisso #0), '..' prima di tutto
    case AColumn of
      0: // Nome
         if S.IsFolder then Result := #0 + LowerCase(S.Caption)
         else               Result := #1 + LowerCase(S.Caption);
      1: // Size numerica reale
         if S.IsFolder then Result := #0 + LowerCase(S.Caption)  // cartelle in testa
         else               Result := #1 + Format('%030d', [S.RealSize]);
      2: // Modified
         if S.IsFolder then Result := #0 + S.Sub1
         else               Result := #1 + S.Sub1;
      3: // Created
         if S.IsFolder then Result := #0 + S.Sub2
         else               Result := #1 + S.Sub2;
      4: // Attributes
         Result := S.Sub3;
      5: // Extension
         if S.IsFolder then Result := #0 + LowerCase(S.Caption)
         else               Result := #1 + LowerCase(S.Sub4);
    else
      Result := LowerCase(S.Caption);
    end;
  end;

begin
  N := lvAddFiles.Items.Count;
  if N <= 1 then Exit;

  // --- 1. Conta e salta l'eventuale riga ".." ---
  HasDotDot := 0;
  if (N > 0) and (lvAddFiles.Items[0].Caption = '..') then
    HasDotDot := 1;

  // Numero di item da ordinare (senza il '..')
  N := N - HasDotDot;
  if N <= 1 then Exit;

  // --- 2. Costruisce snapshot INDIPENDENTI dai TListItem live ---
  SetLength(Snaps, N);
  for I := 0 to N - 1 do
  begin
    LvIdx := I + HasDotDot;
    Snaps[I].Caption  := lvAddFiles.Items[LvIdx].Caption;
    if lvAddFiles.Items[LvIdx].SubItems.Count > 0 then Snaps[I].Sub0 := lvAddFiles.Items[LvIdx].SubItems[0] else Snaps[I].Sub0 := '';
    if lvAddFiles.Items[LvIdx].SubItems.Count > 1 then Snaps[I].Sub1 := lvAddFiles.Items[LvIdx].SubItems[1] else Snaps[I].Sub1 := '';
    if lvAddFiles.Items[LvIdx].SubItems.Count > 2 then Snaps[I].Sub2 := lvAddFiles.Items[LvIdx].SubItems[2] else Snaps[I].Sub2 := '';
    if lvAddFiles.Items[LvIdx].SubItems.Count > 3 then Snaps[I].Sub3 := lvAddFiles.Items[LvIdx].SubItems[3] else Snaps[I].Sub3 := '';
    if lvAddFiles.Items[LvIdx].SubItems.Count > 4 then Snaps[I].Sub4 := lvAddFiles.Items[LvIdx].SubItems[4] else Snaps[I].Sub4 := '';
    Snaps[I].IsFolder := (Length(Snaps[I].Caption) > 0) and (Snaps[I].Caption[Length(Snaps[I].Caption)] = '/');
    // Dimensione reale da FAddFilesList (indice corrispondente = LvIdx in FAddFilesList)
    if (LvIdx < Length(FAddFilesList)) then
      Snaps[I].RealSize := FAddFilesList[LvIdx].Size
    else
      Snaps[I].RealSize := 0;
    Snaps[I].OrigIdx := LvIdx;
  end;

  // --- 3. Bubble sort sugli snapshot ---
  repeat
    Swapped := False;
    for I := 0 to N - 2 do
    begin
      J := I + 1;
      KeyI := SortKey(Snaps[I]);
      KeyJ := SortKey(Snaps[J]);
      if AAscending then
      begin
        if KeyI > KeyJ then
        begin
          TmpSnap := Snaps[I]; Snaps[I] := Snaps[J]; Snaps[J] := TmpSnap;
          Swapped := True;
        end;
      end
      else
      begin
        if KeyI < KeyJ then
        begin
          TmpSnap := Snaps[I]; Snaps[I] := Snaps[J]; Snaps[J] := TmpSnap;
          Swapped := True;
        end;
      end;
    end;
    Dec(N);
  until not Swapped;

  // --- 4. Riscrive il listview dagli snapshot già ordinati ---
  // A questo punto Snaps[] è ordinato e contiene copie indipendenti delle stringhe:
  // nessun aliasing con i TListItem live, quindi niente duplicazioni.
  lvAddFiles.Items.BeginUpdate;
  try
    N := Length(Snaps);
    for I := 0 to N - 1 do
    begin
      LvIdx := I + HasDotDot;
      lvAddFiles.Items[LvIdx].Caption    := Snaps[I].Caption;
      if lvAddFiles.Items[LvIdx].SubItems.Count > 0 then lvAddFiles.Items[LvIdx].SubItems[0] := Snaps[I].Sub0;
      if lvAddFiles.Items[LvIdx].SubItems.Count > 1 then lvAddFiles.Items[LvIdx].SubItems[1] := Snaps[I].Sub1;
      if lvAddFiles.Items[LvIdx].SubItems.Count > 2 then lvAddFiles.Items[LvIdx].SubItems[2] := Snaps[I].Sub2;
      if lvAddFiles.Items[LvIdx].SubItems.Count > 3 then lvAddFiles.Items[LvIdx].SubItems[3] := Snaps[I].Sub3;
      if lvAddFiles.Items[LvIdx].SubItems.Count > 4 then lvAddFiles.Items[LvIdx].SubItems[4] := Snaps[I].Sub4;
    end;
  finally
    lvAddFiles.Items.EndUpdate;
  end;
end;



procedure TfrmMain.btnHelpClick(Sender: TObject);
begin OpenURL('https://github.com/fcorbelli/catpaq/wiki'); end;

procedure TfrmMain.btnHelp1Click(Sender: TObject);
begin

end;

end.
