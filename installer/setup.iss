; Unify Net Monitor — Inno Setup Script
; Compile with Inno Setup 6+: https://jrsoftware.org/isinfo.php
; Run: iscc setup.iss

#define AppName      "Unify Net Monitor"
#define AppVersion   "1.2.5"
#define AppPublisher "Unify Technologies"
#define AppExeName   "network_monitor.exe"
#define AppId        "{{8B3F2C4A-9D7E-4F1B-A6C5-2E8D0B1F3A7C}"
#define SourceDir    "..\build\windows\x64\runner\Release"
#define IconFile     "..\windows\runner\resources\app_icon.ico"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://unifytechnologies.net
AppSupportURL=https://unifytechnologies.net/support
AppUpdatesURL=https://unifytechnologies.net/updates
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.\output
OutputBaseFilename=UnifyNetMonitor_Setup_v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardImageFile=compiler:WizModernImage.bmp
WizardSmallImageFile=compiler:WizModernSmallImage.bmp
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";     Description: "{cm:CreateDesktopIcon}";      GroupDescription: "Shortcuts:"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "Add to Start &Menu";           GroupDescription: "Shortcuts:"; Flags: checkedonce

[Files]
; All files from the Release folder — exe, every DLL, and data assets
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu
Name: "{group}\{#AppName}";             Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: quicklaunchicon
Name: "{group}\Uninstall {#AppName}";   Filename: "{uninstallexe}"

; Desktop icon
Name: "{autodesktop}\{#AppName}";       Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Launch after install (optional)
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall


[UninstallRun]

[Code]
// Kill any running instance before installing so the exe is not locked.
// Inno Setup calls this before copying files, so no exit(0) needed in the app.
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#AppExeName}', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  // Always return True — even if the app wasn't running, proceed with install
  Result := True;
end;

// ── Welcome page: show trial info ──────────────────────────────────────────
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Caption :=
    'This will install {#AppName} {#AppVersion} on your computer.' + #13#10 + #13#10 +
    'TRIAL LICENSE:' + #13#10 +
    'The software includes a 60-day free trial. After the trial period, ' +
    'you will need a license key from the owner to continue using the software.' + #13#10 + #13#10 +
    'TIP: To pin to taskbar, right-click the app after launch and choose "Pin to taskbar".' + #13#10 + #13#10 +
    'Click Next to continue.';
end;
