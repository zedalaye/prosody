unit lua.loader;

interface

uses
  SysUtils,
  System.Generics.Collections,
  dorLua, lua.context;

type
  TScriptError = reference to procedure(Status: Integer; const Error: string);
  TScriptEvent = reference to procedure(State: Plua_State);
  TScriptMessage = reference to procedure(const Message: string);

  TScriptLoader = class
  private
    FLoaderName: string;
    FContext: TScriptContext;
    FOnBeforeExecute: TScriptEvent;
    FOnAfterExecute: TScriptEvent;
    FOnError: TScriptError;
    FLuaState: Plua_State;
    function Main: Integer;
    procedure AdjustPackagePaths(const Path, CPath: string);
    procedure DefineGlobalVariable(const Name, Value: string);
    function RunScript: Integer;
    function DoCall(ArgCount: Integer; Clear: Boolean): Integer;
  protected
    function Report(Status: Integer): Integer;
  public
    constructor Create(const LoaderName: string = '');
    destructor Destroy; override;
    procedure Run(Context: TScriptContext; OnError: TScriptError = nil; OnBeforeExecute: TScriptEvent = nil; OnAfterExecute: TScriptEvent = nil);
    property LuaState: Plua_State read FLuaState;
  end;

implementation

{ TScriptLoader }

constructor TScriptLoader.Create(const LoaderName: string);
begin
  FLoaderName := LoaderName;
  if FLoaderName = '' then
    FLoaderName := ParamStr(0);

  FLuaState := lua_open;
end;

destructor TScriptLoader.Destroy;
begin
  lua_close(FLuaState);
  inherited;
end;

procedure TScriptLoader.AdjustPackagePaths(const Path, CPath: string);

  procedure FixPath(const Name, Value: UTF8String);
  var
    CurPath: UTF8String;
  begin
    lua_getfield(FLuaState, -1, PAnsiChar(Name));
    CurPath := UTF8String(lua_tostring(FLuaState, -1));
    CurPath := CurPath + ';' + Value;
    lua_pop(FLuaState, 1);
    lua_pushstring(FLuaState, PAnsiChar(CurPath));
    lua_setfield(FLuaState, -2, PAnsiChar(Name));
  end;

begin
  lua_getglobal(FLuaState, 'package');
  if lua_istable(FLuaState, -1) then
  begin
    FixPath('path', UTF8String(Path));
    FixPath('cpath', UTF8String(CPath));
  end;
  lua_pop(FLuaState, 1);
end;

procedure TScriptLoader.DefineGlobalVariable(const Name, Value: string);
begin
  lua_pushstring(FLuaState, PAnsiChar(UTF8String(Value)));
  lua_setglobal(FLuaState, PAnsiChar(UTF8String(Name)));
end;

function TScriptLoader.Report(Status: Integer): Integer;
var
  msg: string;
begin
  if (Status <> 0) and (not lua_isnil(FLuaState, -1)) then
  begin
    msg := string(UTF8String(lua_tostring(FLuaState, -1)));
    if (msg = '') then
      msg := '(error object is not a string)';
    if Assigned(FOnError) then
      FOnError(Status, msg);
    lua_pop(FLuaState, 1);
  end;
  Result := Status;
end;

function lua_traceback(L: Plua_State): Integer; cdecl;
begin
  lua_getfield(L, LUA_GLOBALSINDEX, 'debug');

  if (not lua_istable(L, -1)) then
  begin
    lua_pop(L, 1);
    Exit(1);
  end;

  lua_getfield(L, -1, 'traceback');
  if (not lua_isfunction(L, -1)) then
  begin
    lua_pop(L, 2);
    Exit(1);
  end;

  lua_pushvalue(L, 1);    // pass error message
  lua_pushinteger(L, 2);  // skip this function and traceback
  lua_call(L, 2, 1);      // call debug.traceback

  Result := 1;
end;

function TScriptLoader.DoCall(ArgCount: Integer; Clear: Boolean): Integer;
var
  Status, Base: Integer;
begin
  Base := lua_gettop(FLuaState) - ArgCount;  { function index }
  lua_pushcfunction(FLuaState, lua_traceback);  { push traceback function }
  lua_insert(FLuaState, Base);  { put it under chunk and args }

  if Assigned(FOnBeforeExecute) then
    FOnBeforeExecute(FLuaState);

  if Clear then
    Status := lua_pcall(FLuaState, ArgCount, 0, Base)
  else
    Status := lua_pcall(FLuaState, ArgCount, LUA_MULTRET, Base);

  if Assigned(FOnAfterExecute) then
    FOnAfterExecute(FLuaState);

  lua_remove(FLuaState, Base);  { remove traceback function }

  { force a complete garbage collection in case of errors }
  if Status <> 0 then
    lua_gc(FLuaState, LUA_GCCOLLECT, 0);

  Result := Status;
end;

function lua_main(L: Plua_State): Integer; cdecl;
var
  C: TScriptLoader;
begin
  C := TScriptLoader(lua_touserdata(L, 1));
  Result := C.Main;
end;

procedure TScriptLoader.Run(Context: TScriptContext; OnError: TScriptError;
  OnBeforeExecute, OnAfterExecute: TScriptEvent);
begin
  FContext := Context;
  FOnError := OnError;
  FOnBeforeExecute := OnBeforeExecute;
  FOnAfterExecute := OnAfterExecute;
  Report(lua_cpcall(FLuaState, @lua_main, Self));
end;

function TScriptLoader.RunScript: Integer;
var
  Status: Integer;
  NArgs, I: Integer;
  FileName: PAnsiChar;
begin
  NArgs := FContext.ArgCount - 1; { number of arguments to the script }
  luaL_checkstack(FLuaState, NArgs + 3, PAnsiChar(UTF8String('too many arguments')));

  for I := 1 to FContext.ArgCount - 1 do
    lua_pushstring(FLuaState, PAnsiChar(UTF8String(FContext.Arguments[I])));

  lua_createtable(FLuaState, NArgs, 2);

  lua_pushstring(FLuaState, PAnsiChar(UTF8String(FLoaderName)));
  lua_rawseti(FLuaState, -2, -1);

  for I := 0 to FContext.ArgCount - 1 do
  begin
    lua_pushstring(FLuaState, PAnsiChar(UTF8String(FContext.Arguments[I])));
    lua_rawseti(FLuaState, -2, I);
  end;

  lua_setglobal(FLuaState, 'arg');

  FileName := PAnsiChar(UTF8String(FContext.Arguments[0]));
  Status := luaL_loadfile(FLuaState, FileName);
  lua_insert(FLuaState, -(NArgs+1));

  if Status = 0 then
    Status := DoCall(NArgs, False)
  else
    lua_pop(FLuaState, NArgs);

  Result := Report(Status);
end;

function TScriptLoader.Main: Integer;
var
  Global: TPair<string, string>;
begin
  { Initialize all internal lua libraries }
  lua_gc(FLuaState, LUA_GCSTOP, 0);
  luaL_openlibs(FLuaState);
  lua_gc(FLuaState, LUA_GCRESTART, 0);

  { Adjust package.path and package.cpath }
  AdjustPackagePaths(FContext.LoadPath, FContext.LoadCPath);

  { Initialise script configuration through global variables }
  for Global in FContext.Globals do
    DefineGlobalVariable(Global.Key, Global.Value);

  if FContext.ArgCount < 1 then
  begin
    FContext.Status := 1;
    Exit(0);
  end;

  FContext.Status := RunScript;
  Result := 0;
end;

end.
