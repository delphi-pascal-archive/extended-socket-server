program configurer;

uses
  Forms,
  main in 'main.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '������������ Extended Socket Server';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
