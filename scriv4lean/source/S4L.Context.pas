unit S4L.Context;

interface

type
  IContext = interface ['{2E04273F-57EF-4916-8CFB-A8062534DD7E}']
    function  GetDepth: integer;
  //
    procedure Add(const heading: string; depth: integer);
    function  Path: string;
    property Depth: integer read GetDepth;
  end; { IContext }

function CreateContext: IContext;

implementation

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TContext = class(TInterfacedObject, IContext)
  strict private
    FBreadcrumbs: TList<string>;
  strict protected
    function  GetDepth: integer;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const heading: string; depth: integer);
    function  Path: string;
    property Depth: integer read GetDepth;
  end; { TContext }

{ export }

function CreateContext: IContext;
begin
  Result := TContext.Create;
end; { CreateContext }

{ TContext }

constructor TContext.Create;
begin
  inherited Create;
  FBreadcrumbs := TList<string>.Create;
end; { TContext.Create }

destructor TContext.Destroy;
begin
  FreeAndNil(FBreadcrumbs);
  inherited;
end; { TContext.Destroy }

procedure TContext.Add(const heading: string; depth: integer);
begin
  while FBreadcrumbs.Count < depth do
    FBreadcrumbs.Add('');
  FBreadcrumbs[depth-1] := heading;
  while FBreadcrumbs.Count > depth do
    FBreadcrumbs.Delete(FBreadcrumbs.Count - 1);
end; { TContext.Add }

function TContext.GetDepth: integer;
begin
  Result := FBreadcrumbs.Count;
end; { TContext.GetDepth }

function TContext.Path: string;
begin
  Result := '\\' + string.Join('\\', FBreadcrumbs.ToArray);
end; { TContext.Path }

end.
