program Prosody;

{$IFDEF CONSOLEAPP}
  {$APPTYPE CONSOLE}
{$ENDIF}

{$R *.res}

uses
  Winapi.Windows,
  System.SysUtils,
  dorService,
  prosody.main in 'prosody.main.pas',
  lua.context in 'lua.context.pas',
  lua.loader in 'lua.loader.pas';

function AdjustConsoleBuffer(Size: Short): Boolean;
var
  H: Cardinal;
  BI: TConsoleScreenBufferInfo;
begin
  H := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleScreenBufferInfo(H, BI) then
  begin
    BI.dwSize.Y := Size;
    Result := SetConsoleScreenBufferSize(H, BI.dwSize);
  end
  else
    Result := False;
end;

begin
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ShortDateFormat := 'dd/MM/yyyy';
  Application.Name := 'im.prosody.server';
  Application.DisplayName := 'Prosody XMPP Server';
{$IFDEF CONSOLEAPP}
  AdjustConsoleBuffer(32767);
{$ELSE}
  Application.StartType := SERVICE_AUTO_START;
  Application.Description := 'Wraps the Prosody XMPP server written in Lua.';
{$ENDIF}
  Application.Run;
end.
