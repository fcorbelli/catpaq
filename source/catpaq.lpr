program catpaq;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // includes the LCL widgetset
  Forms, SysUtils,
  ufrmMain,       // ERA umain
  uzpaqbridge,
  ucatpaqtypes,
  ucatpaq_update, // ERA uupdate
  ucatpaq_sha256, ufrmsimply; // NUOVA UNIT

{$R *.res}

procedure ParseCommandLine;
var
  I: Integer;
  ArchiveFile: string;
begin
  ArchiveFile := '';
  I := 1;
  while I <= ParamCount do
  begin
    if (LowerCase(ParamStr(I)) = '-key') and (I < ParamCount) then
    begin
      password_aes := ParamStr(I + 1);
      Inc(I, 2);
    end
    else if (LowerCase(ParamStr(I)) = '-franzen') and (I < ParamCount) then
    begin
      password_franzen := ParamStr(I + 1);
      Inc(I, 2);
    end
    else
    begin
      // Parametro non riconosciuto = nome file archivio
      if ArchiveFile = '' then
        ArchiveFile := ParamStr(I);
      Inc(I);
    end;
  end;

  if ArchiveFile <> '' then
    frmMain.LoadArchiveFromCommandLine(ArchiveFile);
end;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);

  ParseCommandLine;

  Application.Run;
end.