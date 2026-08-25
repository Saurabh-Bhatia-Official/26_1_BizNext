[Setup]
AppName=BizNext
AppVersion=1.0.0+1
AppPublisher=Saurabh Bhatia Official
DefaultDirName={autopf}\BizNext
DefaultGroupName=BizNext
AllowNoIcons=yes
LicenseFile=LICENSE.txt
OutputDir=build\windows\installer
OutputBaseFilename=BizNext_v1.0.0_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\biz_next.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\BizNext"; Filename: "{app}\biz_next.exe"
Name: "{group}\{cm:UninstallProgram,BizNext}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\BizNext"; Filename: "{app}\biz_next.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\biz_next.exe"; Description: "{cm:LaunchProgram,BizNext}"; Flags: nowait postinstall skipifsilent
