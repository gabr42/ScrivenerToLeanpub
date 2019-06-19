unit S4L.Anchors;

interface

uses
  S4L.Errors;

type
  IAnchors = interface(IErrorBase) ['{28B6E7E7-B97F-4128-A761-42F0BC7FE6BD}']
    function  Add(const path, anchor: string; currentLine: integer): boolean;
    function  Has(const anchor: string): boolean;
  end; { IAnchors }

function CreateAnchors: IAnchors;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults, System.Generics.Collections;

type
  TAnchors = class(TErrorBase, IAnchors)
  strict private type
    TAnchorValue = TPair<string, integer>; // path, line number
  var
    FAnchors : TDictionary<string, TAnchorValue>; // anchor, <path, line number>
  public
    constructor Create;
    destructor  Destroy; override;
    function  Add(const path, anchor: string; currentLine: integer): boolean;
    function  Has(const anchor: string): boolean;
  end; { TAnchors }

{ exports }

function CreateAnchors: IAnchors;
begin
  Result := TAnchors.Create;
end; { CreateAnchors }

{ TAnchors }

constructor TAnchors.Create;
begin
  inherited Create;
  FAnchors := TDictionary<string, TAnchorValue>.Create(
                TOrdinalIStringComparer(TIStringComparer.Ordinal));
end; { TAnchors.Create }

destructor TAnchors.Destroy;
begin
  FreeAndNil(FAnchors);
  inherited;
end; { TAnchors.Destroy }

function TAnchors.Add(const path, anchor: string; currentLine: integer): boolean;
var
  oldPath: TAnchorValue;
begin
  if FAnchors.TryGetValue(anchor, oldPath) then
    Exit(SetError(Format(
      'Paths "%s" [line #%d] and "%s" [line #%d] resolve to the same anchor %s. Only path "%0:s" [line #%1:d] will be used for cross-references.',
      [oldPath.Key, oldPath.Value, path, currentLine, anchor])));

  FAnchors.Add(anchor, TAnchorValue.Create(path, currentLine));
  Result := true;
end; { TAnchors.Add }

function TAnchors.Has(const anchor: string): boolean;
begin
  Result := FAnchors.ContainsKey(anchor);
end; { TAnchors.Has }

end.
