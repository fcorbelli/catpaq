unit ucatpaqtypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TArchiveType:
    Identifica il tipo di archivio basandosi sui magic bytes iniziali.
    Utile per sapere quale password chiedere o se l'archivio è aperto. }
  TArchiveType = (
    atUnknown,       // Impossibile leggere o file vuoto
    atZpaqPlain,     // Magic: "7kSt" -> Nessuna crittografia
    atZpaqAes,       // Magic: (random salt) -> Crittografia standard AES-256
    atFranzen,       // Magic: "FRANZEN" + #26 -> Solo offuscamento Franzen
    atAesFranzen     // Magic: "FRENZEN" + #26 -> AES + Franzen
  );

  { TFileVersion:
    Rappresenta una specifica versione di un file (-N nel protocollo pakkalist). }
  TFileVersion = record
    Version: Integer;    // Numero versione incrementale
    DateStr: string;     // Timestamp completo (es. "17/12/2023 17:50:13" o "DELETED")
    Size: Int64;         // Dimensione in byte
    IsDeleted: Boolean;  // True se il file è stato cancellato in questa versione
  end;

  { TFileVersionArray: Array dinamico di versioni file }
  TFileVersionArray = array of TFileVersion;

  { TArchiveFileEntry:
    Rappresenta un file univoco (nome e percorso) con la storia delle sue versioni. }
  TArchiveFileEntry = record
    FileName: string;          // Nome file (es. "C:\Documenti\foto.jpg")
    Versions: TFileVersionArray; // Lista di tutte le versioni di questo file
  end;

  { TArchiveFileArray: Array dinamico di file }
  TArchiveFileArray = array of TArchiveFileEntry;

  { TArchiveVersion:
    Rappresenta una versione globale dell'intero archivio (linee che iniziano con |).
    Usato per popolare la TrackBar temporale. }
  TArchiveVersion = record
    Number: Integer;     // Numero versione globale (transazione)
    DateStr: string;     // Data della transazione (es. "2024-05-05 17:21:52")
  end;

  { TArchiveVersionArray: Array dinamico di versioni globali }
  TArchiveVersionArray = array of TArchiveVersion;

  { TArchiveData:
    Struttura root che contiene l'intero risultato del parsing di "pakkalist". }
  TArchiveData = record
    GlobalVersions: TArchiveVersionArray; // Storia delle transazioni (IMPORTANTE: rinominato per matchare il Bridge)
    Files: TArchiveFileArray;             // Contenuto dell'archivio raggruppato per file
    TotalLines: Integer;                  // Numero righe dati stimate (+N)
  end;

// --- Funzioni di Utilità ---

// Rileva il tipo di archivio leggendo l'header
function DetectArchiveType(const AFileName: string): TArchiveType;

// Converte l'enum in stringa leggibile per la UI
function ArchiveTypeToStr(AType: TArchiveType): string;

// Formatta i byte in KB/MB/GB
function FormatFileSize(ASize: Int64): string;

implementation

function DetectArchiveType(const AFileName: string): TArchiveType;
var
  F: TFileStream;
  Magic: array[0..7] of Byte;
  BytesRead: LongInt;
begin
  Result := atUnknown;
  if not FileExists(AFileName) then Exit;

  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      BytesRead := F.Read(Magic, 8);
      // Se il file è troppo corto, è sconosciuto/invalido
      if BytesRead < 4 then Exit;

      // Check 1: Standard ZPAQ "7kSt" ($37 $6B $53 $74)
      if (Magic[0] = $37) and (Magic[1] = $6B) and
         (Magic[2] = $53) and (Magic[3] = $74) then
      begin
        Result := atZpaqPlain;
        Exit;
      end;

      // Check 2: Franzen/Frenzen (richiede 8 byte completi)
      if BytesRead = 8 then
      begin
        // FRANZEN\x1a = $46 $52 $41 $4E $5A $45 $4E $1A
        if (Magic[0] = $46) and (Magic[1] = $52) and
           (Magic[2] = $41) and (Magic[3] = $4E) and
           (Magic[4] = $5A) and (Magic[5] = $45) and
           (Magic[6] = $4E) and (Magic[7] = $1A) then
        begin
          Result := atFranzen;
          Exit;
        end;

        // FRENZEN\x1a = $46 $52 $45 $4E $5A $45 $4E $1A (AES + Franzen)
        if (Magic[0] = $46) and (Magic[1] = $52) and
           (Magic[2] = $45) and (Magic[3] = $4E) and
           (Magic[4] = $5A) and (Magic[5] = $45) and
           (Magic[6] = $4E) and (Magic[7] = $1A) then
        begin
          Result := atAesFranzen;
          Exit;
        end;
      end;

      // Default ZPAQ: Se non è 7kSt e non è Franzen, ZPAQ assume che sia un Salt
      // per un archivio criptato standard.
      Result := atZpaqAes;

    finally
      F.Free;
    end;
  except
    // Gestione errori I/O (file lockato, permessi, ecc.)
    Result := atUnknown;
  end;
end;

function ArchiveTypeToStr(AType: TArchiveType): string;
begin
  case AType of
    atZpaqPlain:  Result := 'ZPAQ (Standard - No Encryption)';
    atZpaqAes:    Result := 'ZPAQ (AES-256 Encryption)';
    atFranzen:    Result := 'ZPAQ (Franzen Obfuscation)';
    atAesFranzen: Result := 'ZPAQ (AES + Franzen)';
    else          Result := 'Unknown / Invalid';
  end;
end;

function FormatFileSize(ASize: Int64): string;
begin
  if ASize < 0 then
    Result := '?'
  else if ASize < 1024 then
    Result := IntToStr(ASize) + ' B'
  else if ASize < 1024 * 1024 then
    Result := Format('%.1f KB', [ASize / 1024.0])
  else if ASize < 1024 * 1024 * 1024 then
    Result := Format('%.2f MB', [ASize / (1024.0 * 1024.0)])
  else
    Result := Format('%.2f GB', [ASize / (1024.0 * 1024.0 * 1024.0)]);
end;

end.
