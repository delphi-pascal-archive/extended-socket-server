{
  Advanced API Hook Libary.
  Coded By Ms-Rem ( Ms-Rem@yandex.ru ) ICQ 286370715
}

unit advApiHook;

{$IMAGEBASE $13140000}

interface

uses
  Windows,
  NativeAPI;

function SizeOfCode(Code: pointer): dword;
function SizeOfProc(Proc: pointer): dword;
function InjectString(Process: dword; Text: PChar): PChar;

function InjectThread(Process: dword; Thread: pointer; Info: pointer;
                      InfoLen: dword; Results: boolean): THandle;

Function InjectDll(Process: dword; ModulePath: PChar): boolean;
function InjectDllEx(Process: dword; Src: pointer): boolean;
function InjectExe(Process: dword; Data: pointer): boolean;
function InjectThisExe(Process: dword; EntryPoint: pointer): boolean;
function InjectMemory(Process: dword; Memory: pointer; Size: dword): pointer;
function ReleaseLibrary(Process: dword; ModulePath: PChar): boolean;

function CreateProcessWithDll(lpApplicationName: pchar;
                              lpCommandLine: pchar;
                              lpProcessAttributes,
                              lpThreadAttributes: PSecurityAttributes;
                              bInheritHandles: boolean;
                              dwCreationFlags: dword;
                              lpEnvironment: pointer;
                              lpCurrentDirectory: pchar;
                              const lpStartupInfo: TStartupInfo;
                              var lpProcessInformation: TProcessInformation;
                              ModulePath: PChar): boolean;

function CreateProcessWithDllEx(lpApplicationName: PChar;
                                lpCommandLine: PChar;
                                lpProcessAttributes,
                                lpThreadAttributes: PSecurityAttributes;
                                bInheritHandles: boolean;
                                dwCreationFlags: dword;
                                lpEnvironment: pointer;
                                lpCurrentDirectory: PChar;
                                const lpStartupInfo: TStartupInfo;
                                var lpProcessInformation:
                                TProcessInformation;
                                Src: pointer): boolean;

function HookCode(TargetProc, NewProc: pointer; var OldProc: pointer): boolean;

function HookProc(lpModuleName, lpProcName: PChar;
                  NewProc: pointer; var OldProc: pointer): boolean;

function UnhookCode(OldProc: pointer): boolean;
function DisableSFC: boolean;

function GetProcAddressEx(Process: dword; lpModuleName,
                          lpProcName: pchar; dwProcLen: dword): pointer;

Function StopProcess(ProcessId: dword): boolean;
Function RunProcess(ProcessId: dword): boolean;
Function StopThreads(): boolean;
Function RunThreads(): boolean;
function EnablePrivilegeEx(Process: dword; lpPrivilegeName: PChar):Boolean;
function EnablePrivilege(lpPrivilegeName: PChar):Boolean;
function EnableDebugPrivilegeEx(Process: dword):Boolean;
function EnableDebugPrivilege():Boolean;
function GetProcessId(pName: PChar): dword;
Function OpenProcessEx(dwProcessId: DWORD): THandle;
Function SearchProcessThread(ProcessId: dword): dword;
function CreateZombieProcess(lpCommandLine: pchar;
                             var lpProcessInformation: TProcessInformation;
                             ModulePath: PChar): boolean;
function InjectDllAlt(Process: dword; ModulePath: PChar): boolean;
Function DebugKillProcess(ProcessId: dword): boolean;

implementation

type
TTHREADENTRY32 = packed record
  dwSize: DWORD;
  cntUsage: DWORD;
  th32ThreadID: DWORD;
  th32OwnerProcessID: DWORD;
  tpBasePri: Longint;
  tpDeltaPri: Longint;
  dwFlags: DWORD;
  end;

TPROCESSENTRY32 = packed record
  dwSize: DWORD;
  cntUsage: DWORD;
  th32ProcessID: DWORD;
  th32DefaultHeapID: DWORD;
  th32ModuleID: DWORD;
  cntThreads: DWORD;
  th32ParentProcessID: DWORD;
  pcPriClassBase: Longint;
  dwFlags: DWORD;
  szExeFile: array[0..MAX_PATH - 1] of Char;
  end;


TModuleList = array of dword;

PImageImportDescriptor = ^TImageImportDescriptor;
TImageImportDescriptor = packed record
  OriginalFirstThunk: dword;
  TimeDateStamp: dword;
  ForwarderChain: dword;
  Name: dword;
  FirstThunk: dword;
  end;

PImageBaseRelocation = ^TImageBaseRelocation;
TImageBaseRelocation = packed record
  VirtualAddress: dword;
  SizeOfBlock: dword;
  end;

TStringArray = array of string;

TDllEntryProc = function(hinstDLL: HMODULE; dwReason: dword;
                         lpvReserved: pointer): boolean; stdcall;

PLibInfo = ^TLibInfo;
TLibInfo = packed record
  ImageBase: pointer;
  ImageSize: longint;
  DllProc: TDllEntryProc;
  DllProcAddress: pointer;
  LibsUsed: TStringArray;
  end;

TSections = array [0..0] of TImageSectionHeader;

const
  IMPORTED_NAME_OFFSET   = $00000002;
  IMAGE_ORDINAL_FLAG32   = $80000000;
  IMAGE_ORDINAL_MASK32   = $0000FFFF;
  THREAD_ALL_ACCESS      = $001F03FF;
  THREAD_SUSPEND_RESUME  = $00000002;
  TH32CS_SNAPTHREAD      = $00000004;
  TH32CS_SNAPPROCESS     = $00000002;

  Opcodes1: array [0..255] of word =
  (
    $4211, $42E4, $2011, $20E4, $8401, $8C42, $0000, $0000, $4211, $42E4,
    $2011, $20E4, $8401, $8C42, $0000, $0000, $4211, $42E4, $2011, $20E4,
    $8401, $8C42, $0000, $0000, $4211, $42E4, $2011, $20E4, $8401, $8C42,
    $0000, $0000, $4211, $42E4, $2011, $20E4, $8401, $8C42, $0000, $8000,
    $4211, $42E4, $2011, $20E4, $8401, $8C42, $0000, $8000, $4211, $42E4,
    $2011, $20E4, $8401, $8C42, $0000, $8000, $0211, $02E4, $0011, $00E4,
    $0401, $0C42, $0000, $8000, $6045, $6045, $6045, $6045, $6045, $6045,
    $6045, $6045, $6045, $6045, $6045, $6045, $6045, $6045, $6045, $6045,
    $0045, $0045, $0045, $0045, $0045, $0045, $0045, $0045, $6045, $6045,
    $6045, $6045, $6045, $6045, $6045, $6045, $0000, $8000, $00E4, $421A,
    $0000, $0000, $0000, $0000, $0C00, $2CE4, $0400, $24E4, $0000, $0000,
    $0000, $0000, $1400, $1400, $1400, $1400, $1400, $1400, $1400, $1400,
    $1400, $1400, $1400, $1400, $1400, $1400, $1400, $1400, $0510, $0DA0,
    $0510, $05A0, $0211, $02E4, $A211, $A2E4, $4211, $42E4, $2011, $20E4,
    $42E3, $20E4, $00E3, $01A0, $0000, $E046, $E046, $E046, $E046, $E046,
    $E046, $E046, $8000, $0000, $0000, $0000, $0000, $0000, $0000, $8000,
    $8101, $8142, $0301, $0342, $0000, $0000, $0000, $0000, $0401, $0C42,
    $0000, $0000, $8000, $8000, $0000, $0000, $6404, $6404, $6404, $6404,
    $6404, $6404, $6404, $6404, $6C45, $6C45, $6C45, $6C45, $6C45, $6C45,
    $6C45, $6C45, $4510, $45A0, $0800, $0000, $20E4, $20E4, $4510, $4DA0,
    $0000, $0000, $0800, $0000, $0000, $0400, $0000, $0000, $4110, $41A0,
    $4110, $41A0, $8400, $8400, $0000, $8000, $0008, $0008, $0008, $0008,
    $0008, $0008, $0008, $0008, $1400, $1400, $1400, $1400, $8401, $8442,
    $0601, $0642, $1C00, $1C00, $0000, $1400, $8007, $8047, $0207, $0247,
    $0000, $0000, $0000, $0000, $0000, $0000, $0008, $0008, $0000, $0000,
    $0000, $0000, $0000, $0000, $4110, $01A0
  );

  Opcodes2: array [0..255] of word =
  (
    $0118, $0120, $20E4, $20E4, $FFFF, $0000, $0000, $0000, $0000, $0000,
    $FFFF, $FFFF, $FFFF, $0110, $0000, $052D, $003F, $023F, $003F, $023F,
    $003F, $003F, $003F, $023F, $0110, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF,
    $FFFF, $FFFF, $4023, $4023, $0223, $0223, $FFFF, $FFFF, $FFFF, $FFFF,
    $003F, $023F, $002F, $023F, $003D, $003D, $003F, $003F, $0000, $8000,
    $8000, $8000, $0000, $0000, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF,
    $FFFF, $FFFF, $FFFF, $FFFF, $20E4, $20E4, $20E4, $20E4, $20E4, $20E4,
    $20E4, $20E4, $20E4, $20E4, $20E4, $20E4, $20E4, $20E4, $20E4, $20E4,
    $4227, $003F, $003F, $003F, $003F, $003F, $003F, $003F, $003F, $003F,
    $003F, $003F, $003F, $003F, $003F, $003F, $00ED, $00ED, $00ED, $00ED,
    $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED,
    $0065, $00ED, $04ED, $04A8, $04A8, $04A8, $00ED, $00ED, $00ED, $0000,
    $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF, $0265, $02ED, $1C00, $1C00,
    $1C00, $1C00, $1C00, $1C00, $1C00, $1C00, $1C00, $1C00, $1C00, $1C00,
    $1C00, $1C00, $1C00, $1C00, $4110, $4110, $4110, $4110, $4110, $4110,
    $4110, $4110, $4110, $4110, $4110, $4110, $4110, $4110, $4110, $4110,
    $0000, $0000, $8000, $02E4, $47E4, $43E4, $C211, $C2E4, $0000, $0000,
    $0000, $42E4, $47E4, $43E4, $0020, $20E4, $C211, $C2E4, $20E4, $42E4,
    $20E4, $22E4, $2154, $211C, $FFFF, $FFFF, $05A0, $42E4, $20E4, $20E4,
    $2154, $211C, $A211, $A2E4, $043F, $0224, $0465, $24AC, $043F, $8128,
    $6005, $6005, $6005, $6005, $6005, $6005, $6005, $6005, $FFFF, $00ED,
    $00ED, $00ED, $00ED, $00ED, $02ED, $20AC, $00ED, $00ED, $00ED, $00ED,
    $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED,
    $003F, $02ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED,
    $FFFF, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED, $00ED,
    $00ED, $00ED, $00ED, $00ED, $00ED, $0000                            
  );

  Opcodes3: array [0..9] of array [0..15] of word =
  (
     ($0510, $FFFF, $4110, $4110, $8110, $8110, $8110, $8110, $0510, $FFFF,
      $4110, $4110, $8110, $8110, $8110, $8110),
     ($0DA0, $FFFF, $41A0, $41A0, $81A0, $81A0, $81A0, $81A0, $0DA0, $FFFF,
      $41A0, $41A0, $81A0, $81A0, $81A0, $81A0),
     ($0120, $0120, $0120, $0120, $0120, $0120, $0120, $0120, $0036, $0036,
      $0030, $0030, $0036, $0036, $0036, $0036),
     ($0120, $FFFF, $0120, $0120, $0110, $0118, $0110, $0118, $0030, $0030,
      $0000, $0030, $0000, $0000, $0000, $0000),
     ($0120, $0120, $0120, $0120, $0120, $0120, $0120, $0120, $0036, $0036,
      $0036, $0036, $FFFF, $0000, $FFFF, $FFFF),
     ($0120, $FFFF, $0120, $0120, $FFFF, $0130, $FFFF, $0130, $0036, $0036,
      $0036, $0036, $0000, $0036, $0036, $0000),
     ($0128, $0128, $0128, $0128, $0128, $0128, $0128, $0128, $0236, $0236,
      $0030, $0030, $0236, $0236, $0236, $0236),
     ($0128, $FFFF, $0128, $0128, $0110, $FFFF, $0110, $0118, $0030, $0030,
      $0030, $0030, $0030, $0030, $FFFF, $FFFF),
     ($0118, $0118, $0118, $0118, $0118, $0118, $0118, $0118, $0236, $0236,
      $0030, $0236, $0236, $0236, $0236, $0236),      
     ($0118, $FFFF, $0118, $0118, $0130, $0128, $0130, $0128, $0030, $0030,
      $0030, $0030, $0000, $0036, $0036, $FFFF)
  );

Function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): dword stdcall;
                                  external 'kernel32.dll';
Function Thread32First(hSnapshot: THandle; var lpte: TThreadEntry32): BOOL stdcall;
                                  external 'kernel32.dll';
Function Thread32Next(hSnapshot: THandle; var lpte: TThreadENtry32): BOOL stdcall;
                                  external 'kernel32.dll';
Function Process32First(hSnapshot: THandle; var lppe: TProcessEntry32): BOOL stdcall;
                                  external 'kernel32.dll';
Function Process32Next(hSnapshot: THandle; var lppe: TProcessEntry32): BOOL stdcall;
                                  external 'kernel32.dll';

Function OpenThread(dwDesiredAccess: dword;
                    bInheritHandle: bool;
                    dwThreadId: dword): dword; stdcall;
                                  external 'kernel32.dll';

function SaveOldFunction(Proc: pointer; Old: pointer): dword; forward;
function MapLibrary(Process: dword; Dest, Src: pointer): TLibInfo; forward;

//**********
function StrToInt(S: string): integer;
begin
 Val(S, Result, Result);
end;

procedure Add(Strings: TStringArray; Text: string);
begin
  SetLength(Strings, Length(Strings) + 1);
  Strings[Length(Strings) - 1] := Text;
end;

function Find(Strings: array of string; Text: string; var Index: integer): boolean;
 var
  StringLoop: integer;
begin
  Result := False;
  for StringLoop := 0 to Length(Strings) - 1 do
    if lstrcmpi(pchar(Strings[StringLoop]), pchar(Text)) = 0 then
    begin
      Index := StringLoop;
      Result := True;
    end;
end;

function GetSectionProtection(ImageScn: dword): dword;
  begin
    Result := 0;
    if (ImageScn and IMAGE_SCN_MEM_NOT_CACHED) <> 0 then
        Result := Result or PAGE_NOCACHE;
    if (ImageScn and IMAGE_SCN_MEM_EXECUTE) <> 0 then
    begin
      if (ImageScn and IMAGE_SCN_MEM_READ)<> 0 then
      begin
        if (ImageScn and IMAGE_SCN_MEM_WRITE)<> 0 then
           Result := Result or PAGE_EXECUTE_READWRITE
           else Result := Result or PAGE_EXECUTE_READ;

      end
      else if (ImageScn and IMAGE_SCN_MEM_WRITE) <> 0 then
        Result := Result or PAGE_EXECUTE_WRITECOPY
        else Result := Result or PAGE_EXECUTE;

    end
    else if (ImageScn and IMAGE_SCN_MEM_READ)<> 0 then
    begin
      if (ImageScn and IMAGE_SCN_MEM_WRITE) <> 0 then
        Result := Result or PAGE_READWRITE
        else Result := Result or PAGE_READONLY;

    end
    else if (ImageScn and IMAGE_SCN_MEM_WRITE) <> 0 then
      Result := Result or PAGE_WRITECOPY
      else Result := Result or PAGE_NOACCESS;
  end;

//***********


{????????? ??????? ??????? ???????? ???????? ?? ????????? ?? ??? }
function SizeOfCode(Code: pointer): dword;
var
  Opcode: word;
  Modrm: byte;
  Fixed, AddressOveride: boolean;
  Last, OperandOveride, Flags, Rm, Size, Extend: dword;
begin
  try
    Last := dword(Code);
    if Code <> nil then
    begin
      AddressOveride := False;
      Fixed := False;
      OperandOveride := 4;
      Extend := 0;
      repeat
        Opcode := byte(Code^);
        Code := pointer(dword(Code) + 1);
        if Opcode = $66 then OperandOveride := 2
        else if Opcode = $67 then  AddressOveride := True
        else
        if not ((Opcode and $E7) = $26) then
         if not (Opcode in [$64..$65]) then  Fixed := True;
      until Fixed;
      if Opcode = $0f then
      begin
        Opcode := byte(Code^);
        Flags := Opcodes2[Opcode];
        Opcode := Opcode + $0f00;
        Code := pointer(dword(Code) + 1);
      end
      else Flags := Opcodes1[Opcode];

      if ((Flags and $0038) <> 0) then
      begin
        Modrm := byte(Code^);
        Rm := Modrm and $7;
        Code := pointer(dword(Code) + 1);
        
        case (Modrm and $c0) of
          $40: Size := 1;
          $80: if AddressOveride then Size := 2 else Size := 4;
          else Size := 0;
        end;

        if not (((Modrm and $c0) <> $c0) and AddressOveride) then
        begin
          if (Rm = 4) and ((Modrm and $c0) <> $c0) then Rm := byte(Code^) and $7;
          if ((Modrm and $c0 = 0) and (Rm = 5)) then Size := 4;
          Code := pointer(dword(Code) + Size);
        end;
        
        if ((Flags and $0038) = $0008) then
        begin
          case Opcode of
            $f6: Extend := 0;
            $f7: Extend := 1;
            $d8: Extend := 2;
            $d9: Extend := 3;
            $da: Extend := 4;
            $db: Extend := 5;
            $dc: Extend := 6;
            $dd: Extend := 7;
            $de: Extend := 8;
            $df: Extend := 9;
          end;
          if ((Modrm and $c0) <> $c0) then
            Flags := Opcodes3[Extend][(Modrm shr 3) and $7] else
            Flags := Opcodes3[Extend][((Modrm shr 3) and $7) + 8];
        end;
        
      end;
      case (Flags and $0C00) of
        $0400: Code := pointer(dword(Code) + 1);
        $0800: Code := pointer(dword(Code) + 2);
        $0C00: Code := pointer(dword(Code) + OperandOveride);
        else
        begin
          case Opcode of
            $9a, $ea: Code := pointer(dword(Code) + OperandOveride + 2);
            $c8: Code := pointer(dword(Code) + 3);
            $a0..$a3:
              begin
                if AddressOveride then
                  Code := pointer(dword(Code) + 2)
                  else Code := pointer(dword(Code) + 4);
              end;
          end;
        end;
      end;
    end;
    Result := dword(Code) - Last;
  except
    Result := 0;
  end;
end;

{ ????????? ??????? ??????? ?? ???????? ?? ??? (?????? ?? ?????? ???????? RET) }
function SizeOfProc(Proc: pointer): dword;
var
  Length: dword;
begin
  Result := 0;
  repeat
    Length := SizeOfCode(Proc);
    Inc(Result, Length);
    if ((Length = 1) and (byte(Proc^) = $C3)) then Break;
    Proc := pointer(dword(Proc) + Length);
  until Length = 0;
end;

{ ????????? null terminated ?????? ? ??????? }
function InjectString(Process: dword; Text: PChar): PChar;
var
  BytesWritten: dword;
begin
  Result := VirtualAllocEx(Process, nil, Length(Text) + 1,
                           MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  WriteProcessMemory(Process, Result, Text, Length(Text) + 1, BytesWritten);
end;

{ ????????? ??????? ?????? ? ??????? }
function InjectMemory(Process: dword; Memory: pointer; Size: dword): pointer;
var
  BytesWritten: dword;
begin
  Result := VirtualAllocEx(Process, nil, Size, MEM_COMMIT or MEM_RESERVE,
                           PAGE_EXECUTE_READWRITE);
  WriteProcessMemory(Process, Result, Memory, Size, BytesWritten);
end;


{
  ????????? ? ??????? ???? ???????, ????????? ? ??? ?????? ? ?????? ??????.
  Process - ????? ????????? ????????,
  Thread  - ????? ????????? ?????? ? ??????? ?????????,
  Info    - ????? ?????? ???????????? ??????
  InfoLen - ?????? ?????? ???????????? ??????
  Results - ????????????? ???????? ?????????? (??????? ????? ?????????? ??????)
}
function InjectThread(Process: dword; Thread: pointer; Info: pointer;
                      InfoLen: dword; Results: boolean): THandle;
var
  pThread, pInfo: pointer;
  BytesRead, TID: dword;
begin
  pInfo := InjectMemory(Process, Info, InfoLen);
  pThread := InjectMemory(Process, Thread, SizeOfProc(Thread));
  Result := CreateRemoteThread(Process, nil, 0, pThread, pInfo, 0, TID);
  if Results then
    begin
      WaitForSingleObject(Result, INFINITE);
      ReadProcessMemory(Process, pInfo, Info, InfoLen, BytesRead);
    end;
end;

{ ????????? Dll ? ??????? }
Function InjectDll(Process: dword; ModulePath: PChar): boolean;
var
  Memory:pointer;
  Code: dword;
  BytesWritten: dword;
  ThreadId: dword;
  hThread: dword;
  hKernel32: dword;
  Inject: packed record
           PushCommand:byte;
           PushArgument:DWORD;
           CallCommand:WORD;
           CallAddr:DWORD;
           PushExitThread:byte;
           ExitThreadArg:dword;
           CallExitThread:word;
           CallExitThreadAddr:DWord;
           AddrLoadLibrary:pointer;
           AddrExitThread:pointer;
           LibraryName:array[0..MAX_PATH] of char;
          end;
begin
  Result := false;
  Memory := VirtualAllocEx(Process, nil, sizeof(Inject),
                           MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then Exit;

  Code := dword(Memory);
  //????????????? ??????????? ????:
  Inject.PushCommand    := $68;
  inject.PushArgument   := code + $1E;
  inject.CallCommand    := $15FF;
  inject.CallAddr       := code + $16;
  inject.PushExitThread := $68;
  inject.ExitThreadArg  := 0;
  inject.CallExitThread := $15FF;
  inject.CallExitThreadAddr := code + $1A;
  hKernel32 := GetModuleHandle('kernel32.dll');
  inject.AddrLoadLibrary := GetProcAddress(hKernel32, 'LoadLibraryA');
  inject.AddrExitThread  := GetProcAddress(hKernel32, 'ExitThread');
  lstrcpy(@inject.LibraryName, ModulePath);
  //???????? ???????? ??? ?? ?????????????????? ??????
  WriteProcessMemory(Process, Memory, @inject, sizeof(inject), BytesWritten);
  //????????? ???????? ???
  hThread := CreateRemoteThread(Process, nil, 0, Memory, nil, 0, ThreadId);
  if hThread = 0 then Exit;
  CloseHandle(hThread);
  Result := True;
end;

{ ????????? ??????? Dll ? ??????? (???? ??????? ?? Dll) }
Function InjectThisDll(Process: dword): boolean;
var
 Name: array [0..MAX_PATH] of Char;
begin
  GetModuleFileName(hInstance, @Name, MAX_PATH);
  Result := InjectDll(Process, @Name);
end;


{
  ????????? Dll ? ??????? ??????? ???????? ???? ? ????????? ?????? Dll ? ??????.
  ?????? ????? ????????? ????? ???????, ? ?? ?????????????? ???????????.
}
function InjectDllEx(Process: dword; Src: pointer): boolean;
type
  TDllLoadInfo = packed record
                  Module: pointer;
                  EntryPoint: pointer;
                 end;
var
  Lib: TLibInfo;
  BytesWritten: dword;
  ImageNtHeaders: PImageNtHeaders;
  pModule: pointer;
  Offset: dword;
  DllLoadInfo: TDllLoadInfo;
  hThread: dword;

 { ????????? ???????? ?????????? ?? ????? ????? dll }
  procedure DllEntryPoint(lpParameter: pointer); stdcall;
  var
    LoadInfo: TDllLoadInfo;
  begin
    LoadInfo := TDllLoadInfo(lpParameter^);
    asm
      xor eax, eax
      push eax
      push DLL_PROCESS_ATTACH
      push LoadInfo.Module
      call LoadInfo.EntryPoint
    end;
  end;

begin
  Result := False;
  ImageNtHeaders := pointer(dword(Src) + dword(PImageDosHeader(Src)._lfanew));
  Offset := $10000000;
  repeat
    Inc(Offset, $10000);
    pModule := VirtualAlloc(pointer(ImageNtHeaders.OptionalHeader.ImageBase + Offset),
                            ImageNtHeaders.OptionalHeader.SizeOfImage,
                            MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if pModule <> nil then
    begin
      VirtualFree(pModule, 0, MEM_RELEASE);
      pModule := VirtualAllocEx(Process, pointer(ImageNtHeaders.OptionalHeader.
                                                 ImageBase + Offset),
                                                 ImageNtHeaders.OptionalHeader.
                                                 SizeOfImage,
                                                 MEM_COMMIT or MEM_RESERVE,
                                                 PAGE_EXECUTE_READWRITE);
    end;
  until ((pModule <> nil) or (Offset > $30000000));
  Lib := MapLibrary(Process, pModule, Src);
  if Lib.ImageBase = nil then Exit;
  DllLoadInfo.Module     := Lib.ImageBase;
  DllLoadInfo.EntryPoint := Lib.DllProcAddress;
  WriteProcessMemory(Process, pModule, Lib.ImageBase, Lib.ImageSize, BytesWritten);
  hThread := InjectThread(Process, @DllEntryPoint, @DllLoadInfo,
                          SizeOf(TDllLoadInfo), False);
  if hThread <> 0 then Result := True
end;

{ ????????? ? ??????? ?????? ??????? Dll (???? ??????? ?? Dll) }
Function InjectThisDllEx(Process: dword): boolean;
begin
 Result := InjectDllEx(Process, pointer(hInstance));
end;


{
 ????????? ?????? Exe ????? ? ????? ???????? ???????????? ? ?????? ??? ????? ?????.
 Data - ????? ?????? ????? ? ??????? ????????.
}
function InjectExe(Process: dword; Data: pointer): boolean;
var
  Module, NewModule: pointer;
  EntryPoint: pointer;
  Size, TID: dword;
  hThread  : dword;
  BytesWritten: dword;
  Header: PImageOptionalHeader;
begin
  Result := False;
  Header := PImageOptionalHeader(pointer(integer(Data) +
                               PImageDosHeader(Data)._lfanew + SizeOf(dword) +
                               SizeOf(TImageFileHeader)));
  Size := Header^.SizeOfImage;
  Module := pointer(Header^.ImageBase);
  EntryPoint := pointer(Header^.ImageBase + Header^.AddressOfEntryPoint);
  
  NewModule := VirtualAllocEx(Process, Module, Size, MEM_COMMIT or
                              MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if NewModule = nil then exit;
  WriteProcessMemory(Process, NewModule, Module, Size, BytesWritten);
  hThread := CreateRemoteThread(Process, nil, 0, EntryPoint, NewModule, 0, TID);
  if hThread <> 0 then Result := True;
end;

{
 ????????? ?????? ???????? ???????? ? ????? ???????? ????????????.
 EntryPoint - ????? ????? ????? ??????????? ????.
}
function InjectThisExe(Process: dword; EntryPoint: pointer): boolean;
var
  Module, NewModule: pointer;
  Size, TID: dword;
  hThread  : dword;
  BytesWritten: dword;

  Buf: PChar;
begin
  Result := False;
  Module := pointer(GetModuleHandle(nil));
  Size := PImageOptionalHeader(pointer(integer(Module) +
                               PImageDosHeader(Module)._lfanew + SizeOf(dword) +
                               SizeOf(TImageFileHeader))).SizeOfImage;
  NewModule := VirtualAllocEx(Process, Module, Size, MEM_COMMIT or
                              MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if NewModule = nil then exit;
  WriteProcessMemory(Process, NewModule, Module, Size, BytesWritten);
  hThread := CreateRemoteThread(Process, nil, 0, EntryPoint, NewModule, 0, TID);
  if hThread <> 0 then Result := True;
end;

{ ???????? Dll ?? ?????? ????????? ???????????? }
function  ReleaseLibrary(Process: dword; ModulePath: PChar): boolean;
type
  TReleaseLibraryInfo = packed record
    pFreeLibrary: pointer;
    pGetModuleHandle: pointer;
    lpModuleName: pointer;
    pExitThread: pointer;
  end;
var
  ReleaseLibraryInfo: TReleaseLibraryInfo;
  hThread: dword;

  procedure ReleaseLibraryThread(lpParameter: pointer); stdcall;
  var
    ReleaseLibraryInfo: TReleaseLibraryInfo;
  begin
    ReleaseLibraryInfo := TReleaseLibraryInfo(lpParameter^);
    asm
      @1:
      inc ecx
      push ReleaseLibraryInfo.lpModuleName
      call ReleaseLibraryInfo.pGetModuleHandle
      cmp eax, 0
      je @2
      push eax
      call ReleaseLibraryInfo.pFreeLibrary
      jmp @1
      @2:
      push eax
      call ReleaseLibraryInfo.pExitThread
    end;
  end;

begin
  Result := False;
  ReleaseLibraryInfo.pGetModuleHandle := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                        'GetModuleHandleA');
  ReleaseLibraryInfo.pFreeLibrary := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                    'FreeLibrary');
  ReleaseLibraryInfo.pExitThread := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                   'ExitThread');
  ReleaseLibraryInfo.lpModuleName := InjectString(Process, ModulePath);
  if ReleaseLibraryInfo.lpModuleName = nil then Exit;
  hThread := InjectThread(Process, @ReleaseLibraryThread, @ReleaseLibraryInfo,
                          SizeOf(TReleaseLibraryInfo), False);
  if hThread = 0 then Exit;
  CloseHandle(hThread);
  Result := True;
end;

{ ?????? ???????? ? ????????? ? ???? Dll }
function CreateProcessWithDll(lpApplicationName: pchar;
                              lpCommandLine: pchar;
                              lpProcessAttributes,
                              lpThreadAttributes: PSecurityAttributes;
                              bInheritHandles: boolean;
                              dwCreationFlags: dword;
                              lpEnvironment: pointer;
                              lpCurrentDirectory: pchar;
                              const lpStartupInfo: TStartupInfo;
                              var lpProcessInformation: TProcessInformation;
                              ModulePath: PChar): boolean;
begin
  Result := False;
  if not CreateProcess(lpApplicationName,
                       lpCommandLine,
                       lpProcessAttributes,
                       lpThreadAttributes,
                       bInheritHandles,
                       dwCreationFlags or CREATE_SUSPENDED,
                       lpEnvironment,
                       lpCurrentDirectory,
                       lpStartupInfo, lpProcessInformation) then Exit;

  Result := InjectDll(lpProcessInformation.hProcess, ModulePath);
  if (dwCreationFlags and CREATE_SUSPENDED) = 0 then
       ResumeThread(lpProcessInformation.hThread);
end;


{
 ?????? ???????? ? ????????? ? ???? Dll ?????????????? ???????.
 ?????????????? ??????? ?????????? ???????? Dll.
}
function CreateProcessWithDllEx(lpApplicationName: PChar;
                                lpCommandLine: PChar;
                                lpProcessAttributes,
                                lpThreadAttributes: PSecurityAttributes;
                                bInheritHandles: boolean;
                                dwCreationFlags: dword;
                                lpEnvironment: pointer;
                                lpCurrentDirectory: PChar;
                                const lpStartupInfo: TStartupInfo;
                                var lpProcessInformation:
                                TProcessInformation;
                                Src: pointer): boolean;
begin
  Result := False;
  if not CreateProcess(lpApplicationName,
                       lpCommandLine,
                       lpProcessAttributes,
                       lpThreadAttributes,
                       bInheritHandles,
                       dwCreationFlags or CREATE_SUSPENDED,
                       lpEnvironment,
                       lpCurrentDirectory,
                       lpStartupInfo,
                       lpProcessInformation) then Exit;
                       
  Result := InjectDllEx(lpProcessInformation.hProcess, Src);
  if (dwCreationFlags and CREATE_SUSPENDED) = 0 then
       ResumeThread(lpProcessInformation.hThread);
end;

{
  ????????? ????????? ???????.
  TargetProc - ????? ??????????????? ???????,
  NewProc    - ????? ??????? ??????,
  OldProc    - ????? ????? ???????? ????? ????? ? ?????? ???????.
}
function HookCode(TargetProc, NewProc: pointer; var OldProc: pointer): boolean;
var
  Address: dword;
  OldProtect: dword;
  OldFunction: pointer;
  Proc: pointer;
begin
  Result := False;
  try
    Proc := TargetProc;
    //????????? ????? ?????????????? (jmp near) ???????? ?? ????? ???????   
    Address := dword(NewProc) - dword(Proc) - 5;
    VirtualProtect(Proc, 5, PAGE_EXECUTE_READWRITE, OldProtect);
    //??????? ?????? ??? true ??????? 
    GetMem(OldFunction, 255);
    //???????? ?????? 4 ????? ??????? 
    dword(OldFunction^) := dword(Proc);
    byte(pointer(dword(OldFunction) + 4)^) := SaveOldFunction(Proc, pointer(dword(OldFunction) + 5));
    //byte(pointer(dword(OldFunction) + 4)^) - ????? ???????????? ???????
    byte(Proc^) := $e9; //????????????? ??????? 
    dword(pointer(dword(Proc) + 1)^) := Address;
    VirtualProtect(Proc, 5, OldProtect, OldProtect);
    OldProc := pointer(dword(OldFunction) + 5);
  except
    Exit;
  end;
  Result := True;
end;


{
 ????????? ????????? ??????? ?? Dll ? ??????? ????????.
 lpModuleName - ??? ??????,
 lpProcName   - ??? ???????,
 NewProc    - ????? ??????? ??????,
 OldProc    - ????? ????? ???????? ????? ????? ? ?????? ???????.
 ? ?????? ?????????? ?????? ? ??????? ??, ????? ??????? ??????? ??? ?????????.
}
function HookProc(lpModuleName, lpProcName: PChar;
                  NewProc: pointer; var OldProc: pointer): boolean;
var
 hModule: dword; 
 fnAdr: pointer;
begin
 Result := false;
 hModule := GetModuleHandle(lpModuleName);
 if hModule = 0 then hModule := LoadLibrary(lpModuleName);
 if hModule = 0 then Exit;
 fnAdr := GetProcAddress(hModule, lpProcName);
 if fnAdr = nil then Exit;
 Result := HookCode(fnAdr, NewProc, OldProc);
end;


{
 ?????? ????????? ?????????????? ?? HookCode,
 OldProc - ????? ????? ???????????? ???????? HookCode.
}
function UnhookCode(OldProc: pointer): boolean;
var
  OldProtect: dword;
  Proc: pointer;
  SaveSize: dword;
begin
  Result := True;
  try
    Proc := pointer(dword(pointer(dword(OldProc) - 5)^));
    SaveSize := byte(pointer(dword(OldProc) - 1)^);
    VirtualProtect(Proc, 5, PAGE_EXECUTE_READWRITE, OldProtect);
    CopyMemory(Proc, OldProc, SaveSize);
    VirtualProtect(Proc, 5, OldProtect, OldProtect);
    FreeMem(pointer(dword(OldProc) - 5));
  except
    Result := False;
  end;
end;


{
 ?????????? System Fle Protection ?? ????.
 ?????????? ??? ?????????? ??????????? ????????? ??????.
}
function DisableSFC: boolean;
var
  Process, SFC, PID, Thread, ThreadID: dword;
begin
  Result := False;
  SFC := LoadLibrary('sfc.dll');
  GetWindowThreadProcessID(FindWindow('NDDEAgnt', nil), @PID);
  Process := OpenProcess(PROCESS_ALL_ACCESS, False, PID);
  Thread := CreateRemoteThread(Process, nil, 0,
                               GetProcAddress(SFC, pchar(2 and $ffff)),
                               nil, 0, ThreadId);
  if Thread = 0 then Exit;
  CloseHandle(Thread);
  CloseHandle(Process);
  FreeLibrary(SFC);
  Result := True;
end;

{ ???????? ????? ? ?????? ??????? }
function SaveOldFunction(Proc: pointer; Old: pointer): dword;
var
  SaveSize, Size: dword;
  Next: pointer;
begin
  SaveSize := 0;
  Next := Proc;
  //????????? ????????? ????????? ????????, ???? ???? ??????? ??????????
  while SaveSize < 5 do
  begin
    Size := SizeOfCode(Next);
    Next := pointer(dword(Next) + Size);
    Inc(SaveSize, Size);
  end;
  CopyMemory(Old, Proc, SaveSize);
  //?????????? ??????? ?? ????????? ?????????? ????? ???????????? ???????
  byte(pointer(dword(Old) + SaveSize)^) := $e9;
  dword(pointer(dword(Old) + SaveSize + 1)^) := dword(Next) - dword(Old) - SaveSize - 5;
  Result := SaveSize;
end;

{ ????????? ?????? API ? ????? ???????? ???????????? }
function GetProcAddressEx(Process: dword; lpModuleName,
                          lpProcName: pchar; dwProcLen: dword): pointer;
type
  TGetProcAddrExInfo = record
    pExitThread: pointer;
    pGetProcAddress: pointer;
    pGetModuleHandle: pointer;
    lpModuleName: pointer;
    lpProcName: pointer;
  end;
var
  GetProcAddrExInfo: TGetProcAddrExInfo;
  ExitCode: dword;
  hThread: dword;

  procedure GetProcAddrExThread(lpParameter: pointer); stdcall;
  var
    GetProcAddrExInfo: TGetProcAddrExInfo;
  begin
    GetProcAddrExInfo := TGetProcAddrExInfo(lpParameter^);
    asm
      push GetProcAddrExInfo.lpModuleName
      call GetProcAddrExInfo.pGetModuleHandle
      push GetProcAddrExInfo.lpProcName
      push eax
      call GetProcAddrExInfo.pGetProcAddress
      push eax
      call GetProcAddrExInfo.pExitThread
    end;
  end;

begin
  Result := nil;
  GetProcAddrExInfo.pGetModuleHandle := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                       'GetModuleHandleA');
  GetProcAddrExInfo.pGetProcAddress  := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                       'GetProcAddress');
  GetProcAddrExInfo.pExitThread      := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                                       'ExitThread');
  if dwProcLen = 4 then GetProcAddrExInfo.lpProcName := lpProcName else
    GetProcAddrExInfo.lpProcName := InjectMemory(Process, lpProcName, dwProcLen);

  GetProcAddrExInfo.lpModuleName := InjectString(Process, lpModuleName);
  hThread := InjectThread(Process, @GetProcAddrExThread, @GetProcAddrExInfo,
                          SizeOf(GetProcAddrExInfo), False);

  if hThread <> 0 then
  begin
    WaitForSingleObject(hThread, INFINITE);
    GetExitCodeThread(hThread, ExitCode);
    Result := pointer(ExitCode);
  end;
end;

{
 ??????????? Dll ?? ????? ???????? ????????????, ????????? ??????? ? ???????.
 Process - ????? ???????? ??? ???????????,
 Dest    - ????? ??????????? ? ???????? Process,
 Src     - ????? ?????? Dll ? ??????? ????????. 
}
function MapLibrary(Process: dword; Dest, Src: pointer): TLibInfo;
var
  ImageBase: pointer;
  ImageBaseDelta: integer;
  ImageNtHeaders: PImageNtHeaders;
  PSections: ^TSections;
  SectionLoop: integer;
  SectionBase: pointer;
  VirtualSectionSize, RawSectionSize: dword;
  OldProtect: dword;
  NewLibInfo: TLibInfo;

  { ????????? ??????? }
  procedure ProcessRelocs(PRelocs:PImageBaseRelocation);
  var
    PReloc: PImageBaseRelocation;
    RelocsSize: dword;
    Reloc: PWord;
    ModCount: dword;
    RelocLoop: dword;
  begin
    PReloc := PRelocs;
    RelocsSize := ImageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size;
    while dword(PReloc) - dword(PRelocs) < RelocsSize do
    begin
      ModCount := (PReloc.SizeOfBlock - Sizeof(PReloc^)) div 2;
      Reloc := pointer(dword(PReloc) + sizeof(PReloc^));
      for RelocLoop := 0 to ModCount - 1 do
      begin
        if Reloc^ and $f000 <> 0 then Inc(pdword(dword(ImageBase) +
                                          PReloc.VirtualAddress +
                                          (Reloc^ and $0fff))^, ImageBaseDelta);
        Inc(Reloc);
      end;
      PReloc := pointer(Reloc);
    end;
  end;

  { ????????? ??????? Dll ? ????? ????????}
  procedure ProcessImports(PImports: PImageImportDescriptor);
  var
    PImport: PImageImportDescriptor;
    Import: pdword;
    PImportedName: pchar;
    ProcAddress: pointer;
    PLibName: pchar;
    ImportLoop: integer;

    function IsImportByOrdinal(ImportDescriptor: dword): boolean;
    begin
      Result := (ImportDescriptor and IMAGE_ORDINAL_FLAG32) <> 0;
    end;

  begin
    PImport := PImports;
    while PImport.Name <> 0 do
    begin
      PLibName := pchar(dword(PImport.Name) + dword(ImageBase));
      if not Find(NewLibInfo.LibsUsed, PLibName, ImportLoop) then
      begin
        InjectDll(Process, PLibName);
        Add(NewLibInfo.LibsUsed, PLibName);
      end;
      if PImport.TimeDateStamp = 0 then
        Import := pdword(pImport.FirstThunk + dword(ImageBase))
      else
        Import := pdword(pImport.OriginalFirstThunk + dword(ImageBase));

      while Import^ <> 0 do
      begin
        if IsImportByOrdinal(Import^) then
          ProcAddress := GetProcAddressEx(Process, PLibName, PChar(Import^ and $ffff), 4)
        else
        begin
          PImportedName := pchar(Import^ + dword(ImageBase) + IMPORTED_NAME_OFFSET);
          ProcAddress := GetProcAddressEx(Process, PLibName, PImportedName, Length(PImportedName));
        end;
        Ppointer(Import)^ := ProcAddress;
        Inc(Import);
      end;
      Inc(PImport);
    end;
  end;

begin
  ImageNtHeaders := pointer(dword(Src) + dword(PImageDosHeader(Src)._lfanew));
  ImageBase := VirtualAlloc(Dest, ImageNtHeaders.OptionalHeader.SizeOfImage,
                            MEM_RESERVE, PAGE_NOACCESS);
                            
  ImageBaseDelta := dword(ImageBase) - ImageNtHeaders.OptionalHeader.ImageBase;
  SectionBase := VirtualAlloc(ImageBase, ImageNtHeaders.OptionalHeader.SizeOfHeaders,
                              MEM_COMMIT, PAGE_READWRITE);
  Move(Src^, SectionBase^, ImageNtHeaders.OptionalHeader.SizeOfHeaders);
  VirtualProtect(SectionBase, ImageNtHeaders.OptionalHeader.SizeOfHeaders,
                 PAGE_READONLY, OldProtect);
  PSections := pointer(pchar(@(ImageNtHeaders.OptionalHeader)) +
                               ImageNtHeaders.FileHeader.SizeOfOptionalHeader);
                               
  for SectionLoop := 0 to ImageNtHeaders.FileHeader.NumberOfSections - 1 do
  begin
    VirtualSectionSize := PSections[SectionLoop].Misc.VirtualSize;
    RawSectionSize := PSections[SectionLoop].SizeOfRawData;
    if VirtualSectionSize < RawSectionSize then
    begin
      VirtualSectionSize := VirtualSectionSize xor RawSectionSize;
      RawSectionSize := VirtualSectionSize xor RawSectionSize;
      VirtualSectionSize := VirtualSectionSize xor RawSectionSize;
    end;
    SectionBase := VirtualAlloc(PSections[SectionLoop].VirtualAddress +
                                pchar(ImageBase), VirtualSectionSize,
                                MEM_COMMIT, PAGE_READWRITE);
    FillChar(SectionBase^, VirtualSectionSize, 0);
    Move((pchar(src) + PSections[SectionLoop].pointerToRawData)^,
         SectionBase^, RawSectionSize);
  end;
  NewLibInfo.DllProcAddress := pointer(ImageNtHeaders.OptionalHeader.AddressOfEntryPoint +
                                       dword(ImageBase));
   NewLibInfo.DllProc := TDllEntryProc(NewLibInfo.DllProcAddress);
  
  NewLibInfo.ImageBase := ImageBase;
  NewLibInfo.ImageSize := ImageNtHeaders.OptionalHeader.SizeOfImage;
  SetLength(NewLibInfo.LibsUsed, 0);
  if ImageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress <> 0
     then ProcessRelocs(pointer(ImageNtHeaders.OptionalHeader.
                                DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].
                                VirtualAddress + dword(ImageBase)));

  if ImageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress <> 0
     then ProcessImports(pointer(ImageNtHeaders.OptionalHeader.
                                 DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].
                                 VirtualAddress + dword(ImageBase)));
     
  for SectionLoop := 0 to ImageNtHeaders.FileHeader.NumberOfSections - 1 do
    VirtualProtect(PSections[SectionLoop].VirtualAddress + pchar(ImageBase),
                   PSections[SectionLoop].Misc.VirtualSize,
                   GetSectionProtection(PSections[SectionLoop].Characteristics),
                   OldProtect); 
  Result := NewLibInfo;
end;


{
 ????????? ???? ????? ????????.
 ???? ??????????????? ??????? ???????, ?? ?????????? ???? ?? ???????????????.
}
Function StopProcess(ProcessId: dword): boolean;
var
 Snap: dword;
 CurrTh: dword;
 ThrHandle: dword;
 Thread:TThreadEntry32;
begin
  Result := false;
  CurrTh := GetCurrentThreadId;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if (Thread.th32ThreadID <> CurrTh) and (Thread.th32OwnerProcessID = ProcessId) then
        begin
        ThrHandle := OpenThread(THREAD_SUSPEND_RESUME, false, Thread.th32ThreadID);
        if ThrHandle = 0 then Exit;
        SuspendThread(ThrHandle);
        CloseHandle(ThrHandle);
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     Result := true;
     end;
end;

{ ?????? ???????? ?????????????? StopProcess }
Function RunProcess(ProcessId: dword): boolean;
var
 Snap: dword;
 CurrTh: dword;
 ThrHandle: dword;
 Thread:TThreadEntry32;
begin
  Result := false;
  CurrTh := GetCurrentThreadId;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if (Thread.th32ThreadID <> CurrTh) and (Thread.th32OwnerProcessID = ProcessId) then
        begin
        ThrHandle := OpenThread(THREAD_SUSPEND_RESUME, false, Thread.th32ThreadID);
        if ThrHandle = 0 then Exit;
        ResumeThread(ThrHandle);
        CloseHandle(ThrHandle);
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     Result := true;
     end;
end;

{ ????? ?????? ?????????? ???? ????????? ???????? }
Function SearchProcessThread(ProcessId: dword): dword;
var
 Snap: dword;
 Thread:TThreadEntry32;
begin
  Result := 0;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
     Thread.dwSize := SizeOf(TThreadEntry32);
     if Thread32First(Snap, Thread) then
     repeat
     if Thread.th32OwnerProcessID = ProcessId then
        begin
         Result := Thread.th32ThreadID;
         CloseHandle(Snap);
         Exit;
        end;
     until not Thread32Next(Snap, Thread);
     CloseHandle(Snap);
     end;
end;

{ ????????? ???? ????? ???????? ???????? ????? ?????????? }
Function StopThreads(): boolean;
begin
  Result := StopProcess(GetCurrentProcessId());
end;

{ ?????? ????? ????????????? StopThreads}
Function RunThreads(): boolean;
begin
  Result := RunProcess(GetCurrentProcessId());
end;

{ ????????? ??????? ?????????? ??? ???????? }
function EnablePrivilegeEx(Process: dword; lpPrivilegeName: PChar):Boolean;
var
  hToken: dword;
  NameValue: Int64;
  tkp: TOKEN_PRIVILEGES;
  ReturnLength: dword;
begin
  Result:=false;
  //???????? ????? ?????? ????????
  OpenProcessToken(Process, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken);
  //???????? LUID ??????????
  if not LookupPrivilegeValue(nil, lpPrivilegeName, NameValue) then
    begin
     CloseHandle(hToken);
     exit;
    end;
  tkp.PrivilegeCount := 1;
  tkp.Privileges[0].Luid := NameValue;
  tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
  //????????? ?????????? ? ????????
  AdjustTokenPrivileges(hToken, false, tkp, SizeOf(TOKEN_PRIVILEGES), tkp, ReturnLength);
  if GetLastError() <> ERROR_SUCCESS then
     begin
      CloseHandle(hToken);
      exit;
     end;
  Result:=true;
  CloseHandle(hToken);
end;

{ ????????? ???????? ?????????? ??? ???????? ???????? }
function EnablePrivilege(lpPrivilegeName: PChar):Boolean;
begin
  Result := EnablePrivilegeEx(INVALID_HANDLE_VALUE, lpPrivilegeName);
end;


{ ????????? ?????????? SeDebugPrivilege ??? ???????? }
function EnableDebugPrivilegeEx(Process: dword):Boolean;
begin
  Result := EnablePrivilegeEx(Process, 'SeDebugPrivilege');
end;

{ ????????? ?????????? SeDebugPrivilege ??? ???????? ???????? }
function EnableDebugPrivilege():Boolean;
begin
  Result := EnablePrivilegeEx(INVALID_HANDLE_VALUE, 'SeDebugPrivilege');
end;

{ ????????? Id ???????? ?? ??? ????? }
function GetProcessId(pName: PChar): dword;
var
 Snap: dword;
 Process: TPROCESSENTRY32;
begin
  Result := 0;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap <> INVALID_HANDLE_VALUE then
     begin
      Process.dwSize := SizeOf(TPROCESSENTRY32);
      if Process32First(Snap, Process) then
         repeat
          if lstrcmpi(Process.szExeFile, pName) = 0 then
             begin
              Result := Process.th32ProcessID;
              CloseHandle(Snap);
              Exit;
             end;
         until not Process32Next(Snap, Process);
      Result := 0;
      CloseHandle(Snap);
     end;
end;


{ ????????? ?????? ???????? ?????????????? ??????? }
Function OpenProcessEx(dwProcessId: DWORD): THandle;
var
 HandlesInfo: PSYSTEM_HANDLE_INFORMATION_EX;
 ProcessInfo: _PROCESS_BASIC_INFORMATION;
 idCSRSS: dword;
 hCSRSS : dword;
 tHandle: dword;
 r      : dword;
begin
 Result := 0;
 //????????? ??????? csrss.exe 
 idCSRSS := GetProcessId('csrss.exe');
 hCSRSS  := OpenProcess(PROCESS_DUP_HANDLE, false, idCSRSS);
 if hCSRSS = 0 then Exit;
 HandlesInfo := GetInfoTable(SystemHandleInformation);
 if HandlesInfo <> nil then
 for r := 0 to HandlesInfo^.NumberOfHandles do
   if (HandlesInfo^.Information[r].ObjectTypeNumber = $5) and  //??? ?????? - ???????
      (HandlesInfo^.Information[r].ProcessId = idCSRSS) then   //???????? - CSRSS
        begin
          //???????? ????? ????
          if DuplicateHandle(hCSRSS, HandlesInfo^.Information[r].Handle,
                             INVALID_HANDLE_VALUE, @tHandle, 0, false,
                             DUPLICATE_SAME_ACCESS) then

             begin
               ZwQueryInformationProcess(tHandle, ProcessBasicInformation,
                                         @ProcessInfo,
                                         SizeOf(_PROCESS_BASIC_INFORMATION), nil);
               if ProcessInfo.UniqueProcessId = dwProcessId then
                  begin
                    VirtualFree(HandlesInfo, 0, MEM_RELEASE);
                    CloseHandle(hCSRSS);
                    Result := tHandle;
                    Exit;
                  end else CloseHandle(tHandle);
             end;
        end;
 VirtualFree(HandlesInfo, 0, MEM_RELEASE);
 CloseHandle(hCSRSS); 
end;


{ ???????? ???????? "?????", ? ????????? ???????? ????? ??????????? ???? DLL }
function CreateZombieProcess(lpCommandLine: pchar;
                             var lpProcessInformation: TProcessInformation;
                             ModulePath: PChar): boolean;
var
  Memory:pointer;
  Code: dword;
  BytesWritten: dword;
  Context: _CONTEXT;
  lpStartupInfo: TStartupInfo;
  hKernel32: dword;
  Inject: packed record
           PushCommand : byte;
           PushArgument: DWORD;
           CallCommand: WORD;
           CallAddr: DWORD;
           PushExitThread: byte;
           ExitThreadArg: dword;
           CallExitThread: word;
           CallExitThreadAddr: DWord;
           AddrLoadLibrary: pointer;
           AddrExitThread: pointer;
           LibraryName: array[0..MAX_PATH] of Char;
          end;
begin
  Result := False;
  //????????? ???????
  ZeroMemory(@lpStartupInfo, SizeOf(TStartupInfo));
  lpStartupInfo.cb := SizeOf(TStartupInfo);
  if not CreateProcess(nil, lpCommandLine, nil, nil,
                       false, CREATE_SUSPENDED, nil, nil,
                       lpStartupInfo, lpProcessInformation) then Exit;
  //???????? ?????? ??? ??????????? ????
  Memory := VirtualAllocEx(lpProcessInformation.hProcess, nil, SizeOf(Inject),
                           MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then
     begin
     TerminateProcess(lpProcessInformation.hProcess, 0);
     Exit;
     end;
  Code := dword(Memory);
  //????????????? ??????????? ????:
  Inject.PushCommand    := $68;
  inject.PushArgument   := code + $1E;
  inject.CallCommand    := $15FF;
  inject.CallAddr       := code + $16;
  inject.PushExitThread := $68;
  inject.ExitThreadArg  := 0;
  inject.CallExitThread := $15FF;
  inject.CallExitThreadAddr := code + $1A;
  hKernel32 := GetModuleHandle('kernel32.dll');
  inject.AddrLoadLibrary := GetProcAddress(hKernel32, 'LoadLibraryA');
  inject.AddrExitThread  := GetProcAddress(hKernel32, 'ExitThread');
  lstrcpy(@inject.LibraryName, ModulePath);
  //???????? ???????? ??? ?? ?????????????????? ??????
  WriteProcessMemory(lpProcessInformation.hProcess, Memory,
                     @inject, sizeof(inject), BytesWritten);

  //???????? ??????? ???????? ????????? ???? ????????
  Context.ContextFlags := CONTEXT_FULL;
  GetThreadContext(lpProcessInformation.hThread, Context);
  //???????? ???????? ???, ????? ?????????? ??? ???
  Context.Eip := code;
  SetThreadContext(lpProcessInformation.hThread, Context);
  //????????? ????
  ResumeThread(lpProcessInformation.hThread);
end;

{ ????????? DLL ?????????????? ???????? (??? CreateRemoteThread) }
function InjectDllAlt(Process: dword; ModulePath: PChar): boolean;
var
  Context: _CONTEXT;
  hThread: dword;
  ProcessInfo: _PROCESS_BASIC_INFORMATION;
  InjData:  packed record
             OldEip: dword;
             OldEsi: dword;
             AdrLoadLibrary: pointer;
             AdrLibName: pointer;
            end;

  Procedure Injector();
  asm
    pushad
    db $E8              // ????? call short 0
    dd 0                //
    pop eax             // eax - ????? ??????? ??????????
    add eax, $12
    mov [eax], esi      // ???????????? ??????? dd $00000000
    push [esi + $0C]    // ?????? ? ???? ??? DLL
    call [esi + $08]    // call LoadLibraryA
    popad
    mov esi, [esi + $4] // ??????????????? esi ?? ??????? ?????????
    dw $25FF            // ????? Jmp dword ptr [00000000h]
    dd $00000000        // ?????????????? ???????
    ret
  end;
  
begin
  Result := false;
  //???????? id ????????
  ZwQueryInformationProcess(Process, ProcessBasicInformation,
                            @ProcessInfo,
                            SizeOf(_PROCESS_BASIC_INFORMATION), nil);
  //????????? ?????? ?????????? ????
  hThread := OpenThread(THREAD_ALL_ACCESS, false,
                        SearchProcessThread(ProcessInfo.UniqueProcessId));
  if hThread = 0 then Exit;
  SuspendThread(hThread);
  //????????? ?????? ????????
  Context.ContextFlags := CONTEXT_FULL;
  GetThreadContext(hThread, Context);
  //?????????????? ?????? ??? ??????????? ????
  InjData.OldEip := Context.Eip;
  InjData.OldEsi := Context.Esi;
  InjData.AdrLoadLibrary  := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                            'LoadLibraryA');
  InjData.AdrLibName := InjectString(Process, ModulePath);
  if InjData.AdrLibName = nil then Exit;
  //???????? ?????? ? ????????????? ebp ????????? 
  Context.Esi := dword(InjectMemory(Process, @InjData, SizeOf(InjData)));
  //???????? ???
  Context.Eip := dword(InjectMemory(Process, @Injector, SizeOfProc(@Injector)));
  //????????????? ????? ???????? 
  SetThreadContext(hThread, Context);
  ResumeThread(hThread);
  Result := true;
end;


{ ???????? ???????? ?????????? ??????? }
Function DebugKillProcess(ProcessId: dword): boolean;
var
 pHandle: dword;
 myPID: dword;
 HandlesInfo: PSYSTEM_HANDLE_INFORMATION_EX;
 r: dword;
begin
 Result := false;
 myPID := GetCurrentProcessId();
 if not EnableDebugPrivilege() then Exit;
 //???????????? ? ??????? ??????? ? ???????? DebugObject
 if DbgUiConnectToDbg() <> STATUS_SUCCESS then Exit;
 pHandle := OpenProcessEx(ProcessId);
 //???????? ??????? ????????
 if DbgUiDebugActiveProcess(pHandle) <> STATUS_SUCCESS then Exit;
 //???? ????? ?????????? DebugObject
 HandlesInfo := GetInfoTable(SystemHandleInformation);
 if HandlesInfo = nil then Exit;
 for r := 0 to HandlesInfo^.NumberOfHandles do
  if (HandlesInfo^.Information[r].ProcessId = myPID) and
     (HandlesInfo^.Information[r].ObjectTypeNumber = $8)  //DebugObject
     then begin
       //????????? DebugObject, ??? ???????? ? ??????????? ????????????? ????????
       CloseHandle(HandlesInfo^.Information[r].Handle);
       Result := true;
       break;
     end;
 VirtualFree(HandlesInfo, 0, MEM_RELEASE);
end;

end.

