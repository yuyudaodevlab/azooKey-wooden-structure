#include "CodeDependencies.iss"
#ifndef SourceDir
  #error SourceDir must point to the build staging directory
#endif
#ifndef Commit
  #error Commit must be the full source commit SHA
#endif
[Setup]
AppId={{DF3A2C38-06A3-4434-9813-F33C231F7B81}
AppName=azooKey wooden structure
AppVersion=0.1.0
AppVerName=azooKey wooden structure {#Commit}
AppPublisher=yuyudaodevlab
AppPublisherURL=https://github.com/yuyudaodevlab/azooKey-wooden-structure
DefaultDirName={autopf}\AzooKeyWooden
DefaultGroupName=azooKey wooden structure
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
OutputBaseFilename=azooKey-wooden-structure-{#Commit}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
AlwaysRestart=yes
[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
[Files]
Source: "{#SourceDir}\azookey_windows.dll"; DestDir: "{app}"; Flags: ignoreversion regserver 64bit restartreplace uninsrestartdelete
Source: "{#SourceDir}\x86\azookey_windows.dll"; DestDir: "{app}\x86"; Flags: ignoreversion regserver 32bit restartreplace uninsrestartdelete
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "azookey_windows.dll,x86\azookey_windows.dll"; Flags: ignoreversion recursesubdirs createallsubdirs restartreplace uninsrestartdelete
[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AzooKeyWooden"; ValueData: """{app}\launcher.exe"""; Flags: uninsdeletevalue
[Icons]
Name: "{group}\設定"; Filename: "{app}\frontend.exe"; WorkingDir: "{app}"
Name: "{group}\アンインストール"; Filename: "{uninstallexe}"
[Run]
Filename: "{sys}\icacls.exe"; Parameters: """{app}"" /grant ""*S-1-15-2-1:(OI)(CI)(RX)"" /T"; Flags: runhidden waituntilterminated
[Code]
function InitializeSetup: Boolean;
begin
  Dependency_AddVC2015To2022x64;
  Dependency_AddVC2015To2022x86;
  Dependency_AddWebView2;
  Result := True;
end;
