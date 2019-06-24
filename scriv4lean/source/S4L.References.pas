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
  WinApi.Windows,
  System.SysUtils;

type
  TReferences = class(TInterfacedObject, IReferences)
  public type
    TItem = TPair<string,string>;
  strict private
    FReferences: TList<TItem>;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const anchor, reference: string);
    function  GetEnumerator: TEnumerator<TItem>;
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
  FReferences := TList<TItem>.Create;
end; { TReferences.Create }

destructor TReferences.Destroy;
begin
  FreeAndNil(FReferences);
  inherited Destroy;
end; { TReferences.Destroy }

procedure TReferences.Add(const anchor, reference: string);
begin
  FReferences.Add(TItem.Create(anchor, reference));
end; { TReferences.Add }

function TReferences.GetEnumerator: TEnumerator<TItem>;
begin
  Result := FReferences.GetEnumerator;
end; { TReferences.GetEnumerator }

end.
