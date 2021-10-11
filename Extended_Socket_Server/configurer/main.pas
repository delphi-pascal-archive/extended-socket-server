unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, Grids, ValEdit, ExtCtrls, XPMan;
const StringTableName : PChar = PChar(4096);
      IconID = 1;
type
  EModuleError = class(Exception);
  EResourceError = class(Exception);

type
  TfrmMain = class(TForm)
    dlgOpenFile: TOpenDialog;
    dlgSaveFile: TSaveDialog;
    pnButtons: TPanel;
    btnOpen: TSpeedButton;
    btnSave: TSpeedButton;
    btnSaveAs: TSpeedButton;
    pnMain: TPanel;
    vleditMain: TValueListEditor;
    XPManifest: TXPManifest;
    procedure btnClick(Sender: TObject);
  private
    FFileName: String;
    FTargetIsCorrect: Boolean;
    { Private declarations }
    procedure LoadValuesFromResource(const file_name: String);
    procedure UpdateResourceValues();
    function GetRealPasw(const Psw: String): String;
    function MakeCodedPasw(const Psw: String): String;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation
{$R *.dfm}
//-----------------------------------------------------------------------------
procedure TfrmMain.btnClick(Sender: TObject);
begin
  if (Sender = btnOpen) then
    Begin
      if (dlgOpenFile.Execute) then
        Begin
          LoadValuesFromResource(dlgOpenFile.FileName);
        End;
    End
  else if (Sender = btnSave) then
    Begin
      if (FTargetIsCorrect) then UpdateResourceValues()
    End
  else if (Sender = btnSaveAs) then
    Begin
      if (FTargetIsCorrect) then
        begin
          if (dlgSaveFile.FileName = '') then dlgSaveFile.FileName := FFileName; 
          if (not dlgSaveFile.Execute) then exit;
          CopyFile(PChar(FFileName), PChar(dlgSaveFile.FileName), false);
          FFileName := dlgSaveFile.FileName;
          
          UpdateResourceValues();
        end;
    End;
end;
//-----------------------------------------------------------------------------
procedure TfrmMain.LoadValuesFromResource(const file_name: String);
// Аналогично делается через LoadString, но лень
Var
  hInstance: THandle;
  res_info: THandle;
  res_handle: THandle;
  res_sz: cardinal;
  buf: PWideChar;
  key_value: WideString;
  i, j: Longword;
Var
  login: WideString;
  password: WideString;
  port: WideString;
  com_spec: WideString;
begin
  try
    hInstance := 0;
    hInstance := LoadLibraryEx(PChar(file_name), 0,
      DONT_RESOLVE_DLL_REFERENCES or LOAD_LIBRARY_AS_DATAFILE);
    if (hInstance = 0) Then
      raise EModuleError.Create('Это неверный модуль!');
    res_info := FindResource(hInstance, StringTableName,
      RT_STRING);
    if (res_info = 0) Then
      raise EResourceError.Create('Не найдена необходимая таблица строк!');
    res_handle := LoadResource(hInstance, res_info);
    if (res_handle = 0) Then
      raise EResourceError.Create('Ресурс не может быть загружен!');
    res_sz  := SizeofResource(hInstance, res_info);
    buf     := Pointer(res_handle);
    for i := 1 to vleditMain.RowCount - 1 do
      begin
        // Первый символ - размер 2 байта
        SetLength(key_value, Word(buf^));
        for j := 1 to Word(buf^) do
          key_value[j] := (buf + j)^;
        //  + 1 - учёт адресной арифметики
        buf := buf + Word(buf^) + 1;
        if (Pointer(buf) >= (PChar(res_handle) + res_sz)) then
          raise EResourceError.Create('Не хватает строк!');
        case i of
          1: login    := key_value;
          2: password := GetRealPasw(key_value);
          3: port     := key_value;
          4: com_spec := key_value;
        end;
      end;
      // Пока без иконки
{      if (FindResource(hInstance, PChar(IconID), RT_ICON) <> 0) then
        imgIcon.Picture.Bitmap.LoadFromResourceID(hInstance, IconID);}
  except
    on E: EModuleError do
      begin
        Application.MessageBox(PChar(E.Message), PChar(Caption),
          MB_ICONERROR or MB_OK);
        exit;
      end;
    on E: EResourceError do
      begin
        Application.MessageBox(PChar(E.Message), PChar(Caption),
          MB_ICONERROR or MB_OK);
        FreeLibrary(hInstance);
        exit;
      end;
  end;
  FreeLibrary(hInstance);  
  vleditMain.Values[vleditMain.Keys[1]] := login;
  vleditMain.Values[vleditMain.Keys[2]] := password;
  vleditMain.Values[vleditMain.Keys[3]] := port;
  vleditMain.Values[vleditMain.Keys[4]] := com_spec;

  FFileName         := file_name;
  FTargetIsCorrect  := true;
  btnSave.Enabled   := FTargetIsCorrect;
  btnSaveAs.Enabled := FTargetIsCorrect;
end;
//-----------------------------------------------------------------------------
procedure TfrmMain.UpdateResourceValues();
Var hInstance: THandle;
    src_str: WideString;
    string_table: array of WideChar;
    table_size: cardinal;
    i, j: integer;
    sz: integer;
begin
  try
    hInstance := 0;
    hInstance := BeginUpdateResource(PChar(FFileName), false);

    if (hInstance = 0) then
      raise EModuleError.Create('Не могу начать обновление ресурсов!');
    for i := 1 to vleditMain.RowCount - 1 do
      begin
        if (i = 2) then
          src_str := MakeCodedPasw(vleditMain.Values[vleditMain.Keys[i]])
        else
          src_str := vleditMain.Values[vleditMain.Keys[i]];
        sz := Length(src_str);
        SetLength(string_table, Length(string_table) + sz + 1);
        string_table[Length(string_table) - sz - 1] := WideChar(sz);
        for j := 0 to sz - 1 do
          string_table[Length(string_table) - sz + j] := src_str[j + 1];
      end;
    table_size := Length(string_table) * sizeof(WideChar);
    if ((table_size and $ff) <> 0) then
    // Младший байт длины должен быть == 0, иначе выёбываются реседиторы
    // и моя проверка на число строк (при загрузке цели)
      begin
        table_size := table_size + ($100 - (table_size and $ff));
        SetLength(string_table, table_size div sizeof(WideChar));
      end;
    if (not UpdateResource(hInstance, RT_STRING, StringTableName,
        (SUBLANG_NEUTRAL shl 10) or LANG_NEUTRAL, string_table,
        table_size)) then
          raise EResourceError.Create('Не могу обновить ресурсы!');

    if (not EndUpdateResource(hInstance, false)) then
      raise EResourceError.Create('Не могу закончить обновление ресурсов!');
  except
    on E: EModuleError do
      Begin
        Application.MessageBox(PChar(E.Message), PChar(Caption),
          MB_ICONERROR or MB_OK);
        exit;
      End;
    on E: EResourceError do
      Begin
        Application.MessageBox(PChar(E.Message), PChar(Caption),
          MB_ICONERROR or MB_OK);
        EndUpdateResource(hInstance, true);
        btnSaveAs.Click;
        exit;
      End;
  end;
  Application.MessageBox(PChar('Цель была успешно обновлена'), PChar(Caption),
    MB_ICONINFORMATION or MB_OK);
end;
//-----------------------------------------------------------------------------
function TfrmMain.GetRealPasw(const Psw: String): String;
// Дешифрует пароль
Var LPos, Pl: Integer;

Begin
   Result := '';
   Pl     := Length(Psw);
   LPos   := 1;
   While (LPos < Pl)
      Do
         Begin
            Result  := Result + Chr(StrToIntDef(Copy(Psw, LPos, 3), 0));
            LPos    := LPos + 3;
         End;
End;
//-----------------------------------------------------------------------------
function TfrmMain.MakeCodedPasw(const Psw: String): String;
Var i: integer;
begin
  Result := '';
  for i := 1 to Length(Psw) do
    Result := Result + Format('%3u', [Ord(Psw[i])]);
  // Поганые идиоты, которые писали функцию format считают, что знают лучше
  // меня, что мне нужно. Они делают выравнивание пробелами. Ебаный Borland!
  for i := 1to Length(Result) do
    if (Result[i] = ' ') then Result[i] := '0';

end;
//-----------------------------------------------------------------------------
end.
