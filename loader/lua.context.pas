unit lua.context;

interface

uses
  Generics.Collections;

type
  TScriptContext = class
  private
    FStatus: Integer;
    FLoadPath: string;
    FLoadCPath: string;
    FArguments: TList<string>;
    FGlobals: TDictionary<string, string>;
  protected
    function GetArgCount: Integer;
    function GetArgArray: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property Status: Integer read FStatus write FStatus;
    property LoadPath: string read FLoadPath write FLoadPath;
    property LoadCPath: string read FLoadCPath write FLoadCPath;
    property Arguments: TList<string> read FArguments;
    property ArgCount: Integer read GetArgCount;
    property ArgArray: TArray<string> read GetArgArray;
    property Globals: TDictionary<string, string> read FGlobals;
  end;

implementation

{ TScriptContext }

constructor TScriptContext.Create;
begin
  inherited;
  FArguments := TList<string>.Create;
  FGlobals := TDictionary<string, string>.Create;
end;

destructor TScriptContext.Destroy;
begin
  FGlobals.Free;
  FArguments.Free;
  inherited;
end;

function TScriptContext.GetArgArray: TArray<string>;
begin
  Result := FArguments.ToArray;
end;

function TScriptContext.GetArgCount: Integer;
begin
  Result := FArguments.Count;
end;

end.
