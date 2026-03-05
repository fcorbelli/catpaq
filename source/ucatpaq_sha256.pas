unit ucatpaq_sha256;

{$mode objfpc}{$H+}
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses SysUtils, Classes;

type
  TSHA256Ctx = record
    State: array[0..7] of Cardinal;
    BitLen: QWord;
    Buffer: array[0..63] of Byte;
    BufLen: Cardinal;
  end;

  TSHA256Digest = array[0..31] of Byte;

procedure SHA256Init(out Ctx: TSHA256Ctx);
procedure SHA256Update(var Ctx: TSHA256Ctx; const Data; Len: Cardinal);
procedure SHA256Final(var Ctx: TSHA256Ctx; out Digest: TSHA256Digest);
function SHA256File(const Filename: string): string;
function SHA256Bytes(const Data: TBytes): string;

implementation

const
  K: array[0..63] of Cardinal = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

function ROR(x, n: Cardinal): Cardinal; inline;
begin
  Result := (x shr n) or (x shl (32 - n));
end;

procedure Transform(var State: array of Cardinal; const Buffer: array of Byte);
var
  S0, S1, Maj, T1, T2, Ch: Cardinal;
  W: array[0..63] of Cardinal;
  i: Integer;
  a, b, c, d, e, f, g, h: Cardinal;
begin
  for i := 0 to 15 do
    W[i] := (Cardinal(Buffer[i * 4]) shl 24) or (Cardinal(Buffer[i * 4 + 1]) shl 16) or
            (Cardinal(Buffer[i * 4 + 2]) shl 8) or Cardinal(Buffer[i * 4 + 3]);

  for i := 16 to 63 do
  begin
    S0 := ROR(W[i - 15], 7) xor ROR(W[i - 15], 18) xor (W[i - 15] shr 3);
    S1 := ROR(W[i - 2], 17) xor ROR(W[i - 2], 19) xor (W[i - 2] shr 10);
    W[i] := W[i - 16] + S0 + W[i - 7] + S1;
  end;

  a := State[0]; b := State[1]; c := State[2]; d := State[3];
  e := State[4]; f := State[5]; g := State[6]; h := State[7];

  for i := 0 to 63 do
  begin
    S1 := ROR(e, 6) xor ROR(e, 11) xor ROR(e, 25);
    Ch := (e and f) xor ((not e) and g);
    T1 := h + S1 + Ch + K[i] + W[i];
    S0 := ROR(a, 2) xor ROR(a, 13) xor ROR(a, 22);
    Maj := (a and b) xor (a and c) xor (b and c);
    T2 := S0 + Maj;

    h := g; g := f; f := e; e := d + T1;
    d := c; c := b; b := a; a := T1 + T2;
  end;

  State[0] := State[0] + a; State[1] := State[1] + b; State[2] := State[2] + c; State[3] := State[3] + d;
  State[4] := State[4] + e; State[5] := State[5] + f; State[6] := State[6] + g; State[7] := State[7] + h;
end;

procedure SHA256Init(out Ctx: TSHA256Ctx);
begin
  Ctx.State[0] := $6a09e667; Ctx.State[1] := $bb67ae85; Ctx.State[2] := $3c6ef372; Ctx.State[3] := $a54ff53a;
  Ctx.State[4] := $510e527f; Ctx.State[5] := $9b05688c; Ctx.State[6] := $1f83d9ab; Ctx.State[7] := $5be0cd19;
  Ctx.BitLen := 0;
  Ctx.BufLen := 0;
end;

procedure SHA256Update(var Ctx: TSHA256Ctx; const Data; Len: Cardinal);
var
  Ptr: PByte;
  i: Cardinal;
begin
  if Len = 0 then Exit;
  Ptr := @Data;
  for i := 0 to Len - 1 do
  begin
    Ctx.Buffer[Ctx.BufLen] := Ptr^;
    Inc(Ptr);
    Inc(Ctx.BufLen);
    if Ctx.BufLen = 64 then
    begin
      Transform(Ctx.State, Ctx.Buffer);
      Ctx.BitLen := Ctx.BitLen + 512;
      Ctx.BufLen := 0;
    end;
  end;
end;

procedure SHA256Final(var Ctx: TSHA256Ctx; out Digest: TSHA256Digest);
var
  i: Integer;
begin
  i := Ctx.BufLen;
  Ctx.Buffer[i] := $80;
  Inc(i);
  
  if i > 56 then
  begin
    FillChar(Ctx.Buffer[i], 64 - i, 0);
    Transform(Ctx.State, Ctx.Buffer);
    i := 0;
  end;
  
  FillChar(Ctx.Buffer[i], 56 - i, 0);
  Ctx.BitLen := Ctx.BitLen + (QWord(Ctx.BufLen) * 8);
  
  // Append BitLen in big-endian
  Ctx.Buffer[63] := Ctx.BitLen and $FF;
  Ctx.Buffer[62] := (Ctx.BitLen shr 8) and $FF;
  Ctx.Buffer[61] := (Ctx.BitLen shr 16) and $FF;
  Ctx.Buffer[60] := (Ctx.BitLen shr 24) and $FF;
  Ctx.Buffer[59] := (Ctx.BitLen shr 32) and $FF;
  Ctx.Buffer[58] := (Ctx.BitLen shr 40) and $FF;
  Ctx.Buffer[57] := (Ctx.BitLen shr 48) and $FF;
  Ctx.Buffer[56] := (Ctx.BitLen shr 56) and $FF;

  Transform(Ctx.State, Ctx.Buffer);

  for i := 0 to 7 do
  begin
    Digest[i * 4]     := (Ctx.State[i] shr 24) and $FF;
    Digest[i * 4 + 1] := (Ctx.State[i] shr 16) and $FF;
    Digest[i * 4 + 2] := (Ctx.State[i] shr 8) and $FF;
    Digest[i * 4 + 3] := Ctx.State[i] and $FF;
  end;
end;

function DigestToHex(const Digest: TSHA256Digest): string;
var i: Integer;
begin
  Result := '';
  for i := 0 to 31 do Result := Result + IntToHex(Digest[i], 2);
  Result := LowerCase(Result);
end;

function SHA256File(const Filename: string): string;
var
  F: TFileStream;
  Ctx: TSHA256Ctx;
  Digest: TSHA256Digest;
  Buf: array[0..4095] of Byte;
  Num: Integer;
begin
  Result := '';
  if not FileExists(Filename) then Exit;
  SHA256Init(Ctx);
  F := TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite);
  try
    repeat
      Num := F.Read(Buf, SizeOf(Buf));
      if Num > 0 then SHA256Update(Ctx, Buf[0], Num);
    until Num = 0;
  finally
    F.Free;
  end;
  SHA256Final(Ctx, Digest);
  Result := DigestToHex(Digest);
end;

function SHA256Bytes(const Data: TBytes): string;
var
  Ctx: TSHA256Ctx;
  Digest: TSHA256Digest;
begin
  SHA256Init(Ctx);
  if Length(Data) > 0 then SHA256Update(Ctx, Data[0], Length(Data));
  SHA256Final(Ctx, Digest);
  Result := DigestToHex(Digest);
end;

end.