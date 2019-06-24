unit S4L.URLChecker;

interface

uses
  S4L.Errors;

type
  IURLChecker = interface(IErrorBase) ['{E87B70B5-6DAF-44E3-957D-E16C2CCFF2D6}']
    procedure Add(const url: string);
    function  CheckAll: boolean;
  end; { IURLChecker }

function CreateURLChecker: IURLChecker;

implementation

uses
  Winapi.Windows,
  System.SysUtils, System.Threading, System.Net.HttpClient,
  System.Generics.Defaults, System.Generics.Collections;

type
  TURLChecker = class(TErrorBase, IURLChecker)
  strict private
    FURLList: TList<string>;
  strict protected
    function  CheckURL(const url: string): integer;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const url: string);
    function  CheckAll: boolean;
  end; { TURLChecker }

{ exports }

function CreateURLChecker: IURLChecker;
begin
  Result := TURLChecker.Create;
end; { CreateURLChecker }

{ TURLChecker }

constructor TURLChecker.Create;
begin
  inherited Create;
  FURLList := TList<string>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
end; { TURLChecker.Create }

destructor TURLChecker.Destroy;
begin
  FreeAndNil(FURLList);
  inherited;
end; { TURLChecker.Destroy }

procedure TURLChecker.Add(const url: string);
begin
  if not FURLList.Contains(url) then
    FURLList.Add(url);
end; { TURLChecker.Add }

function TURLChecker.CheckAll: boolean;
var
  statusCodes: TArray<integer>;
begin
  Result := true;

  SetLength(statusCodes, FURLList.Count);

  TParallel.&For(0, FURLList.Count - 1,
    procedure (idx: integer)
    begin
      statusCodes[idx] := CheckURL(FURLList[idx]);
    end);

  for var idx := 0 to FURLList.Count - 1 do
    if (statusCodes[idx] div 100) <> 2 then
      Result := SetError('URL ' + FURLList[idx] + ' returned status code ' + statusCodes[idx].ToString);
end; { TURLChecker.CheckAll }

function TURLChecker.CheckURL(const url: string): integer;
begin
  var client := THTTPClient.Create;
  try
    try
      Result := client.Head(url).StatusCode;
      if (Result div 100) <> 2 then
        Result := client.Get(url).StatusCode;
    except
      Result := 0;
    end;
  finally FreeAndNil(client); end;
end; { TURLChecker.CheckURL }

end.
