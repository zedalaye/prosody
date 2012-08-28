; Commenter cette ligne pour ne pas compresser l'exécutable de sortie et ainsi gagner un peu de temps...
#define Release

#define AppDir "Prosody"

#define AppName "Prosody"
#define AppFullName AppName
#define AppFullHumanName "Serveur XMPP Prosody"

#define AppServiceName "im.prosody.server"
#define AppMutexName "Prosody.Mutex"

// Elements du numéro de version d'AgentPresse.exe
#define Major
#define Minor
#define Rel
#define Build

// Le chemin de l'exécutable
#define AppExecutable AddBackslash(SourcePath) + "..\bin\" + AppName + ".exe"

// La partie MajorMinorRelease
#define AppVersion \
  ParseVersion(AppExecutable, Major, Minor, Rel, Build), \
  Str(Major) + Str(Minor) + Str(Rel) + Str(Build)

#define AppShortVersion "v" + Str(Major) + "." + Str(Minor)

#emit "; Script d'installation pour " + AppFullHumanName + " - Version " + Str(Major) + "." + Str(Minor) + "." + Str(Rel) + "." + Str(Build)

#undef Build
#undef Rel
#undef Minor
#undef Major

// Le numéro de version avec des "." entre les paquets de nombres
#define AppFullVersion GetFileVersion(AppExecutable)

[Setup]
AppID={#AppName}
AppName={#AppFullHumanName}
AppVerName={#AppFullHumanName} {#AppShortVersion}
AppPublisher=Crisalid
AppPublisherURL=http://www.crisalid.com
AppSupportURL=http://www.crisalid.com
AppUpdatesURL=http://www.crisalid.com
AppCopyright=©2012
DefaultDirName={pf}\{#AppDir}\
DefaultGroupName={#AppName}
DisableProgramGroupPage=true
OutputDir=D:\Builds\Prosody
SourceDir=..
#ifdef Release
Compression=lzma2
InternalCompressLevel=max
SolidCompression=yes
OutputBaseFilename={#AppFullName}-{#AppVersion}
#else
Compression=none
OutputBaseFilename={#AppFullName}-{#AppVersion}d
#endif
PrivilegesRequired=admin
DisableStartupPrompt=true
ShowTasksTreeLines=false

VersionInfoCompany=Crisalid
VersionInfoCopyright=©2012 - Crisalid
VersionInfoDescription=Assistant d'installation pour {#AppFullHumanName}
VersionInfoVersion={#AppFullVersion}

[Languages]
Name: fr; MessagesFile: "compiler:Languages\French.isl"

[Files]
; Our loader
Source: bin\Prosody.exe; DestDir: {app}\bin; Flags: replacesameversion
; Stripped down version of prosody
Source: bin\lua.exe; DestDir: {app}\bin
Source: bin\*.dll; DestDir: {app}\bin
Source: lib\*.*; DestDir: {app}\lib; Flags: recursesubdirs
Source: plugins\*.*; DestDir: {app}\plugins; Flags: recursesubdirs
Source: src\*.*; DestDir: {app}\src; Flags: recursesubdirs
; Default configuration
Source: prosody.cfg.lua.template; Flags: dontcopy
Source: certs\*.*; DestDir: {commonappdata}\{#AppName}\certs; Flags: recursesubdirs

[Dirs]
Name: {commonappdata}\{#AppName}
Name: {commonappdata}\{#AppName}\data

[Run]
FileName: "{app}\bin\{#AppName}.exe"; Parameters: install; StatusMsg: "Installation du service Prosody"

[UninstallDelete]
Type: filesandordirs; Name: {commonappdata}\{#AppName}

[Code]

#include AddBackslash(SourcePath) + "..\..\..\Install\InnoSetup\innoutils.iss"
   
function UninstallService(const ServiceName: string): Boolean;
var
  i: Integer;
begin
  Result := true;
  if IsServiceInstalled(ServiceName) then
  begin
    StopService(ServiceName);
    i := 600; // à peu près 5 minutes.
    while (i > 0) and IsServiceRunning(ServiceName) do
    begin
      i := i - 1;
      Sleep(500);
    end;
    if not IsServiceRunning(ServiceName) then
    begin
      RemoveService(ServiceName);
      i := 600; // à peu près 5 minutes.
      while (i > 0) and IsServiceInstalled(ServiceName) do
      begin
        i := i - 1;
        Sleep(500);
      end;
    end;
  end;
end;

procedure UpdateConfig;
var
  CfgFileName: string;
  LogFileName: string;
  S: string;
begin
  CfgFileName := ExpandConstant('{commonappdata}\{#AppName}\prosody.cfg.lua');
  if not FileExists(CfgFileName) then
  begin
    ExtractTemporaryFile('prosody.cfg.lua.template');
    if LoadStringFromFile(ExpandConstant('{tmp}\prosody.cfg.lua.template'), S) then
    begin
      LogFileName := ExpandConstant('{commonappdata}\{#AppName}\Prosody.log');
      StringChangeEx(LogFileName, '\', '/', True);
      StringChangeEx(S, '%LOG_PATH%', LogFileName, True);
      SaveStringToFile(CfgFileName, S, False);
    end;
  end;
end;

{ InnoSetup Wizard Events }

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    UpdateConfig;
    if IsServiceInstalled('{#AppServiceName}') then
      StartService('{#AppServiceName}');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    UninstallService('{#AppServiceName}');
end;