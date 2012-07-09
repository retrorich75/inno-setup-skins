[Setup]
AppName=My Program
AppVersion=1.5
DefaultDirName={pf}\My Program
DefaultGroupName=My Program
UninstallDisplayIcon={app}\MyProg.exe
Compression=lzma2
SolidCompression=yes
OutputDir=userdocs:Inno Setup Examples Output

[Files]
Source: "MyProg.exe"; DestDir: "{app}"
Source: "MyProg.chm"; DestDir: "{app}"
Source: "Readme.txt"; DestDir: "{app}"; Flags: isreadme
Source: "Skins\Garnet.asz"; Flags: dontcopy

[Icons]
Name: "{group}\My Program"; Filename: "{app}\MyProg.exe"

[Code]
procedure InitializeWizard;
begin
  WizardForm.SkinManager.SkinDirectory := 'c:\Users\Public\Documents\AlphaSkins\Skins';
  WizardForm.SkinManager.SkinName := 'Garnet';
end;