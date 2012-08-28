unit prosody.main;

interface

uses
  Winapi.Windows, System.SysUtils, Winapi.ShlObj, Winapi.ActiveX,
  dorService, dorSocketStub, dorLua,
  lua.context, lua.loader;

type
  TProsodyMainThread = class(TDORThread)
  private
    FStopping: Boolean;
    FScriptLoader: TScriptLoader;
    function LocalAppDataPath: string;
    function ProgramDataPath: string;
  protected
    function Run: Cardinal; override;
    procedure Stop; override;
  end;

implementation

{$IFDEF CONSOLEAPP}
type
  ConsoleString = type AnsiString(850);
{$ENDIF}

{ TProsodyMainThread }

function TProsodyMainThread.LocalAppDataPath: string;
const
  SHGFP_TYPE_CURRENT = 0;
var
  path: array [0..MaxChar] of Char;
begin
  SHGetFolderPath(0, CSIDL_APPDATA, 0, SHGFP_TYPE_CURRENT, @path[0]);
  Result := IncludeTrailingPathDelimiter(StrPas(path));
end;

function TProsodyMainThread.ProgramDataPath: string;
var
  ItemIDList: PItemIDList;
  Path: array[0..MAX_PATH-1] of Char;
begin
  SHGetSpecialFolderLocation(HInstance, CSIDL_COMMON_APPDATA, ItemIDList);
  SHGetPathFromIDList(ItemIDList, @Path);
  CoTaskMemFree(ItemIDList);
  Result := IncludeTrailingPathDelimiter(Path);
end;

function TProsodyMainThread.Run: Cardinal;
var
  Context: TScriptContext;
  root, data: string;
  I: Integer;
begin
  FStopping := False;
  FScriptLoader := nil;

  { Disable Floating Point Exceptions }
  Set8087CW(Get8087CW or $3F);

  Context := TScriptContext.Create;
  try
    { This loader must be installed in Prosody\bin }
    root := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..');

    (* Data is stored in {commonappdata} then in {userappdata} and if not found
       in {root} *)
    data := ProgramDataPath + 'Prosody';
    if not DirectoryExists(data) then
      data := LocalAppDataPath + 'Prosody';

    if DirectoryExists(data) then
    begin
      Context.Globals.AddOrSetValue('CFG_CONFIGDIR', data);
      Context.Globals.AddOrSetValue('CFG_DATADIR', data + '\data');
    end
    else
    begin
      { Debug mode : data is stored within the installation directory }
      Context.Globals.AddOrSetValue('CFG_CONFIGDIR', root);
      Context.Globals.AddOrSetValue('CFG_DATADIR', root + '\data');
    end;

    { Source and plugin directories for Prosody }
    Context.Globals.AddOrSetValue('CFG_SOURCEDIR', root + '\src\');
    Context.Globals.AddOrSetValue('CFG_PLUGINDIR', root + '\plugins\');

    { Lua interpreter package.[c]path for loading dependencies }
    Context.LoadPath := root + '\src\?.lua;' + root + '\lib\?.lua';;
    Context.LoadCPath := root + '\lib\?.dll';

    { We can pass params to prosody so we build a structure to handle these
      params that will be passed as the "arg" table to the script, the first
      argument is, by convention, the full path of the prosody main script }
    Context.Arguments.Add(root + '\src\prosody');
    for I := 1 to ParamCount do
      Context.Arguments.Add(ParamStr(I));

    FScriptLoader := TScriptLoader.Create;
    try
      FScriptLoader.Run(Context,
        procedure(Status: Integer; const Error: string)
        begin
        {$IFDEF CONSOLEAPP}
          WriteLn(ConsoleString(Error));
        {$ENDIF}
        end
      );
    finally
      Free;
      FScriptLoader := nil;
    end;
  finally
    Context.Free;
  end;

  Result := 0;
end;

{ This is an Lua CFunction used to stop the Lua application }
procedure lua_stop(L: Plua_State; ar: Plua_Debug); cdecl;
begin
  lua_sethook(L, nil, 0, 0);
  luaL_error(L, 'interrupted!');
end;

procedure TProsodyMainThread.Stop;
begin
  inherited;
  if not FStopping then
  begin
    if Assigned(FScriptLoader) then
      lua_sethook(FScriptLoader.LuaState, lua_stop, LUA_MASKCALL or LUA_MASKRET or LUA_MASKCOUNT, 1);
    FStopping := True;
  end;
end;

initialization
  // requests the application to start this thread
  Application.CreateThread(TProsodyMainThread);

end.
