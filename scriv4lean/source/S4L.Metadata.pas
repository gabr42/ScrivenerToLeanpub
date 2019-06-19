unit S4L.Metadata;

interface

type
  IMetadata = interface ['{8C54D77E-007B-45C6-8D1D-7FA922796830}']
    function  GetValues(const key: string): string;
    procedure SetValues(const key: string; const Value: string);
  //
    procedure Clear;
    property Values[const key: string]: string read GetValues write SetValues; default;
  end; { IMetadata }

function CreateMetadata: IMetadata;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults, System.Generics.Collections;

type
  TMetadata = class(TInterfacedObject, IMetadata)
  strict private
    FMetadata: TDictionary<string,string>;
  strict protected
    function  GetValues(const key: string): string;
    procedure SetValues(const key: string; const value: string);
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Clear;
    property Values[const key: string]: string read GetValues write SetValues; default;
  end; { TMetadata }

{ exports }

function CreateMetadata: IMetadata;
begin
  Result := TMetadata.Create;
end; { CreateMetadata }

{ TMetadata }

constructor TMetadata.Create;
begin
  inherited Create;
  FMetadata := TDictionary<string,string>.Create(TOrdinalIStringComparer(TIStringComparer.Ordinal));
end; { TMetadata.Create }

destructor TMetadata.Destroy;
begin
  FreeAndNil(FMetadata);
  inherited Destroy;
end; { TMetadata.Destroy }

procedure TMetadata.Clear;
begin
  FMetadata.Clear;
end; { TMetadata.Clear }

function TMetadata.GetValues(const key: string): string;
begin
  if not FMetadata.TryGetValue(key, Result) then
    Result := '';
end; { TMetadata.GetValues }

procedure TMetadata.SetValues(const key: string; const value: string);
begin
  FMetadata.AddOrSetValue(key, value);
end; { TMetadata.SetValues }

end.
