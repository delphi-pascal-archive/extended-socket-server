object frmMain: TfrmMain
  Left = 285
  Top = 129
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #1050#1086#1085#1092#1080#1075#1091#1088#1072#1094#1080#1103' Extended Socket Server'
  ClientHeight = 266
  ClientWidth = 492
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 13
  object pnButtons: TPanel
    Left = 0
    Top = 208
    Width = 492
    Height = 58
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnOpen: TSpeedButton
      Left = 8
      Top = 15
      Width = 120
      Height = 30
      Caption = #1054#1090#1082#1088#1099#1090#1100' '#1094#1077#1083#1100
      Flat = True
      OnClick = btnClick
    end
    object btnSave: TSpeedButton
      Left = 144
      Top = 15
      Width = 120
      Height = 30
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1094#1077#1083#1100
      Enabled = False
      Flat = True
      OnClick = btnClick
    end
    object btnSaveAs: TSpeedButton
      Left = 280
      Top = 15
      Width = 120
      Height = 30
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1094#1077#1083#1100' '#1082#1072#1082
      Enabled = False
      Flat = True
      OnClick = btnClick
    end
  end
  object pnMain: TPanel
    Left = 0
    Top = 0
    Width = 492
    Height = 208
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object vleditMain: TValueListEditor
      Left = 0
      Top = 0
      Width = 492
      Height = 208
      Align = alClient
      Ctl3D = False
      ParentCtl3D = False
      Strings.Strings = (
        #1051#1086#1075#1080#1085'='
        #1055#1072#1088#1086#1083#1100'='
        #1055#1086#1088#1090'='
        #1048#1085#1090#1077#1088#1087#1088#1077#1090#1072#1090#1086#1088'=')
      TabOrder = 0
      TitleCaptions.Strings = (
        #1055#1072#1088#1072#1084#1077#1090#1088
        #1047#1085#1072#1095#1077#1085#1080#1077)
      ColWidths = (
        150
        338)
    end
  end
  object dlgOpenFile: TOpenDialog
    Filter = 
      #1048#1089#1087#1086#1083#1085#1080#1084#1099#1077' '#1092#1072#1081#1083#1099'|*.exe|Dll '#1073#1080#1073#1083#1080#1086#1090#1077#1082#1080'|*.dll|'#1042#1089#1077' '#1087#1086#1076#1076#1077#1088#1078#1080#1074#1072#1077#1084#1099#1077' '#1092 +
      #1086#1088#1084#1072#1090#1099'|*.dll;*.exe|'#1042#1089#1077' '#1092#1072#1081#1083#1099'|*.*'
    Left = 464
    Top = 236
  end
  object dlgSaveFile: TSaveDialog
    Filter = 
      #1048#1089#1087#1086#1083#1085#1080#1084#1099#1077' '#1092#1072#1081#1083#1099'|*.exe|Dll '#1073#1080#1073#1083#1080#1086#1090#1077#1082#1080'|*.dll|'#1042#1089#1077' '#1087#1086#1076#1076#1077#1088#1078#1080#1074#1072#1077#1084#1099#1077' '#1092 +
      #1086#1088#1084#1072#1090#1099'|*.dll;*.exe|'#1042#1089#1077' '#1092#1072#1081#1083#1099'|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 448
    Top = 224
  end
  object XPManifest: TXPManifest
    Left = 440
    Top = 216
  end
end
