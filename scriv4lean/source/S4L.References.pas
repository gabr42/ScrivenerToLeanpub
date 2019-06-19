unit S4L.References;

interface

uses
  System.Generics.Collections;

type
  IReferences = interface ['{0EE7BDF2-DA8F-4836-8500-04EB9492E8FD}']
    procedure Add(const anchor, reference: string);
    function  GetEnumerator: TEnumerator<TPair<string,string>>;
  end; { IReferences }

function CreateReferences: IReferences;

implementation

uses
  System.SysUtils;

type
  TReferences = class(TInterfacedObject, IReferences)
  strict private
    FReferences: TList<TPair<string,string>>;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const anchor, reference: string);
    function  GetEnumerator: TEnumerator<TPair<string,string>>;
  end; { TReferences }

{ exports }

function CreateReferences: IReferences;
begin
  Result := TReferences.Create;
end; { CreateReferences }

{ TReferences }

constructor TReferences.Create;
begin
  inherited Create;
  FReferences := TList<TPair<string,string>>.Create;
end; { TReferences.Create }

destructor TReferences.Destroy;
begin
  FreeAndNil(FReferences);
  inherited Destroy;
end; { TReferences.Destroy }

procedure TReferences.Add(const anchor, reference: string);
begin
  FReferences.Add(TPair<string,string>.Create(anchor, reference));
end; { TReferences.Add }

function TReferences.GetEnumerator: TEnumerator<TPair<string,string>>;
begin
  Result := FReferences.GetEnumerator;
end; { TReferences.GetEnumerator }

end.
